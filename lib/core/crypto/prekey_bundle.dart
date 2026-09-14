import 'package:cryptography/cryptography.dart';

import 'crypto_algorithms.dart';

/// A signed prekey the client publishes to the server so peers can start a
/// session even while this device is offline. Rotated periodically; the
/// private half never leaves the device.
class SignedPreKey {
  SignedPreKey({required this.id, required this.keyPair});

  final int id;
  final SimpleKeyPair keyPair;

  static Future<SignedPreKey> generate(int id) async {
    final keyPair = await CryptoAlgorithms.x25519.newKeyPair();
    return SignedPreKey(id: id, keyPair: keyPair);
  }
}

/// A single-use prekey. The server hands out (and marks used) one per
/// session-establishment request, giving forward secrecy even for the very
/// first message of a conversation.
class OneTimePreKey {
  OneTimePreKey({required this.id, required this.keyPair});

  final int id;
  final SimpleKeyPair keyPair;

  static Future<OneTimePreKey> generate(int id) async {
    final keyPair = await CryptoAlgorithms.x25519.newKeyPair();
    return OneTimePreKey(id: id, keyPair: keyPair);
  }
}

/// The public bundle fetched from the server in order to start a session
/// with a peer (the "Bob" side of X3DH, from Alice's point of view).
class RemotePreKeyBundle {
  RemotePreKeyBundle({
    required this.accountId,
    required this.identitySigningKey,
    required this.identityAgreementKey,
    required this.signedPreKey,
    required this.signedPreKeySignature,
    required this.signedPreKeyId,
    this.oneTimePreKey,
    this.oneTimePreKeyId,
  });

  final String accountId;
  final SimplePublicKey identitySigningKey;
  final SimplePublicKey identityAgreementKey;
  final SimplePublicKey signedPreKey;
  final List<int> signedPreKeySignature;
  final int signedPreKeyId;
  final SimplePublicKey? oneTimePreKey;
  final int? oneTimePreKeyId;

  /// Must be checked before using this bundle — it proves the signed prekey
  /// really was produced by whoever holds [identitySigningKey], so a
  /// malicious/compromised server can't swap in a prekey of its own.
  Future<bool> verifySignedPreKey() {
    return CryptoAlgorithms.ed25519.verify(
      signedPreKey.bytes,
      signature: Signature(signedPreKeySignature, publicKey: identitySigningKey),
    );
  }
}
