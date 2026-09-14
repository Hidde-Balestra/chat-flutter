import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/crypto_algorithms.dart';
import 'package:privacychat/core/crypto/double_ratchet.dart';
import 'package:privacychat/core/messaging/wire_format.dart';

void main() {
  group('WireFormat', () {
    test('prekey message round-trips, including the one-time prekey id',
        () async {
      final identityKeyPair = await CryptoAlgorithms.x25519.newKeyPair();
      final ephemeralKeyPair = await CryptoAlgorithms.x25519.newKeyPair();
      final header = RatchetHeader(
        dhPublicKey: await (await CryptoAlgorithms.x25519.newKeyPair())
            .extractPublicKey(),
        previousChainLength: 3,
        messageNumber: 7,
      );
      final ratchetMessage =
          RatchetMessage(header: header, ciphertext: [1, 2, 3, 4, 5]);

      final encoded = WireFormat.encodePrekeyMessage(
        senderIdentityAgreementKey: await identityKeyPair.extractPublicKey(),
        senderEphemeralKey: await ephemeralKeyPair.extractPublicKey(),
        signedPreKeyId: 42,
        oneTimePreKeyId: 99,
        ratchetMessage: ratchetMessage,
      );

      final decoded = WireFormat.decodePrekeyMessage(encoded);

      expect(decoded.senderIdentityAgreementKey.bytes,
          (await identityKeyPair.extractPublicKey()).bytes);
      expect(decoded.senderEphemeralKey.bytes,
          (await ephemeralKeyPair.extractPublicKey()).bytes);
      expect(decoded.signedPreKeyId, 42);
      expect(decoded.oneTimePreKeyId, 99);
      expect(decoded.ratchetMessage.header.previousChainLength, 3);
      expect(decoded.ratchetMessage.header.messageNumber, 7);
      expect(decoded.ratchetMessage.ciphertext, [1, 2, 3, 4, 5]);
    });

    test('prekey message round-trips without a one-time prekey', () async {
      final identityKeyPair = await CryptoAlgorithms.x25519.newKeyPair();
      final ephemeralKeyPair = await CryptoAlgorithms.x25519.newKeyPair();
      final header = RatchetHeader(
        dhPublicKey: await (await CryptoAlgorithms.x25519.newKeyPair())
            .extractPublicKey(),
        previousChainLength: 0,
        messageNumber: 0,
      );
      final ratchetMessage = RatchetMessage(header: header, ciphertext: [9]);

      final encoded = WireFormat.encodePrekeyMessage(
        senderIdentityAgreementKey: await identityKeyPair.extractPublicKey(),
        senderEphemeralKey: await ephemeralKeyPair.extractPublicKey(),
        signedPreKeyId: 1,
        ratchetMessage: ratchetMessage,
      );

      final decoded = WireFormat.decodePrekeyMessage(encoded);

      expect(decoded.oneTimePreKeyId, isNull);
    });

    test('normal message round-trips', () async {
      final header = RatchetHeader(
        dhPublicKey: await (await CryptoAlgorithms.x25519.newKeyPair())
            .extractPublicKey(),
        previousChainLength: 12,
        messageNumber: 5,
      );
      final ratchetMessage =
          RatchetMessage(header: header, ciphertext: [10, 20, 30]);

      final encoded = WireFormat.encodeNormalMessage(ratchetMessage);
      final decoded = WireFormat.decodeNormalMessage(encoded);

      expect(decoded.header.dhPublicKey.bytes, header.dhPublicKey.bytes);
      expect(decoded.header.previousChainLength, 12);
      expect(decoded.header.messageNumber, 5);
      expect(decoded.ciphertext, [10, 20, 30]);
    });
  });
}
