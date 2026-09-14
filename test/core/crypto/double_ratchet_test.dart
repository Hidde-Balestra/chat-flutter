import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/crypto_algorithms.dart';
import 'package:privacychat/core/crypto/double_ratchet.dart';

void main() {
  group('DoubleRatchetSession', () {
    late List<int> sharedSecret;
    late SimpleKeyPair bobInitialKeyPair;

    setUp(() async {
      sharedSecret = List<int>.generate(32, (i) => i);
      bobInitialKeyPair = await CryptoAlgorithms.x25519.newKeyPair();
    });

    Future<(DoubleRatchetSession, DoubleRatchetSession)> freshPair() async {
      final bobPublic = await bobInitialKeyPair.extractPublicKey();
      final alice = await DoubleRatchetSession.initAsInitiator(
        sharedSecret: sharedSecret,
        remoteRatchetPublicKey: bobPublic,
      );
      final bob = DoubleRatchetSession.initAsResponder(
        sharedSecret: sharedSecret,
        selfRatchetKeyPair: bobInitialKeyPair,
      );
      return (alice, bob);
    }

    test("Bob decrypts Alice's first message", () async {
      final (alice, bob) = await freshPair();
      final message = await alice.encrypt('hello bob'.codeUnits);
      final plaintext = await bob.decrypt(message);
      expect(String.fromCharCodes(plaintext), 'hello bob');
    });

    test('conversation flows back and forth across several DH ratchet steps', () async {
      final (alice, bob) = await freshPair();

      final m1 = await alice.encrypt('hi bob'.codeUnits);
      expect(String.fromCharCodes(await bob.decrypt(m1)), 'hi bob');

      final m2 = await bob.encrypt('hi alice'.codeUnits);
      expect(String.fromCharCodes(await alice.decrypt(m2)), 'hi alice');

      final m3 = await alice.encrypt('how are you'.codeUnits);
      expect(String.fromCharCodes(await bob.decrypt(m3)), 'how are you');

      final m4 = await bob.encrypt('great, you?'.codeUnits);
      expect(String.fromCharCodes(await alice.decrypt(m4)), 'great, you?');
    });

    test('out-of-order delivery still decrypts via skipped message keys', () async {
      final (alice, bob) = await freshPair();

      final m1 = await alice.encrypt('one'.codeUnits);
      final m2 = await alice.encrypt('two'.codeUnits);
      final m3 = await alice.encrypt('three'.codeUnits);

      expect(String.fromCharCodes(await bob.decrypt(m2)), 'two');
      expect(String.fromCharCodes(await bob.decrypt(m3)), 'three');
      expect(String.fromCharCodes(await bob.decrypt(m1)), 'one');
    });

    test('messages stay readable across many ratchet steps in a long conversation', () async {
      final (alice, bob) = await freshPair();
      DoubleRatchetSession sender = alice;
      DoubleRatchetSession receiver = bob;

      for (var i = 0; i < 20; i++) {
        final text = 'message $i';
        final message = await sender.encrypt(text.codeUnits);
        final plaintext = await receiver.decrypt(message);
        expect(String.fromCharCodes(plaintext), text);

        final tmp = sender;
        sender = receiver;
        receiver = tmp;
      }
    });

    test('a session restored from storage keeps working', () async {
      final (alice, bob) = await freshPair();

      final m1 = await alice.encrypt('before restore'.codeUnits);
      expect(String.fromCharCodes(await bob.decrypt(m1)), 'before restore');

      final restoredBob = await DoubleRatchetSession.fromStorage(await bob.toStorage());

      final m2 = await alice.encrypt('after restore'.codeUnits);
      expect(String.fromCharCodes(await restoredBob.decrypt(m2)), 'after restore');

      final m3 = await restoredBob.encrypt('reply after restore'.codeUnits);
      expect(String.fromCharCodes(await alice.decrypt(m3)), 'reply after restore');
    });

    test('a duplicate delivery of an already-processed message is rejected', () async {
      final (alice, bob) = await freshPair();
      final message = await alice.encrypt('once'.codeUnits);

      expect(String.fromCharCodes(await bob.decrypt(message)), 'once');
      expect(() => bob.decrypt(message), throwsStateError);
    });

    test('tampered ciphertext fails to decrypt', () async {
      final (alice, bob) = await freshPair();
      final message = await alice.encrypt('secret'.codeUnits);
      final mutated = [...message.ciphertext];
      mutated[0] = mutated[0] ^ 0xff;
      final tampered = RatchetMessage(header: message.header, ciphertext: mutated);

      expect(() => bob.decrypt(tampered), throwsA(anything));
    });

    test('mismatched associated data fails to decrypt', () async {
      final (alice, bob) = await freshPair();
      final message = await alice.encrypt(
        'secret'.codeUnits,
        associatedData: 'conversation-1'.codeUnits,
      );

      expect(
        () => bob.decrypt(message, associatedData: 'conversation-2'.codeUnits),
        throwsA(anything),
      );
    });
  });
}
