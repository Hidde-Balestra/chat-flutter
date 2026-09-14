import 'package:cryptography/cryptography.dart';

/// Central place for every cryptographic primitive used in the app. Keeping
/// one instance per algorithm (rather than constructing them ad-hoc) makes it
/// obvious, at a glance, exactly which primitives this app relies on.
class CryptoAlgorithms {
  CryptoAlgorithms._();

  static final X25519 x25519 = X25519();
  static final Ed25519 ed25519 = Ed25519();
  static final Hmac hmacSha256 = Hmac.sha256();
  static final Chacha20 aead = Chacha20.poly1305Aead();

  /// 32-byte output — used to derive sub-seeds and the X3DH shared secret.
  static final Hkdf hkdf32 = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// 64-byte output, split into a 32-byte root key + 32-byte chain key —
  /// used by the Double Ratchet's KDF_RK step.
  static final Hkdf hkdf64 = Hkdf(hmac: Hmac.sha256(), outputLength: 64);

  /// 44-byte output, split into a 32-byte cipher key + 12-byte nonce —
  /// used to turn a one-time-use message key into AEAD parameters.
  static final Hkdf hkdf44 = Hkdf(hmac: Hmac.sha256(), outputLength: 44);
}
