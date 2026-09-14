import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';

void main() {
  group('IdentityKeyPair', () {
    test('accountId has the expected shape and no personal data', () async {
      final identity = await IdentityKeyPair.generateRandom();
      final accountId = await identity.accountId();

      expect(accountId, startsWith('05'));
      expect(accountId, hasLength(66));
      expect(RegExp(r'^05[0-9a-f]{64}$').hasMatch(accountId), isTrue);
    });

    test('two random identities never collide', () async {
      final a = await IdentityKeyPair.generateRandom();
      final b = await IdentityKeyPair.generateRandom();

      expect(await a.accountId(), isNot(equals(await b.accountId())));
    });

    test('the same seed always restores the same account id', () async {
      final original = await IdentityKeyPair.generateRandom();
      final restored = await IdentityKeyPair.fromSeed(original.seed);

      expect(await restored.accountId(), equals(await original.accountId()));
    });

    test('rejects seeds that are not exactly 32 bytes', () async {
      expect(() => IdentityKeyPair.fromSeed(List<int>.filled(16, 0)), throwsArgumentError);
    });

    test('signatures verify against the public signing key', () async {
      final identity = await IdentityKeyPair.generateRandom();
      final message = 'a login challenge nonce'.codeUnits;

      final signature = await identity.sign(message);

      expect(signature.publicKey, equals(await identity.signingPublicKey));
    });
  });
}
