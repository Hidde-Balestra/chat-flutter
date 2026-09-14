import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'crypto_algorithms.dart';
import 'identity_key_pair.dart';
import 'prekey_bundle.dart';

/// Result of Alice initiating a session: the shared secret to seed the
/// Double Ratchet with, plus everything Bob needs to derive the same secret
/// (sent alongside the first encrypted message).
class X3dhInitiationResult {
  X3dhInitiationResult({
    required this.sharedSecret,
    required this.ephemeralPublicKey,
    this.usedOneTimePreKeyId,
  });

  final List<int> sharedSecret;
  final SimplePublicKey ephemeralPublicKey;
  final int? usedOneTimePreKeyId;
}

/// Extended Triple Diffie-Hellman (X3DH), as specified by Signal. Lets two
/// parties agree on a shared secret using only public keys — one of them can
/// be fully offline at the time, since the server just hands out their
/// previously published prekeys.
class X3dh {
  X3dh._();

  /// Alice's side, after fetching Bob's [remoteBundle] from the server.
  static Future<X3dhInitiationResult> initiate({
    required IdentityKeyPair localIdentity,
    required RemotePreKeyBundle remoteBundle,
  }) async {
    if (!await remoteBundle.verifySignedPreKey()) {
      throw StateError('signed prekey signature is invalid — refusing to start a session');
    }

    final ephemeralKeyPair = await CryptoAlgorithms.x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

    final dh1 = await _dh(localIdentity.agreementKeyPair, remoteBundle.signedPreKey);
    final dh2 = await _dh(ephemeralKeyPair, remoteBundle.identityAgreementKey);
    final dh3 = await _dh(ephemeralKeyPair, remoteBundle.signedPreKey);
    final dh4 = remoteBundle.oneTimePreKey == null
        ? null
        : await _dh(ephemeralKeyPair, remoteBundle.oneTimePreKey!);

    final sharedSecret = await _deriveSharedSecret([dh1, dh2, dh3, if (dh4 != null) dh4]);

    return X3dhInitiationResult(
      sharedSecret: sharedSecret,
      ephemeralPublicKey: ephemeralPublicKey,
      usedOneTimePreKeyId: remoteBundle.oneTimePreKeyId,
    );
  }

  /// Bob's side: reconstructs the same shared secret from Alice's identity
  /// and ephemeral public keys, which travel alongside her first message.
  static Future<List<int>> respond({
    required IdentityKeyPair localIdentity,
    required SimpleKeyPair localSignedPreKeyPair,
    SimpleKeyPair? localOneTimePreKeyPair,
    required SimplePublicKey remoteIdentityAgreementKey,
    required SimplePublicKey remoteEphemeralKey,
  }) async {
    final dh1 = await _dh(localSignedPreKeyPair, remoteIdentityAgreementKey);
    final dh2 = await _dh(localIdentity.agreementKeyPair, remoteEphemeralKey);
    final dh3 = await _dh(localSignedPreKeyPair, remoteEphemeralKey);
    final dh4 = localOneTimePreKeyPair == null
        ? null
        : await _dh(localOneTimePreKeyPair, remoteEphemeralKey);

    return _deriveSharedSecret([dh1, dh2, dh3, if (dh4 != null) dh4]);
  }

  static Future<List<int>> _dh(SimpleKeyPair keyPair, SimplePublicKey remotePublicKey) async {
    final secretKey = await CryptoAlgorithms.x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublicKey,
    );
    return secretKey.extractBytes();
  }

  static Future<List<int>> _deriveSharedSecret(List<List<int>> dhOutputs) async {
    // Per the X3DH spec: prefix the input keying material with 32 0xFF bytes
    // when using a Montgomery curve like X25519, so the key material can
    // never collide with a valid Ed25519/X25519 encoding of something else.
    final ikm = <int>[
      ...List<int>.filled(32, 0xff),
      for (final dh in dhOutputs) ...dh,
    ];

    final derived = await CryptoAlgorithms.hkdf32.deriveKey(
      secretKey: SecretKey(ikm),
      info: utf8.encode('privacychat-x3dh-v1'),
    );
    return derived.extractBytes();
  }
}
