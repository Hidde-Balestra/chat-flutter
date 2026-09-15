import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/messaging/message_payload.dart';

void main() {
  group('MessagePayload', () {
    test('round-trips a plain 1:1 message with no group id', () {
      final encoded = MessagePayload(body: 'hoi daar!').encode();
      final decoded = MessagePayload.decode(encoded);

      expect(decoded.body, 'hoi daar!');
      expect(decoded.groupId, isNull);
    });

    test('round-trips a group message', () {
      final encoded =
          MessagePayload(body: 'hoi allemaal', groupId: 'group-123').encode();
      final decoded = MessagePayload.decode(encoded);

      expect(decoded.body, 'hoi allemaal');
      expect(decoded.groupId, 'group-123');
    });

    test(
        'a direct message never decodes with a group id, even if the '
        'text itself looks like the group JSON shape', () {
      final encoded = MessagePayload(body: '{"g":"fake","b":"trick"}').encode();
      final decoded = MessagePayload.decode(encoded);

      expect(decoded.body, '{"g":"fake","b":"trick"}');
      expect(decoded.groupId, isNull);
    });

    test('handles unicode text correctly', () {
      final encoded =
          MessagePayload(body: 'héllo 👋 groep', groupId: 'g1').encode();
      final decoded = MessagePayload.decode(encoded);

      expect(decoded.body, 'héllo 👋 groep');
      expect(decoded.groupId, 'g1');
    });
  });
}
