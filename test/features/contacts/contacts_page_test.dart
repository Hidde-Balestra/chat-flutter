import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/messaging/session_manager.dart';
import 'package:privacychat/core/security/app_lock_controller.dart';
import 'package:privacychat/core/settings/locale_controller.dart';
import 'package:privacychat/core/storage/local_store.dart';
import 'package:privacychat/features/chat/chat_page.dart';
import 'package:privacychat/features/contacts/contacts_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/messaging/fakes.dart';
import '../../test_helpers/fake_local_auth.dart';
import '../../test_helpers/fake_secure_storage.dart';
import '../../test_helpers/fake_tor_service.dart';
import '../../test_helpers/localized_test_app.dart';

// Tiny on purpose — see settings_page_test.dart for why: the real 210k-
// iteration work factor is slow enough to make pumpAndSettle hang against
// an indeterminate progress spinner elsewhere in these tests' widget tree.
AppLockController _testAppLock() => AppLockController(pbkdf2Iterations: 10);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installFakeSecureStorage();
    installFakeLocalAuth();
  });

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

      await tester.pumpWidget(localizedTestApp(ContactsPage(
        sessionManager: me,
        store: store,
        localeController: LocaleController(),
        appLock: _testAppLock(),
      )));
      await tester.pump();

      expect(find.textContaining('Nog geen contacten'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, contactId);
      await tester.tap(find.text('Toevoegen'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatPage), findsOneWidget);
      expect(await store.listContacts(), hasLength(1));
    });

    testWidgets(
        'a contact can be given a local name, shown instead of the account id',
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
      await store.upsertContact(contactId);

      await tester.pumpWidget(localizedTestApp(ContactsPage(
        sessionManager: me,
        store: store,
        localeController: LocaleController(),
        appLock: _testAppLock(),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bob');
      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect((await store.getContact(contactId))?.displayName, 'Bob');
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

      await tester.pumpWidget(localizedTestApp(ContactsPage(
        sessionManager: me,
        store: InMemoryLocalStore(),
        localeController: LocaleController(),
        appLock: _testAppLock(),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.badge_outlined));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == expectedId),
        findsOneWidget,
      );
    });

    testWidgets('opens Settings from the app bar', (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();

      await tester.pumpWidget(localizedTestApp(ContactsPage(
        sessionManager: me,
        store: InMemoryLocalStore(),
        localeController: LocaleController(),
        appLock: _testAppLock(),
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Instellingen'), findsOneWidget);
      expect(find.text('App vergrendelen met pincode'), findsOneWidget);
    });

    testWidgets(
        'shows a message-requests section, separate from accepted contacts, '
        'and lets you swipe to delete a contact', (tester) async {
      final server = FakeServer();
      final store = InMemoryLocalStore();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: store,
      );
      await me.bootstrap();

      final requesterId = '05${'55' * 32}';
      final friendId = '05${'66' * 32}';
      await store.upsertContact(requesterId, status: ContactStatus.pending);
      await store.upsertContact(friendId,
          displayName: 'Vriend', status: ContactStatus.accepted);

      await tester.pumpWidget(localizedTestApp(ContactsPage(
        sessionManager: me,
        store: store,
        localeController: LocaleController(),
        appLock: _testAppLock(),
      )));
      await tester.pump();

      expect(find.text('Berichtverzoeken'), findsOneWidget);
      expect(find.text('Contacten'), findsOneWidget);
      expect(find.text('Vriend'), findsOneWidget);

      // Swipe the accepted contact away and confirm deletion.
      await tester.drag(find.text('Vriend'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verwijderen').last);
      await tester.pumpAndSettle();

      expect(await store.getContact(friendId), isNull);
      expect(find.text('Vriend'), findsNothing);
    });

    testWidgets(
        'shows a Tor connection indicator that updates as it bootstraps',
        (tester) async {
      final server = FakeServer();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      final torService = FakeTorService();

      await tester.pumpWidget(localizedTestApp(ContactsPage(
        sessionManager: me,
        store: InMemoryLocalStore(),
        localeController: LocaleController(),
        appLock: _testAppLock(),
        torStatus: torService.status,
      )));
      await tester.pump();

      expect(find.byIcon(Icons.security), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      torService.setConnected();
      await tester.pump();

      expect(find.byIcon(Icons.security), findsOneWidget);
    });
  });
}
