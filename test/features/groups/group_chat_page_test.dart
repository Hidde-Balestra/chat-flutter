import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/messaging/session_manager.dart';
import 'package:privacychat/features/groups/group_chat_page.dart';

import '../../core/messaging/fakes.dart';
import '../../test_helpers/localized_test_app.dart';

void main() {
  group('GroupChatPage', () {
    testWidgets('shows the group name and existing messages', (tester) async {
      final server = FakeServer();
      final store = InMemoryLocalStore();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: store,
      );
      await me.bootstrap();
      const groupId = 'group-abc';
      await store.upsertGroup(groupId,
          displayName: 'Reisgenoten', memberAccountIds: [await me.accountId]);
      await store.saveMessage(
          contactId: groupId, direction: 'in', body: 'eerder bericht');

      await tester.pumpWidget(localizedTestApp(
          GroupChatPage(sessionManager: me, store: store, groupId: groupId)));
      await tester.pump();

      expect(find.text('Reisgenoten'), findsOneWidget);
      expect(find.text('eerder bericht'), findsOneWidget);
    });

    testWidgets('lets you view members, showing yourself labelled',
        (tester) async {
      final server = FakeServer();
      final store = InMemoryLocalStore();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: store,
      );
      await me.bootstrap();
      final myId = await me.accountId;
      const groupId = 'group-abc';
      final otherId = '05${'44' * 32}';
      await store.upsertGroup(groupId,
          displayName: 'Reisgenoten', memberAccountIds: [myId, otherId]);

      await tester.pumpWidget(localizedTestApp(
          GroupChatPage(sessionManager: me, store: store, groupId: groupId)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Reisgenoten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leden bekijken'));
      await tester.pumpAndSettle();

      expect(find.textContaining('(jij)'), findsOneWidget);
      expect(find.text('Leden'), findsOneWidget);
    });

    testWidgets(
        'leaving the group calls SessionManager.leaveGroup, clears the '
        'local record, and pops back', (tester) async {
      final server = FakeServer();
      final store = InMemoryLocalStore();
      final me = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: store,
      );
      final other = SessionManager(
        identity: await IdentityKeyPair.generateRandom(),
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      await me.bootstrap();
      await other.bootstrap();
      final myId = await me.accountId;
      final otherId = await other.accountId;
      await me.createGroup('group-xyz', [otherId]);
      const groupId = 'group-xyz';
      await store.upsertGroup(groupId,
          displayName: 'Weg ermee', memberAccountIds: [myId, otherId]);

      await tester.pumpWidget(localizedTestApp(Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GroupChatPage(
                    sessionManager: me, store: store, groupId: groupId),
              )),
              child: const Text('open'),
            ),
          ),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weg ermee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groep verlaten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groep verlaten').last);
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget); // popped back
      expect(await store.getGroup(groupId), isNull);
    });
  });
}
