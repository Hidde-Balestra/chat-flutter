import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/crypto/prekey_bundle.dart';
import 'package:privacychat/core/crypto/x3dh.dart';

Future<RemotePreKeyBundle> _publishBundle(
  IdentityKeyPair bob,
  SignedPreKey signedPreKey, {
  OneTimePreKey? oneTimePreKey,
}) async {
  final signature =
      await bob.sign((await signedPreKey.keyPair.extractPublicKey()).bytes);
  return RemotePreKeyBundle(
    accountId: await bob.accountId(),
    identitySigningKey: await bob.signingPublicKey,
    identityAgreementKey: await bob.agreementPublicKey,
    signedPreKey: await signedPreKey.keyPair.extractPublicKey(),
    signedPreKeySignature: signature.bytes,
    signedPreKeyId: signedPreKey.id,
    oneTimePreKey: oneTimePreKey == null
        ? null
        : await oneTimePreKey.keyPair.extractPublicKey(),
    oneTimePreKeyId: oneTimePreKey?.id,
  );
}

void main() {
  group('X3dh', () {
    test(
        'initiator and responder derive the same shared secret (with one-time prekey)',
        () async {
      final alice = await IdentityKeyPair.generateRandom();
      final bob = await IdentityKeyPair.generateRandom();
      final bobSignedPreKey = await SignedPreKey.generate(1);
      final bobOneTimePreKey = await OneTimePreKey.generate(7);

      final bundle = await _publishBundle(bob, bobSignedPreKey,
          oneTimePreKey: bobOneTimePreKey);

      final initiation =
          await X3dh.initiate(localIdentity: alice, remoteBundle: bundle);

      final responderSecret = await X3dh.respond(
        localIdentity: bob,
        localSignedPreKeyPair: bobSignedPreKey.keyPair,
        localOneTimePreKeyPair: bobOneTimePreKey.keyPair,
        remoteIdentityAgreementKey: await alice.agreementPublicKey,
        remoteEphemeralKey: initiation.ephemeralPublicKey,
      );

      expect(initiation.sharedSecret, equals(responderSecret));
      expect(initiation.sharedSecret, hasLength(32));
    });

    test('still agrees when no one-time prekey is available', () async {
      final alice = await IdentityKeyPair.generateRandom();
      final bob = await IdentityKeyPair.generateRandom();
      final bobSignedPreKey = await SignedPreKey.generate(1);

      final bundle = await _publishBundle(bob, bobSignedPreKey);

      final initiation =
          await X3dh.initiate(localIdentity: alice, remoteBundle: bundle);

      final responderSecret = await X3dh.respond(
        localIdentity: bob,
        localSignedPreKeyPair: bobSignedPreKey.keyPair,
        remoteIdentityAgreementKey: await alice.agreementPublicKey,
        remoteEphemeralKey: initiation.ephemeralPublicKey,
      );

      expect(initiation.sharedSecret, equals(responderSecret));
    });

    test('rejects a bundle whose signed prekey signature was tampered with',
        () async {
      final alice = await IdentityKeyPair.generateRandom();
      final bob = await IdentityKeyPair.generateRandom();
      final bobSignedPreKey = await SignedPreKey.generate(1);

      final bundle = await _publishBundle(bob, bobSignedPreKey);
      final tampered = RemotePreKeyBundle(
        accountId: bundle.accountId,
        identitySigningKey: bundle.identitySigningKey,
        identityAgreementKey: bundle.identityAgreementKey,
        signedPreKey: bundle.signedPreKey,
        signedPreKeySignature: List<int>.filled(64, 0),
        signedPreKeyId: bundle.signedPreKeyId,
      );

      expect(
        () => X3dh.initiate(localIdentity: alice, remoteBundle: tampered),
        throwsStateError,
      );
    });

    test(
        'different runs produce different shared secrets (fresh ephemeral key)',
        () async {
      final alice = await IdentityKeyPair.generateRandom();
      final bob = await IdentityKeyPair.generateRandom();
      final bobSignedPreKey = await SignedPreKey.generate(1);
      final bundle = await _publishBundle(bob, bobSignedPreKey);

      final first =
          await X3dh.initiate(localIdentity: alice, remoteBundle: bundle);
      final second =
          await X3dh.initiate(localIdentity: alice, remoteBundle: bundle);

      expect(first.sharedSecret, isNot(equals(second.sharedSecret)));
    });
  });
}
