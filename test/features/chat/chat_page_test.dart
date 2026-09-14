import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/messaging/session_manager.dart';
import 'package:privacychat/features/chat/chat_page.dart';

import '../../core/messaging/fakes.dart';

void main() {
  group('ChatPage', () {
    testWidgets('shows existing messages and lets you send a new one',
        (tester) async {
      final server = FakeServer();
      final meIdentity = await IdentityKeyPair.generateRandom();
      final contactIdentity = await IdentityKeyPair.generateRandom();
      final meStore = InMemoryLocalStore();

      final me = SessionManager(
          identity: meIdentity,
          backend: FakeChatBackend(server),
          store: meStore);
      final contact = SessionManager(
        identity: contactIdentity,
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );

      await me.bootstrap();
      await contact.bootstrap();
      final contactId = await contact.accountId;

      await meStore.upsertContact(contactId);
      await meStore.saveMessage(
          contactId: contactId, direction: 'in', body: 'hoi!');

      await tester.pumpWidget(MaterialApp(
        home: ChatPage(
            sessionManager: me, store: meStore, contactAccountId: contactId),
      ));
      await tester.pump();

      expect(find.text('hoi!'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nieuw bericht');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('nieuw bericht'), findsOneWidget);
      expect(await meStore.messagesWith(contactId), hasLength(2));
    });

    testWidgets('shows an empty state when there are no messages yet',
        (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();

      await tester.pumpWidget(MaterialApp(
        home: ChatPage(
          sessionManager: me,
          store: InMemoryLocalStore(),
          contactAccountId: '05${'11' * 32}',
        ),
      ));
      await tester.pump();

      expect(find.text('Nog geen berichten. Zeg iets!'), findsOneWidget);
    });
  });
}
