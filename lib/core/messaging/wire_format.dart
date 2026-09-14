import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../crypto/double_ratchet.dart';

/// Byte layout for the two kinds of envelopes this app ever sends. The
/// server only ever sees these bytes as an opaque blob (`ciphertext` in the
/// mailbox table) — it has no idea what's inside.
class DecodedPrekeyMessage {
  DecodedPrekeyMessage({
    required this.senderIdentityAgreementKey,
    required this.senderEphemeralKey,
    required this.signedPreKeyId,
    required this.oneTimePreKeyId,
    required this.ratchetMessage,
  });

  final SimplePublicKey senderIdentityAgreementKey;
  final SimplePublicKey senderEphemeralKey;
  final int signedPreKeyId;
  final int? oneTimePreKeyId;
  final RatchetMessage ratchetMessage;
}

class WireFormat {
  WireFormat._();

  static const int _publicKeyLength = 32;
  static const int _headerLength = 40; // see RatchetHeader.serialize()

  /// The very first message ever sent to a contact: everything the
  /// recipient needs to complete X3DH on their end (their prekeys were
  /// already published, so only the sender's half needs to travel), followed
  /// by the usual ratchet header + ciphertext.
  static List<int> encodePrekeyMessage({
    required SimplePublicKey senderIdentityAgreementKey,
    required SimplePublicKey senderEphemeralKey,
    required int signedPreKeyId,
    int? oneTimePreKeyId,
    required RatchetMessage ratchetMessage,
  }) {
    final builder = BytesBuilder();
    builder.add(senderIdentityAgreementKey.bytes);
    builder.add(senderEphemeralKey.bytes);
    builder.add(_uint32be(signedPreKeyId));
    builder.add([oneTimePreKeyId == null ? 0 : 1]);
    builder.add(_uint32be(oneTimePreKeyId ?? 0));
    builder.add(ratchetMessage.header.serialize());
    builder.add(ratchetMessage.ciphertext);
    return builder.toBytes();
  }

  static DecodedPrekeyMessage decodePrekeyMessage(List<int> bytes) {
    const minLength = _publicKeyLength * 2 + 4 + 1 + 4 + _headerLength;
    if (bytes.length < minLength) {
      throw ArgumentError('prekey message is too short to be valid');
    }

    var offset = 0;
    final identityAgreementKey = SimplePublicKey(
      bytes.sublist(offset, offset += _publicKeyLength),
      type: KeyPairType.x25519,
    );
    final ephemeralKey = SimplePublicKey(
      bytes.sublist(offset, offset += _publicKeyLength),
      type: KeyPairType.x25519,
    );
    final signedPreKeyId = _readUint32be(bytes, offset);
    offset += 4;
    final hasOneTimePreKey = bytes[offset] == 1;
    offset += 1;
    final oneTimePreKeyId = _readUint32be(bytes, offset);
    offset += 4;
    final header = RatchetHeader.deserialize(bytes.sublist(offset, offset + _headerLength));
    offset += _headerLength;
    final ciphertext = bytes.sublist(offset);

    return DecodedPrekeyMessage(
      senderIdentityAgreementKey: identityAgreementKey,
      senderEphemeralKey: ephemeralKey,
      signedPreKeyId: signedPreKeyId,
      oneTimePreKeyId: hasOneTimePreKey ? oneTimePreKeyId : null,
      ratchetMessage: RatchetMessage(header: header, ciphertext: ciphertext),
    );
  }

  /// Every message after the first one with a given contact: just the
  /// ratchet header + ciphertext, no X3DH fields needed anymore.
  static List<int> encodeNormalMessage(RatchetMessage ratchetMessage) {
    return [...ratchetMessage.header.serialize(), ...ratchetMessage.ciphertext];
  }

  static RatchetMessage decodeNormalMessage(List<int> bytes) {
    if (bytes.length < _headerLength) {
      throw ArgumentError('normal message is too short to be valid');
    }
    final header = RatchetHeader.deserialize(bytes.sublist(0, _headerLength));
    final ciphertext = bytes.sublist(_headerLength);
    return RatchetMessage(header: header, ciphertext: ciphertext);
  }

  static List<int> _uint32be(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  static int _readUint32be(List<int> bytes, int offset) {
    final data = ByteData.sublistView(Uint8List.fromList(bytes.sublist(offset, offset + 4)));
    return data.getUint32(0, Endian.big);
  }
}
