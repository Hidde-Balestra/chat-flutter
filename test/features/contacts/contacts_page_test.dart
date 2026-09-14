import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/messaging/session_manager.dart';
import 'package:privacychat/features/chat/chat_page.dart';
import 'package:privacychat/features/contacts/contacts_page.dart';

import '../../core/messaging/fakes.dart';

void main() {
  group('ContactsPage', () {
    testWidgets(
        'shows an empty state, then opens a chat after adding a contact',
        (tester) async {
      final server = FakeServer();
      final store = InMemoryLocalStore();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: store,
      );
      final contact = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );

      await me.bootstrap();
      await contact.bootstrap();
      final contactId = await contact.accountId;

      await tester.pumpWidget(
          MaterialApp(home: ContactsPage(sessionManager: me, store: store)));
      await tester.pump();

      expect(find.textContaining('Nog geen contacten'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), contactId);
      await tester.tap(find.text('Toevoegen'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatPage), findsOneWidget);
      expect(await store.listContacts(), hasLength(1));
    });

    testWidgets('shows your own account id in a dialog', (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      final expectedId = await me.accountId;

      await tester.pumpWidget(
        MaterialApp(
            home:
                ContactsPage(sessionManager: me, store: InMemoryLocalStore())),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.badge_outlined));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == expectedId),
        findsOneWidget,
      );
    });
  });
}
