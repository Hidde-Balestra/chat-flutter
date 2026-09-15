import 'dart:convert';

/// The plaintext that actually gets encrypted by the Double Ratchet — a
/// tiny tagged envelope distinguishing a plain 1:1 message from a group
/// message. Group messages are still delivered as an individually-
/// encrypted copy to each member's own 1:1 session (see
/// SessionManager.sendGroupMessage for why groups don't use a shared
/// "sender key" scheme here) — this tag is how the recipient's device
/// tells the two apart after decrypting, so it can route the message into
/// the right local conversation.
class MessagePayload {
  MessagePayload({required this.body, this.groupId});

  final String body;

  /// Null for an ordinary 1:1 message.
  final String? groupId;

  static const _directTag = 0;
  static const _groupTag = 1;

  List<int> encode() {
    if (groupId == null) {
      return [_directTag, ...utf8.encode(body)];
    }
    final wrapped = jsonEncode({'g': groupId, 'b': body});
    return [_groupTag, ...utf8.encode(wrapped)];
  }

  static MessagePayload decode(List<int> bytes) {
    if (bytes.isEmpty) {
      return MessagePayload(body: '');
    }
    final tag = bytes[0];
    final rest = bytes.sublist(1);
    if (tag == _groupTag) {
      final decoded = jsonDecode(utf8.decode(rest)) as Map<String, dynamic>;
      return MessagePayload(
        body: decoded['b'] as String,
        groupId: decoded['g'] as String,
      );
    }
    return MessagePayload(body: utf8.decode(rest));
  }
}
