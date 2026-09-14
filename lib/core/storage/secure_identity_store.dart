import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto/identity_key_pair.dart';

/// Persists the identity seed in the platform keystore (Android Keystore /
/// iOS Keychain) — never in plain SharedPreferences/UserDefaults, and never
/// synced anywhere by this app.
class SecureIdentityStore {
  SecureIdentityStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _seedKey = 'identity_seed_v1';

  final FlutterSecureStorage _storage;

  Future<IdentityKeyPair?> load() async {
    final encoded = await _storage.read(key: _seedKey);
    if (encoded == null) {
      return null;
    }
    return IdentityKeyPair.fromSeed(base64Decode(encoded));
  }

  Future<void> save(IdentityKeyPair identity) {
    return _storage.write(key: _seedKey, value: base64Encode(identity.seed));
  }

  Future<void> delete() {
    return _storage.delete(key: _seedKey);
  }

  /// Loads the existing identity, or generates and persists a brand-new one
  /// if this is the first launch. This is the only "onboarding step" the app
  /// needs — no form, no phone number, no e-mail.
  Future<IdentityKeyPair> loadOrCreate() async {
    final existing = await load();
    if (existing != null) {
      return existing;
    }
    final created = await IdentityKeyPair.generateRandom();
    await save(created);
    return created;
  }
}
