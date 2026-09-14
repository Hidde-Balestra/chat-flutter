import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../crypto/crypto_algorithms.dart';
import '../storage/app_database.dart';

/// Locks the on-device database behind a PIN the user chooses, on top of
/// (not instead of) the platform keystore protection every secret in this
/// app already gets via `flutter_secure_storage`. Fingerprint/Face
/// unlock is an optional, faster stand-in for typing the PIN — see
/// [enableBiometric] for exactly what it does and doesn't add.
///
/// Without a PIN, [AppDatabase]'s passphrase sits directly in the keystore
/// and the app opens itself automatically — fine against "someone copies
/// the app's files off the device", but not against "someone picks up your
/// already-unlocked phone". With a PIN set, that raw passphrase is deleted
/// from storage entirely: what remains is a copy encrypted with a key
/// derived from the PIN via PBKDF2 (the PIN itself, and the derived key,
/// are never stored) — so nothing at rest on the device can open the chat
/// database without it, and it's only ever decrypted transiently, in
/// memory, right after the user enters it.
///
/// Note this protects *storage*, not the Double Ratchet messages
/// themselves — those already have forward secrecy (each message key is
/// used once and discarded), so there is nothing to "re-encrypt" there;
/// this closes the separate, real gap of the local plaintext message cache.
class AppLockController {
  /// [pbkdf2Iterations] defaults to a modern, deliberately-slow OWASP-level
  /// work factor for real use. Tests inject a tiny value instead — not for
  /// speed alone, but because the real one is slow enough to make
  /// `pumpAndSettle()` hang forever against the indeterminate progress
  /// spinner shown while [enable]/[unlock]/[disable] are running.
  AppLockController({
    FlutterSecureStorage? storage,
    this.pbkdf2Iterations = 210000,
    LocalAuthentication? localAuth,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  static const _wrappedPassphraseKey = 'local_db_passphrase_wrapped_v1';
  static const _saltKey = 'local_db_passphrase_salt_v1';
  static const _biometricKeyKey = 'local_db_passphrase_biometric_key_v1';
  static const _biometricWrappedPassphraseKey =
      'local_db_passphrase_biometric_wrapped_v1';

  final int pbkdf2Iterations;
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  Future<bool> get isEnabled async =>
      (await _storage.read(key: AppDatabase.passphraseStorageKey)) == null &&
      (await _storage.read(key: _wrappedPassphraseKey)) != null;

  /// Turns on PIN protection. Requires the database to have been opened at
  /// least once already (so a passphrase exists to protect).
  Future<void> enable(String pin) async {
    final rawPassphrase =
        await _storage.read(key: AppDatabase.passphraseStorageKey);
    if (rawPassphrase == null) {
      throw StateError(
          'no existing database passphrase to protect — open the database first');
    }

    final salt = _randomBytes(16);
    final key = await _deriveKey(pin, salt);
    final box = await CryptoAlgorithms.aead
        .encrypt(utf8.encode(rawPassphrase), secretKey: key);

    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(
        key: _wrappedPassphraseKey, value: base64Encode(box.concatenation()));
    await _storage.delete(key: AppDatabase.passphraseStorageKey);
  }

  /// Turns PIN protection back off: restores the plain passphrase to
  /// storage so the app can unlock itself automatically again, like before
  /// [enable] was called. Also turns off biometric unlock, since it's
  /// meaningless once there's no PIN-protected secret left to gate access
  /// to. Throws if [pin] is wrong.
  Future<void> disable(String pin) async {
    final passphrase = await unlock(pin);
    if (passphrase == null) {
      throw StateError('incorrect PIN');
    }
    await _storage.write(
        key: AppDatabase.passphraseStorageKey, value: passphrase);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _wrappedPassphraseKey);
    await disableBiometric();
  }

  /// Returns the database passphrase if [pin] is correct, or null if not
  /// (or if PIN protection isn't enabled at all).
  Future<String?> unlock(String pin) async {
    final saltB64 = await _storage.read(key: _saltKey);
    final wrappedB64 = await _storage.read(key: _wrappedPassphraseKey);
    if (saltB64 == null || wrappedB64 == null) {
      return null;
    }

    final key = await _deriveKey(pin, base64Decode(saltB64));
    final box = SecretBox.fromConcatenation(
      base64Decode(wrappedB64),
      nonceLength: CryptoAlgorithms.aead.nonceLength,
      macLength: CryptoAlgorithms.aead.macAlgorithm.macLength,
    );

    try {
      final plaintext =
          await CryptoAlgorithms.aead.decrypt(box, secretKey: key);
      return utf8.decode(plaintext);
    } catch (_) {
      return null; // wrong PIN — AEAD authentication failed
    }
  }

  /// Whether this device can even offer biometric unlock (has a sensor and
  /// at least one fingerprint/face enrolled).
  Future<bool> get isBiometricAvailable async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      // Missing platform setup, permission denied, etc. — treat as
      // unavailable rather than crashing the settings screen over it.
      return false;
    }
  }

  Future<bool> get isBiometricEnabled async =>
      (await _storage.read(key: _biometricWrappedPassphraseKey)) != null;

  /// Turns on biometric unlock. This does *not* weaken the PIN's
  /// protection: it stores a second copy of the passphrase, wrapped with a
  /// freshly generated random key that never leaves the device's keystore
  /// storage. Reading that copy back always requires a successful
  /// biometric prompt first (see [unlockWithBiometric]) — biometrics are a
  /// faster stand-in for typing the PIN, not a way to skip proving you
  /// unlocked the device. Requires [pin] to already be correct.
  Future<void> enableBiometric(String pin) async {
    final passphrase = await unlock(pin);
    if (passphrase == null) {
      throw StateError('incorrect PIN');
    }

    final keyBytes = _randomBytes(32);
    final box = await CryptoAlgorithms.aead
        .encrypt(utf8.encode(passphrase), secretKey: SecretKey(keyBytes));

    await _storage.write(key: _biometricKeyKey, value: base64Encode(keyBytes));
    await _storage.write(
      key: _biometricWrappedPassphraseKey,
      value: base64Encode(box.concatenation()),
    );
  }

  Future<void> disableBiometric() async {
    await _storage.delete(key: _biometricKeyKey);
    await _storage.delete(key: _biometricWrappedPassphraseKey);
  }

  /// Prompts for fingerprint/face authentication and, on success, returns
  /// the database passphrase. Returns null if the user cancels, fails, or
  /// biometric unlock isn't set up — callers should fall back to the PIN
  /// entry screen in that case, not treat it as a hard error.
  Future<String?> unlockWithBiometric({
    String reason = 'Ontgrendel PrivacyChat',
  }) async {
    final keyB64 = await _storage.read(key: _biometricKeyKey);
    final wrappedB64 = await _storage.read(key: _biometricWrappedPassphraseKey);
    if (keyB64 == null || wrappedB64 == null) {
      return null;
    }

    bool authenticated;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return null;
    }
    if (!authenticated) {
      return null;
    }

    final box = SecretBox.fromConcatenation(
      base64Decode(wrappedB64),
      nonceLength: CryptoAlgorithms.aead.nonceLength,
      macLength: CryptoAlgorithms.aead.macAlgorithm.macLength,
    );

    try {
      final plaintext = await CryptoAlgorithms.aead
          .decrypt(box, secretKey: SecretKey(base64Decode(keyB64)));
      return utf8.decode(plaintext);
    } catch (_) {
      return null;
    }
  }

  Future<SecretKey> _deriveKey(String pin, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
