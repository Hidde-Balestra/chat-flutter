import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'crypto_algorithms.dart';
import 'hex.dart';

/// The permanent, locally-generated identity for this account. It never
/// contains — and is never derived from — a phone number, e-mail address or
/// any other piece of real-world identifying data. Everything the server
/// ever sees is a public key or a signature.
class IdentityKeyPair {
  IdentityKeyPair._({
    required this.seed,
    required this.signingKeyPair,
    required this.agreementKeyPair,
  });

  /// The 32-byte master seed both keys are derived from. This is the only
  /// thing that needs to be backed up (as a recovery phrase) to restore the
  /// full identity on a new device — treat it like a private key.
  final List<int> seed;

  /// Ed25519 — used to derive the account id and to sign things (e.g. the
  /// signed prekey, login challenges).
  final SimpleKeyPair signingKeyPair;

  /// X25519 — used for Diffie-Hellman key agreement (X3DH, Double Ratchet).
  final SimpleKeyPair agreementKeyPair;

  /// Generates a brand-new identity from fresh randomness. Call this exactly
  /// once, on first launch, before the user has entered anything at all.
  static Future<IdentityKeyPair> generateRandom() async {
    final random = Random.secure();
    final seed = List<int>.generate(32, (_) => random.nextInt(256));
    return fromSeed(seed);
  }

  /// Restores an identity deterministically from a 32-byte seed, e.g. one
  /// decoded from a recovery phrase the user typed in on a new device.
  static Future<IdentityKeyPair> fromSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw ArgumentError('seed must be exactly 32 bytes');
    }

    final signingSeed =
        await _deriveSubSeed(seed, 'privacychat-identity-sign-v1');
    final agreementSeed =
        await _deriveSubSeed(seed, 'privacychat-identity-dh-v1');

    final signingKeyPair =
        await CryptoAlgorithms.ed25519.newKeyPairFromSeed(signingSeed);
    final agreementKeyPair =
        await CryptoAlgorithms.x25519.newKeyPairFromSeed(agreementSeed);

    return IdentityKeyPair._(
      seed: seed,
      signingKeyPair: signingKeyPair,
      agreementKeyPair: agreementKeyPair,
    );
  }

  static Future<List<int>> _deriveSubSeed(List<int> seed, String info) async {
    final derived = await CryptoAlgorithms.hkdf32.deriveKey(
      secretKey: SecretKey(seed),
      info: utf8.encode(info),
    );
    return derived.extractBytes();
  }

  Future<SimplePublicKey> get signingPublicKey =>
      signingKeyPair.extractPublicKey();

  Future<SimplePublicKey> get agreementPublicKey =>
      agreementKeyPair.extractPublicKey();

  /// The public, permanent account id: "05" + hex(Ed25519 public key) — the
  /// same convention Session uses for its Session IDs. Purely derived from a
  /// locally generated key; contains no personal data whatsoever.
  Future<String> accountId() async {
    final publicKey = await signingPublicKey;
    return '05${bytesToHex(publicKey.bytes)}';
  }

  Future<Signature> sign(List<int> message) {
    return CryptoAlgorithms.ed25519.sign(message, keyPair: signingKeyPair);
  }
}
