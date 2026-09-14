import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';

import 'crypto_algorithms.dart';
import 'hex.dart';

const _listEquality = ListEquality<int>();

/// Public header sent alongside every ratchet message. The receiver needs it
/// to know which DH ratchet step and which position in the chain a message
/// belongs to; it is also bound into the AEAD associated data so it can't be
/// tampered with in transit.
class RatchetHeader {
  const RatchetHeader({
    required this.dhPublicKey,
    required this.previousChainLength,
    required this.messageNumber,
  });

  final SimplePublicKey dhPublicKey;
  final int previousChainLength;
  final int messageNumber;

  List<int> serialize() {
    final builder = BytesBuilder();
    builder.add(dhPublicKey.bytes);
    builder.add(_uint32be(previousChainLength));
    builder.add(_uint32be(messageNumber));
    return builder.toBytes();
  }

  static RatchetHeader deserialize(List<int> bytes) {
    if (bytes.length != 40) {
      throw ArgumentError('a serialized ratchet header is always 40 bytes');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return RatchetHeader(
      dhPublicKey:
          SimplePublicKey(bytes.sublist(0, 32), type: KeyPairType.x25519),
      previousChainLength: data.getUint32(32, Endian.big),
      messageNumber: data.getUint32(36, Endian.big),
    );
  }

  static List<int> _uint32be(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.big);
    return data.buffer.asUint8List();
  }
}

/// A header plus its encrypted, authenticated payload — the unit that
/// actually travels over the mailbox.
class RatchetMessage {
  const RatchetMessage({required this.header, required this.ciphertext});

  final RatchetHeader header;

  /// AEAD ciphertext + tag. No nonce is transmitted — sender and receiver
  /// each independently derive it from the (never-reused) message key.
  final List<int> ciphertext;
}

/// The Double Ratchet algorithm, as specified by Signal: a per-message
/// symmetric-key ratchet combined with a per-DH-ratchet-step asymmetric
/// ratchet. Gives forward secrecy (past messages stay secret if a later key
/// leaks) and break-in recovery (the session heals after a compromise, as
/// soon as both sides send a fresh DH ratchet key).
class DoubleRatchetSession {
  DoubleRatchetSession._({
    required SimpleKeyPair selfRatchetKeyPair,
    SimplePublicKey? remoteRatchetPublicKey,
    required List<int> rootKey,
    List<int>? sendingChainKey,
    List<int>? receivingChainKey,
    int sendingMessageNumber = 0,
    int receivingMessageNumber = 0,
    int previousSendingChainLength = 0,
  })  : _selfRatchetKeyPair = selfRatchetKeyPair,
        _remoteRatchetPublicKey = remoteRatchetPublicKey,
        _rootKey = rootKey,
        _sendingChainKey = sendingChainKey,
        _receivingChainKey = receivingChainKey,
        _sendingMessageNumber = sendingMessageNumber,
        _receivingMessageNumber = receivingMessageNumber,
        _previousSendingChainLength = previousSendingChainLength;

  static const int _maxSkippedMessageKeys = 1000;

  SimpleKeyPair _selfRatchetKeyPair;
  SimplePublicKey? _remoteRatchetPublicKey;
  List<int> _rootKey;
  List<int>? _sendingChainKey;
  List<int>? _receivingChainKey;
  int _sendingMessageNumber;
  int _receivingMessageNumber;
  int _previousSendingChainLength;

  final Map<String, List<int>> _skippedMessageKeys = {};

  /// Alice: she just ran X3DH and knows Bob's initial ratchet public key
  /// (his signed prekey).
  static Future<DoubleRatchetSession> initAsInitiator({
    required List<int> sharedSecret,
    required SimplePublicKey remoteRatchetPublicKey,
  }) async {
    final selfKeyPair = await CryptoAlgorithms.x25519.newKeyPair();
    final session = DoubleRatchetSession._(
      selfRatchetKeyPair: selfKeyPair,
      remoteRatchetPublicKey: remoteRatchetPublicKey,
      rootKey: sharedSecret,
    );
    final dhOut =
        await session._dh(session._selfRatchetKeyPair, remoteRatchetPublicKey);
    final derived = await session._kdfRk(session._rootKey, dhOut);
    session._rootKey = derived.rootKey;
    session._sendingChainKey = derived.chainKey;
    return session;
  }

  /// Bob: he just ran X3DH and reuses his signed prekey pair as the initial
  /// ratchet key pair. His sending/receiving chains stay empty until Alice's
  /// first message triggers the first DH ratchet step.
  static DoubleRatchetSession initAsResponder({
    required List<int> sharedSecret,
    required SimpleKeyPair selfRatchetKeyPair,
  }) {
    return DoubleRatchetSession._(
      selfRatchetKeyPair: selfRatchetKeyPair,
      rootKey: sharedSecret,
    );
  }

  /// Serializes the full session state (including private key material) so
  /// it can be persisted locally between app launches. Store the result
  /// somewhere encrypted at rest — it is as sensitive as a private key.
  Future<Map<String, dynamic>> toStorage() async {
    final selfPrivateKey = await _selfRatchetKeyPair.extractPrivateKeyBytes();
    return {
      'selfRatchetPrivateKey': base64Encode(selfPrivateKey),
      'remoteRatchetPublicKey': _remoteRatchetPublicKey == null
          ? null
          : base64Encode(_remoteRatchetPublicKey!.bytes),
      'rootKey': base64Encode(_rootKey),
      'sendingChainKey':
          _sendingChainKey == null ? null : base64Encode(_sendingChainKey!),
      'receivingChainKey':
          _receivingChainKey == null ? null : base64Encode(_receivingChainKey!),
      'sendingMessageNumber': _sendingMessageNumber,
      'receivingMessageNumber': _receivingMessageNumber,
      'previousSendingChainLength': _previousSendingChainLength,
      'skippedMessageKeys': _skippedMessageKeys
          .map((key, value) => MapEntry(key, base64Encode(value))),
    };
  }

  static Future<DoubleRatchetSession> fromStorage(
      Map<String, dynamic> json) async {
    final selfRatchetKeyPair = await CryptoAlgorithms.x25519.newKeyPairFromSeed(
        base64Decode(json['selfRatchetPrivateKey'] as String));

    final session = DoubleRatchetSession._(
      selfRatchetKeyPair: selfRatchetKeyPair,
      remoteRatchetPublicKey: json['remoteRatchetPublicKey'] == null
          ? null
          : SimplePublicKey(
              base64Decode(json['remoteRatchetPublicKey'] as String),
              type: KeyPairType.x25519,
            ),
      rootKey: base64Decode(json['rootKey'] as String),
      sendingChainKey: json['sendingChainKey'] == null
          ? null
          : base64Decode(json['sendingChainKey'] as String),
      receivingChainKey: json['receivingChainKey'] == null
          ? null
          : base64Decode(json['receivingChainKey'] as String),
      sendingMessageNumber: json['sendingMessageNumber'] as int,
      receivingMessageNumber: json['receivingMessageNumber'] as int,
      previousSendingChainLength: json['previousSendingChainLength'] as int,
    );

    final skipped = (json['skippedMessageKeys'] as Map).cast<String, dynamic>();
    for (final entry in skipped.entries) {
      session._skippedMessageKeys[entry.key] =
          base64Decode(entry.value as String);
    }
    return session;
  }

  Future<RatchetMessage> encrypt(List<int> plaintext,
      {List<int> associatedData = const []}) async {
    if (_sendingChainKey == null) {
      throw StateError(
          'no sending chain yet — nothing has been received to ratchet on');
    }

    final stepped = await _kdfCk(_sendingChainKey!);
    _sendingChainKey = stepped.chainKey;

    final header = RatchetHeader(
      dhPublicKey: await _selfRatchetKeyPair.extractPublicKey(),
      previousChainLength: _previousSendingChainLength,
      messageNumber: _sendingMessageNumber,
    );
    _sendingMessageNumber += 1;

    final ciphertext =
        await _seal(stepped.messageKey, plaintext, header, associatedData);
    return RatchetMessage(header: header, ciphertext: ciphertext);
  }

  Future<List<int>> decrypt(RatchetMessage message,
      {List<int> associatedData = const []}) async {
    final skippedKey = _skippedKeyFor(message.header);
    final skippedMessageKey = _skippedMessageKeys.remove(skippedKey);
    if (skippedMessageKey != null) {
      return _open(skippedMessageKey, message, associatedData);
    }

    final isNewRatchetKey = _remoteRatchetPublicKey == null ||
        !_listEquality.equals(
            _remoteRatchetPublicKey!.bytes, message.header.dhPublicKey.bytes);

    if (!isNewRatchetKey &&
        message.header.messageNumber < _receivingMessageNumber) {
      // Already processed on this chain (its key was consumed, not skipped),
      // and this isn't a match in _skippedMessageKeys either — a duplicate
      // delivery. Reject explicitly instead of deriving the wrong message
      // key, which would silently advance the chain past the next real key.
      throw StateError('duplicate or already-processed message');
    }

    if (isNewRatchetKey) {
      await _skipReceivingMessageKeys(message.header.previousChainLength);
      await _dhRatchetStep(message.header.dhPublicKey);
    }

    await _skipReceivingMessageKeys(message.header.messageNumber);

    final stepped = await _kdfCk(_receivingChainKey!);
    _receivingChainKey = stepped.chainKey;
    _receivingMessageNumber += 1;

    return _open(stepped.messageKey, message, associatedData);
  }

  Future<void> _dhRatchetStep(SimplePublicKey newRemoteRatchetKey) async {
    _previousSendingChainLength = _sendingMessageNumber;
    _sendingMessageNumber = 0;
    _receivingMessageNumber = 0;
    _remoteRatchetPublicKey = newRemoteRatchetKey;

    final receivingDh = await _dh(_selfRatchetKeyPair, newRemoteRatchetKey);
    final receivingDerived = await _kdfRk(_rootKey, receivingDh);
    _rootKey = receivingDerived.rootKey;
    _receivingChainKey = receivingDerived.chainKey;

    _selfRatchetKeyPair = await CryptoAlgorithms.x25519.newKeyPair();

    final sendingDh = await _dh(_selfRatchetKeyPair, newRemoteRatchetKey);
    final sendingDerived = await _kdfRk(_rootKey, sendingDh);
    _rootKey = sendingDerived.rootKey;
    _sendingChainKey = sendingDerived.chainKey;
  }

  Future<void> _skipReceivingMessageKeys(int until) async {
    if (_receivingChainKey == null) {
      return;
    }
    if (until - _receivingMessageNumber > _maxSkippedMessageKeys) {
      throw StateError(
          'refusing to skip more than $_maxSkippedMessageKeys message keys');
    }
    while (_receivingMessageNumber < until) {
      final stepped = await _kdfCk(_receivingChainKey!);
      _receivingChainKey = stepped.chainKey;
      _skippedMessageKeys[_skippedKeyFor(RatchetHeader(
        dhPublicKey: _remoteRatchetPublicKey!,
        previousChainLength: 0,
        messageNumber: _receivingMessageNumber,
      ))] = stepped.messageKey;
      _receivingMessageNumber += 1;
    }
  }

  String _skippedKeyFor(RatchetHeader header) =>
      '${bytesToHex(header.dhPublicKey.bytes)}:${header.messageNumber}';

  Future<List<int>> _dh(
      SimpleKeyPair keyPair, SimplePublicKey remotePublicKey) async {
    final secretKey = await CryptoAlgorithms.x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublicKey,
    );
    return secretKey.extractBytes();
  }

  Future<({List<int> rootKey, List<int> chainKey})> _kdfRk(
      List<int> rootKey, List<int> dhOut) async {
    final derived = await CryptoAlgorithms.hkdf64.deriveKey(
      secretKey: SecretKey(dhOut),
      nonce: rootKey,
      info: utf8.encode('privacychat-ratchet-rk-v1'),
    );
    final bytes = await derived.extractBytes();
    return (rootKey: bytes.sublist(0, 32), chainKey: bytes.sublist(32, 64));
  }

  Future<({List<int> chainKey, List<int> messageKey})> _kdfCk(
      List<int> chainKey) async {
    final chainMac = await CryptoAlgorithms.hmacSha256.calculateMac(
      const [0x02],
      secretKey: SecretKey(chainKey),
    );
    final messageMac = await CryptoAlgorithms.hmacSha256.calculateMac(
      const [0x01],
      secretKey: SecretKey(chainKey),
    );
    return (chainKey: chainMac.bytes, messageKey: messageMac.bytes);
  }

  Future<({List<int> key, List<int> nonce})> _cipherParamsFor(
      List<int> messageKey) async {
    final derived = await CryptoAlgorithms.hkdf44.deriveKey(
      secretKey: SecretKey(messageKey),
      info: utf8.encode('privacychat-ratchet-msg-v1'),
    );
    final bytes = await derived.extractBytes();
    return (key: bytes.sublist(0, 32), nonce: bytes.sublist(32, 44));
  }

  Future<List<int>> _seal(
    List<int> messageKey,
    List<int> plaintext,
    RatchetHeader header,
    List<int> associatedData,
  ) async {
    final params = await _cipherParamsFor(messageKey);
    final box = await CryptoAlgorithms.aead.encrypt(
      plaintext,
      secretKey: SecretKey(params.key),
      nonce: params.nonce,
      aad: [...associatedData, ...header.serialize()],
    );
    return box.concatenation(nonce: false);
  }

  Future<List<int>> _open(
    List<int> messageKey,
    RatchetMessage message,
    List<int> associatedData,
  ) async {
    final params = await _cipherParamsFor(messageKey);
    final macLength = CryptoAlgorithms.aead.macAlgorithm.macLength;
    final cipherTextLength = message.ciphertext.length - macLength;
    if (cipherTextLength < 0) {
      throw StateError(
          'ciphertext shorter than the AEAD tag — malformed message');
    }

    final box = SecretBox(
      message.ciphertext.sublist(0, cipherTextLength),
      nonce: params.nonce,
      mac: Mac(message.ciphertext.sublist(cipherTextLength)),
    );

    return CryptoAlgorithms.aead.decrypt(
      box,
      secretKey: SecretKey(params.key),
      aad: [...associatedData, ...message.header.serialize()],
    );
  }
}
