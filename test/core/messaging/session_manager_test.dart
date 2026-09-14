import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/messaging/session_manager.dart';

import 'fakes.dart';

void main() {
  group('SessionManager', () {
    test(
        'Alice and Bob exchange end-to-end encrypted messages, server never sees plaintext',
        () async {
      final server = FakeServer();

      final aliceIdentity = await IdentityKeyPair.generateRandom();
      final bobIdentity = await IdentityKeyPair.generateRandom();
      final aliceStore = InMemoryLocalStore();
      final bobStore = InMemoryLocalStore();

      final alice = SessionManager(
        identity: aliceIdentity,
        backend: FakeChatBackend(server),
        store: aliceStore,
      );
      final bob = SessionManager(
        identity: bobIdentity,
        backend: FakeChatBackend(server),
        store: bobStore,
      );

      await alice.bootstrap();
      await bob.bootstrap();

      final aliceId = await alice.accountId;
      final bobId = await bob.accountId;

      // Alice starts the conversation — this is the X3DH "prekey_msg" path.
      await alice.sendMessage(bobId, 'hoi bob!');

      // The server only ever stores opaque ciphertext, never the plaintext.
      expect(server.mailbox, hasLength(1));
      final rawOnServer =
          utf8.decode(server.mailbox.single.ciphertext, allowMalformed: true);
      expect(rawOnServer, isNot(contains('hoi bob')));

      final bobUpdates = await bob.pollAndDecrypt();
      expect(bobUpdates, {aliceId});
      expect(server.mailbox, isEmpty); // acked and deleted after delivery

      final bobInbox = await bobStore.messagesWith(aliceId);
      expect(bobInbox, hasLength(1));
      expect(bobInbox.single.body, 'hoi bob!');
      expect(bobInbox.single.direction, 'in');

      // Bob replies — this is the already-established "normal_msg" path.
      await bob.sendMessage(aliceId, 'hoi alice, hoe gaat het?');
      final aliceUpdates = await alice.pollAndDecrypt();
      expect(aliceUpdates, {bobId});

      final aliceInbox = await aliceStore.messagesWith(bobId);
      expect(
          aliceInbox.map((m) => m.body), contains('hoi alice, hoe gaat het?'));

      // A longer back-and-forth to exercise several DH ratchet steps.
      for (var i = 0; i < 5; i++) {
        await alice.sendMessage(bobId, 'alice zegt $i');
        await bob.pollAndDecrypt();
        await bob.sendMessage(aliceId, 'bob zegt $i');
        await alice.pollAndDecrypt();
      }

      final finalBobInbox = await bobStore.messagesWith(aliceId);
      final finalAliceInbox = await aliceStore.messagesWith(bobId);
      expect(finalBobInbox.map((m) => m.body), contains('alice zegt 4'));
      expect(finalAliceInbox.map((m) => m.body), contains('bob zegt 4'));
    });

    test(
        'a fresh SessionManager can initiate the very first contact with someone new',
        () async {
      final server = FakeServer();

      final bobIdentity = await IdentityKeyPair.generateRandom();
      final carolIdentity = await IdentityKeyPair.generateRandom();

      final bob = SessionManager(
        identity: bobIdentity,
        backend: FakeChatBackend(server),
        store: InMemoryLocalStore(),
      );
      final carolStore = InMemoryLocalStore();
      final carol = SessionManager(
        identity: carolIdentity,
        backend: FakeChatBackend(server),
        store: carolStore,
      );

      await bob.bootstrap();
      await carol.bootstrap();

      final carolId = await carol.accountId;

      await bob.sendMessage(carolId, 'hallo carol, dit is bob');
      final updates = await carol.pollAndDecrypt();

      expect(updates, isNotEmpty);
      final inbox = await carolStore.messagesWith(await bob.accountId);
      expect(inbox.single.body, 'hallo carol, dit is bob');
    });
  });
}
