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

    testWidgets(
        'refreshes on the next poll tick even if another poller already '
        'stored the message (e.g. ContactsPage polling in the background)',
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

      await tester.pumpWidget(MaterialApp(
        home: ChatPage(
            sessionManager: me, store: meStore, contactAccountId: contactId),
      ));
      await tester.pump();
      expect(find.text('binnengekomen via een andere poller'), findsNothing);

      // Simulate another poller (ContactsPage, still alive underneath this
      // page in the nav stack) having already fetched-and-acked the
      // envelope: the message lands straight in the store, without
      // ChatPage's own poll call ever seeing it in its own
      // pollAndDecrypt() result.
      await meStore.saveMessage(
        contactId: contactId,
        direction: 'in',
        body: 'binnengekomen via een andere poller',
      );

      // Let ChatPage's own 3-second poll timer fire once.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('binnengekomen via een andere poller'), findsOneWidget);
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
