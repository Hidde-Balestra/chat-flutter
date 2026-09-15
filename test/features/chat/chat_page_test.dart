import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/crypto/safety_number.dart';
import 'package:privacychat/core/messaging/session_manager.dart';
import 'package:privacychat/core/storage/local_store.dart';
import 'package:privacychat/features/chat/chat_page.dart';
import 'package:privacychat/features/chat/safety_number_page.dart';

import '../../core/messaging/fakes.dart';
import '../../test_helpers/localized_test_app.dart';

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

      await tester.pumpWidget(localizedTestApp(ChatPage(
          sessionManager: me, store: meStore, contactAccountId: contactId)));
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

      await tester.pumpWidget(localizedTestApp(ChatPage(
          sessionManager: me, store: meStore, contactAccountId: contactId)));
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

      await tester.pumpWidget(localizedTestApp(ChatPage(
        sessionManager: me,
        store: InMemoryLocalStore(),
        contactAccountId: '05${'11' * 32}',
      )));
      await tester.pump();

      expect(find.text('Nog geen berichten. Zeg iets!'), findsOneWidget);
    });

    testWidgets(
        'a pending message request shows a banner and hides the input until accepted',
        (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      final store = InMemoryLocalStore();
      final requesterId = '05${'22' * 32}';
      await store.upsertContact(requesterId, status: ContactStatus.pending);
      await store.saveMessage(
          contactId: requesterId,
          direction: 'in',
          body: 'hoi, mag ik chatten?');

      await tester.pumpWidget(localizedTestApp(ChatPage(
          sessionManager: me, store: store, contactAccountId: requesterId)));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Accepteren'), findsOneWidget);
      expect(find.text('Weigeren'), findsOneWidget);
      expect(find.text('Blokkeren'), findsOneWidget);

      await tester.tap(find.text('Accepteren'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Accepteren'), findsNothing);
      expect((await store.getContact(requesterId))?.status,
          ContactStatus.accepted);
    });

    testWidgets('declining a message request removes the conversation',
        (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      final store = InMemoryLocalStore();
      final requesterId = '05${'33' * 32}';
      await store.upsertContact(requesterId, status: ContactStatus.pending);
      await store.saveMessage(
          contactId: requesterId, direction: 'in', body: 'spam?');

      await tester.pumpWidget(localizedTestApp(Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatPage(
                    sessionManager: me,
                    store: store,
                    contactAccountId: requesterId),
              )),
              child: const Text('open'),
            ),
          ),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weigeren'));
      await tester.pumpAndSettle();

      expect(await store.getContact(requesterId), isNull);
      expect(await store.messagesWith(requesterId), isEmpty);
    });

    testWidgets('blocking a contact clears the conversation and shows a banner',
        (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      final store = InMemoryLocalStore();
      final requesterId = '05${'44' * 32}';
      await store.upsertContact(requesterId, status: ContactStatus.pending);
      await store.saveMessage(
          contactId: requesterId, direction: 'in', body: 'vervelend bericht');

      await tester.pumpWidget(localizedTestApp(ChatPage(
          sessionManager: me, store: store, contactAccountId: requesterId)));
      await tester.pump();

      await tester.tap(find.text('Blokkeren'));
      await tester.pumpAndSettle();
      // Confirmation dialog.
      await tester.tap(find.text('Blokkeren').last);
      await tester.pumpAndSettle();

      expect(
          (await store.getContact(requesterId))?.status, ContactStatus.blocked);
      expect(await store.messagesWith(requesterId), isEmpty);
      expect(find.textContaining('geblokkeerd'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
        'tapping the contact name opens options to rename, block or delete',
        (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      final store = InMemoryLocalStore();
      final contactId = '05${'66' * 32}';
      await store.upsertContact(contactId, displayName: 'Vriend');

      await tester.pumpWidget(localizedTestApp(Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatPage(
                    sessionManager: me,
                    store: store,
                    contactAccountId: contactId),
              )),
              child: const Text('open'),
            ),
          ),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vriend'));
      await tester.pumpAndSettle();

      expect(find.text('Account ID bekijken'), findsOneWidget);
      expect(find.text('Naam aanpassen'), findsOneWidget);
      expect(find.text('Veiligheidsnummer'), findsOneWidget);
      expect(find.text('Blokkeren'), findsOneWidget);
      expect(find.text('Verwijderen'), findsOneWidget);

      await tester.tap(find.text('Verwijderen'));
      await tester.pumpAndSettle();
      // Confirmation dialog.
      await tester.tap(find.text('Verwijderen').last);
      await tester.pumpAndSettle();

      expect(await store.getContact(contactId), isNull);
      expect(find.text('open'), findsOneWidget); // popped back
    });

    testWidgets(
        'shows a plain "still connecting" message instead of a raw error '
        'when bootstrap has not succeeded yet', (tester) async {
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: UnreachableChatBackend(),
        store: InMemoryLocalStore(),
      );
      final contactId = '05${'77' * 32}';

      await tester.pumpWidget(localizedTestApp(ChatPage(
          sessionManager: me,
          store: InMemoryLocalStore(),
          contactAccountId: contactId)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hoi');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
          find.text('Nog aan het verbinden — probeer het over een paar '
              'seconden opnieuw.'),
          findsOneWidget);
      // The typed text is kept, not silently discarded.
      expect(find.text('hoi'), findsOneWidget);
    });

    testWidgets(
        'opens the safety number screen showing the right computed number',
        (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      final myAccountId = await me.accountId;
      final store = InMemoryLocalStore();
      final contactId = '05${'88' * 32}';
      await store.upsertContact(contactId, displayName: 'Vriend');

      await tester.pumpWidget(localizedTestApp(ChatPage(
          sessionManager: me, store: store, contactAccountId: contactId)));
      await tester.pump();

      await tester.tap(find.text('Vriend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Veiligheidsnummer'));
      await tester.pumpAndSettle();

      expect(find.byType(SafetyNumberPage), findsOneWidget);
      final expected = await SafetyNumber.compute(myAccountId, contactId);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets(
        'a chat with yourself sends instantly offline, and its options '
        'menu only offers to clear messages', (tester) async {
      final store = InMemoryLocalStore();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        // Would throw on any real call — proves sending here never
        // touches the network.
        backend: UnreachableChatBackend(),
        store: store,
      );
      final myAccountId = await me.accountId;

      await tester.pumpWidget(localizedTestApp(ChatPage(
        sessionManager: me,
        store: store,
        contactAccountId: myAccountId,
      )));
      await tester.pump();
      await tester.pump();

      expect(find.text('Jezelf'), findsOneWidget); // app bar title

      await tester.enterText(find.byType(TextField), 'koop melk');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();

      expect(find.text('koop melk'), findsOneWidget);
      expect(find.textContaining('Nog aan het verbinden'), findsNothing);

      await tester.tap(find.text('Jezelf'));
      await tester.pumpAndSettle();

      expect(find.text('Berichten wissen'), findsOneWidget);
      expect(find.text('Account ID bekijken'), findsNothing);
      expect(find.text('Blokkeren'), findsNothing);
    });
  });
}
