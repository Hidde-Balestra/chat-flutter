import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../api/chat_backend.dart';
import '../crypto/double_ratchet.dart';
import '../crypto/identity_key_pair.dart';
import '../crypto/prekey_bundle.dart';
import '../crypto/x3dh.dart';
import '../storage/local_store.dart';
import 'message_payload.dart';
import 'wire_format.dart';

/// Orchestrates everything needed for a working, persisted, end-to-end
/// encrypted 1:1 conversation: publishing prekeys, establishing new sessions
/// via X3DH on first contact, and encrypting/decrypting messages through the
/// Double Ratchet afterwards — with session state durable across restarts.
class SessionManager {
  SessionManager({
    required IdentityKeyPair identity,
    required ChatBackend backend,
    required LocalStore store,
    this.oneTimePreKeyBatchSize = 20,
    this.oneTimePreKeyLowWaterMark = 5,
  })  : _identity = identity,
        _backend = backend,
        _store = store;

  final IdentityKeyPair _identity;
  final ChatBackend _backend;
  final LocalStore _store;
  final int oneTimePreKeyBatchSize;
  final int oneTimePreKeyLowWaterMark;

  String? _accountId;
  bool _isBootstrapped = false;

  Future<String> get accountId async =>
      _accountId ??= await _identity.accountId();

  /// True once [bootstrap] has completed successfully at least once. Contacts
  /// and message history are always readable from the local store regardless
  /// — this only gates network actions (sending, polling).
  bool get isBootstrapped => _isBootstrapped;

  /// Retries [bootstrap] if it hasn't succeeded yet (e.g. the app launched
  /// without a connection). A no-op once already bootstrapped. Returns
  /// whether the session is bootstrapped after this call — safe to call on
  /// every poll tick to transparently recover once connectivity returns.
  Future<bool> ensureBootstrapped() async {
    if (_isBootstrapped) {
      return true;
    }
    try {
      await bootstrap();
      return true;
    } catch (e, stackTrace) {
      // Silently swallowed otherwise, which made a persistently-failing
      // bootstrap (as opposed to "just not online yet") indistinguishable
      // from the ordinary case — visible via `flutter logs` / adb logcat.
      debugPrint('privacychat: bootstrap failed, will retry: $e\n$stackTrace');
      return false;
    }
  }

  /// Publishes this device's prekeys (idempotent — safe on every launch) and
  /// logs in via the passwordless challenge/response flow. Call once at
  /// startup before sending or polling. Throws if there's no connection —
  /// callers that need the app to stay usable offline should use
  /// [ensureBootstrapped] instead, which swallows that failure.
  Future<void> bootstrap() async {
    final id = await accountId;

    var signedPreKey = await _store.loadLatestSignedPreKey();
    signedPreKey ??= await _generateAndStoreSignedPreKey();

    final signedPreKeyPublic = await signedPreKey.keyPair.extractPublicKey();
    final signature = await _identity.sign(signedPreKeyPublic.bytes);

    await _backend.registerAccount(
      identitySigningKey: await _identity.signingPublicKey,
      identityAgreementKey: await _identity.agreementPublicKey,
      signedPreKey: signedPreKeyPublic,
      signedPreKeySignature: signature.bytes,
      signedPreKeyId: signedPreKey.id,
    );

    final nonce = await _backend.requestAuthChallenge(id);
    final nonceSignature = await _identity.sign(nonce);
    await _backend.verifyAuthChallenge(id, nonceSignature.bytes);

    await _replenishOneTimePreKeysIfNeeded();
    _isBootstrapped = true;
  }

  Future<SignedPreKey> _generateAndStoreSignedPreKey() async {
    final key = await SignedPreKey.generate(1);
    await _store.saveOwnSignedPreKey(key);
    return key;
  }

  Future<void> _replenishOneTimePreKeysIfNeeded() async {
    final remaining = await _store.countUnusedOneTimePreKeys();
    if (remaining >= oneTimePreKeyLowWaterMark) {
      return;
    }

    final random = Random.secure();
    final newKeys = <OneTimePreKey>[];
    for (var i = 0; i < oneTimePreKeyBatchSize; i++) {
      newKeys.add(await OneTimePreKey.generate(random.nextInt(1 << 31)));
    }
    await _store.saveOwnOneTimePreKeys(newKeys);

    final byId = <int, SimplePublicKey>{
      for (final key in newKeys) key.id: await key.keyPair.extractPublicKey(),
    };
    await _backend.uploadOneTimePreKeys(byId);
  }

  /// Associated data binds a ciphertext to a specific conversation direction
  /// so a message can't be replayed into a different context. Always
  /// ordered `sender:recipient` so both sides compute the same bytes.
  Future<List<int>> _associatedData(
      String senderAccountId, String recipientAccountId) async {
    return utf8.encode('$senderAccountId:$recipientAccountId');
  }

  Future<void> sendMessage(String contactAccountId, String text) async {
    final myAccountId = await accountId;

    if (contactAccountId == myAccountId) {
      // Notes to yourself: there's no second party to establish a session
      // with, and this session's own sending chain can't turn around and
      // decrypt a message sent right back to itself (the Double Ratchet's
      // sending and receiving chains are only symmetric between two
      // *different* parties) — so this skips X3DH/the ratchet/the server
      // entirely and is just saved straight to the local (already
      // encrypted-at-rest) store. Works fully offline, on purpose.
      await _store.saveMessage(
          contactId: contactAccountId, direction: 'out', body: text);
      return;
    }

    // A defense-in-depth check, not the primary UX for this: callers (e.g.
    // ChatPage) should already call ensureBootstrapped() themselves first
    // and show a friendly "still connecting" message rather than ever
    // reaching this exception — see its doc comment for why this can be
    // false even after the app has been open for a while (Tor bootstrap,
    // no connectivity yet, etc).
    if (!await ensureBootstrapped()) {
      throw StateError('not connected yet — try again once connected');
    }

    await _encryptAndSendToRecipient(
      myAccountId: myAccountId,
      recipientAccountId: contactAccountId,
      plaintext: MessagePayload(body: text).encode(),
    );
    await _store.upsertContact(contactAccountId);
    await _store.saveMessage(
        contactId: contactAccountId, direction: 'out', body: text);
  }

  /// Sends [text] to every member of [groupId] (except yourself) as an
  /// individually end-to-end encrypted copy over each member's own 1:1
  /// session — groups deliberately don't use a shared "sender key" scheme;
  /// see [MessagePayload]'s doc comment for why. One member failing to
  /// receive it (e.g. their prekey bundle can't be fetched right now)
  /// doesn't stop delivery to the others; failures are collected and
  /// reported together once every member has been tried.
  Future<void> sendGroupMessage(
    String groupId,
    List<String> memberAccountIds,
    String text,
  ) async {
    if (!await ensureBootstrapped()) {
      throw StateError('not connected yet — try again once connected');
    }
    final myAccountId = await accountId;
    final plaintext = MessagePayload(body: text, groupId: groupId).encode();

    final failures = <String, Object>{};
    for (final memberId in memberAccountIds) {
      if (memberId == myAccountId) continue;
      try {
        await _encryptAndSendToRecipient(
          myAccountId: myAccountId,
          recipientAccountId: memberId,
          plaintext: plaintext,
        );
      } catch (e) {
        failures[memberId] = e;
      }
    }

    await _store.saveMessage(contactId: groupId, direction: 'out', body: text);

    if (failures.isNotEmpty) {
      throw StateError(
          'failed to deliver to ${failures.length} member(s): ${failures.keys.join(', ')}');
    }
  }

  /// Registers a new group with the server (bookkeeping only — see
  /// [ChatBackend.createGroup]). Does not touch local storage; the caller
  /// is expected to save the [GroupRecord] itself once this succeeds, the
  /// same way adding a 1:1 contact works.
  Future<void> createGroup(
      String groupId, List<String> otherMemberAccountIds) async {
    if (!await ensureBootstrapped()) {
      throw StateError('not connected yet — try again once connected');
    }
    await _backend.createGroup(groupId, otherMemberAccountIds);
  }

  Future<void> addGroupMember(String groupId, String accountId) async {
    if (!await ensureBootstrapped()) {
      throw StateError('not connected yet — try again once connected');
    }
    await _backend.addGroupMember(groupId, accountId);
  }

  /// Removes this device's own membership server-side. Doesn't touch local
  /// storage — the caller deletes the local [GroupRecord] itself, same as
  /// [createGroup]. Afterwards, [ChatBackend.fetchGroupMembers] for this
  /// group id will 403 for this account (see GroupController::
  /// assertIsMember server-side), which is exactly what makes any future
  /// message still tagged with this group_id get refused by
  /// [_handleIncomingGroupMessage] rather than silently reappearing.
  Future<void> leaveGroup(String groupId) async {
    if (!await ensureBootstrapped()) {
      throw StateError('not connected yet — try again once connected');
    }
    await _backend.leaveGroup(groupId);
  }

  /// Test-only: sends a raw [MessagePayload] to [recipientAccountId] via
  /// the same encryption path [sendMessage]/[sendGroupMessage] use,
  /// without their higher-level bookkeeping — lets a test simulate a
  /// sender lying about a message's group_id, to verify [pollAndDecrypt]
  /// on the receiving end actually refuses to trust an unverified claim
  /// like that. Doesn't expose any new capability an adversarial client
  /// couldn't already reach by hand-crafting the (unencrypted, documented)
  /// wire format itself — this is a convenience for testing that defense,
  /// not a bypass of it.
  @visibleForTesting
  Future<void> debugSendRawPayload(
      String recipientAccountId, MessagePayload payload) async {
    final myAccountId = await accountId;
    await _encryptAndSendToRecipient(
      myAccountId: myAccountId,
      recipientAccountId: recipientAccountId,
      plaintext: payload.encode(),
    );
  }

  /// The X3DH + Double Ratchet + wire-format machinery shared by 1:1 and
  /// group sends: establishes a session with [recipientAccountId] if one
  /// doesn't already exist, encrypts [plaintext], and posts it to their
  /// mailbox.
  Future<void> _encryptAndSendToRecipient({
    required String myAccountId,
    required String recipientAccountId,
    required List<int> plaintext,
  }) async {
    var session = await _store.loadSession(recipientAccountId);
    final associatedData =
        await _associatedData(myAccountId, recipientAccountId);

    final List<int> wireBytes;
    final String envelopeType;

    if (session == null) {
      final bundle = await _backend.fetchPrekeyBundle(recipientAccountId);
      final initiation =
          await X3dh.initiate(localIdentity: _identity, remoteBundle: bundle);
      session = await DoubleRatchetSession.initAsInitiator(
        sharedSecret: initiation.sharedSecret,
        remoteRatchetPublicKey: bundle.signedPreKey,
      );

      final ratchetMessage =
          await session.encrypt(plaintext, associatedData: associatedData);
      wireBytes = WireFormat.encodePrekeyMessage(
        senderIdentityAgreementKey: await _identity.agreementPublicKey,
        senderEphemeralKey: initiation.ephemeralPublicKey,
        signedPreKeyId: bundle.signedPreKeyId,
        oneTimePreKeyId: initiation.usedOneTimePreKeyId,
        ratchetMessage: ratchetMessage,
      );
      envelopeType = 'prekey_msg';
    } else {
      final ratchetMessage =
          await session.encrypt(plaintext, associatedData: associatedData);
      wireBytes = WireFormat.encodeNormalMessage(ratchetMessage);
      envelopeType = 'normal_msg';
    }

    await _backend.postEnvelope(
      recipientAccountId: recipientAccountId,
      envelopeType: envelopeType,
      ciphertext: wireBytes,
    );
    await _store.saveSession(recipientAccountId, session);
  }

  /// Polls the mailbox, decrypts everything it can, persists the results and
  /// acknowledges every processed envelope so the server can delete it.
  /// Returns the ids (contact or group) of every conversation that
  /// received a new message.
  Future<Set<String>> pollAndDecrypt() async {
    final envelopes = await _backend.pollMailbox();
    final updatedConversations = <String>{};
    final toAck = <int>[];

    for (final envelope in envelopes) {
      try {
        // Decrypting always happens, blocked or not — the Double Ratchet
        // chain must keep advancing on every message or a later, wanted
        // message from the same contact would fail to decrypt too.
        final plaintextBytes = await _decryptEnvelope(envelope);
        final payload = MessagePayload.decode(plaintextBytes);

        if (payload.groupId != null) {
          final delivered = await _handleIncomingGroupMessage(
            groupId: payload.groupId!,
            senderAccountId: envelope.senderAccountId,
            body: payload.body,
          );
          if (delivered) {
            updatedConversations.add(payload.groupId!);
          }
        } else {
          final existing = await _store.getContact(envelope.senderAccountId);
          if (existing?.status != ContactStatus.blocked) {
            // New senders land as a pending message request, not silently
            // added as a normal contact — upsertContact only applies this
            // on first insert, so an already-accepted contact is left
            // alone.
            await _store.upsertContact(envelope.senderAccountId,
                status: ContactStatus.pending);
            await _store.saveMessage(
              contactId: envelope.senderAccountId,
              direction: 'in',
              body: payload.body,
            );
            updatedConversations.add(envelope.senderAccountId);
          }
        }
      } catch (e, stackTrace) {
        // Malformed, out-of-window or already-processed (duplicate
        // delivery) — this can never succeed on retry, so ack it anyway
        // rather than let a single bad envelope wedge the whole mailbox.
        // Still logged (visible via `flutter logs` / adb logcat) so a real
        // bug doesn't silently look like "message never arrived".
        debugPrint(
          'privacychat: dropping undecryptable envelope ${envelope.envelopeId} '
          'from ${envelope.senderAccountId} (${envelope.envelopeType}): $e\n$stackTrace',
        );
      }
      toAck.add(envelope.envelopeId);
    }

    await _backend.ackEnvelopes(toAck);
    return updatedConversations;
  }

  /// Handles a decrypted group message. Returns whether it was actually
  /// stored (false if the claimed sender turned out not to be a real
  /// member of the group).
  ///
  /// The `group_id` tag comes from inside plaintext the *sender* chose —
  /// their own honest 1:1 session with us happily encrypts whatever they
  /// put in it, so nothing stops a contact from tagging an ordinary
  /// message with a group_id for a group they aren't actually in, trying
  /// to spoof a "group message". [ChatBackend.fetchGroupMembers] only ever
  /// answers for a group *we* are actually a member of (see
  /// GroupController::assertIsMember server-side), so treating its
  /// response as the source of truth for membership — and refusing to
  /// store the message at all if the claimed sender isn't in it — closes
  /// that off.
  Future<bool> _handleIncomingGroupMessage({
    required String groupId,
    required String senderAccountId,
    required String body,
  }) async {
    final group = await _store.getGroup(groupId);
    var members = group?.memberAccountIds;

    if (members == null || !members.contains(senderAccountId)) {
      try {
        members = await _backend.fetchGroupMembers(groupId);
      } catch (_) {
        // Not a member (any more), or offline right now — can't verify
        // this claim, so don't trust it.
        return false;
      }
      await _store.upsertGroup(groupId, memberAccountIds: members);
    }

    if (!members.contains(senderAccountId)) {
      return false;
    }

    await _store.saveMessage(contactId: groupId, direction: 'in', body: body);
    return true;
  }

  Future<List<int>> _decryptEnvelope(MailboxEnvelope envelope) async {
    final myAccountId = await accountId;
    final associatedData =
        await _associatedData(envelope.senderAccountId, myAccountId);

    if (envelope.envelopeType == 'prekey_msg') {
      final decoded = WireFormat.decodePrekeyMessage(envelope.ciphertext);
      var session = await _store.loadSession(envelope.senderAccountId);

      if (session == null) {
        final signedPreKey = await _store.loadLatestSignedPreKey();
        if (signedPreKey == null || signedPreKey.id != decoded.signedPreKeyId) {
          throw StateError(
              'no matching local signed prekey for id ${decoded.signedPreKeyId}');
        }
        final oneTimePreKey = decoded.oneTimePreKeyId == null
            ? null
            : await _store.takeOneTimePreKeyById(decoded.oneTimePreKeyId!);

        final sharedSecret = await X3dh.respond(
          localIdentity: _identity,
          localSignedPreKeyPair: signedPreKey.keyPair,
          localOneTimePreKeyPair: oneTimePreKey?.keyPair,
          remoteIdentityAgreementKey: decoded.senderIdentityAgreementKey,
          remoteEphemeralKey: decoded.senderEphemeralKey,
        );
        session = DoubleRatchetSession.initAsResponder(
          sharedSecret: sharedSecret,
          selfRatchetKeyPair: signedPreKey.keyPair,
        );
      }

      final plaintext = await session.decrypt(decoded.ratchetMessage,
          associatedData: associatedData);
      await _store.saveSession(envelope.senderAccountId, session);
      return plaintext;
    }

    if (envelope.envelopeType == 'normal_msg') {
      final session = await _store.loadSession(envelope.senderAccountId);
      if (session == null) {
        throw StateError(
            'received a normal_msg with no existing session for this contact');
      }
      final ratchetMessage =
          WireFormat.decodeNormalMessage(envelope.ciphertext);
      final plaintext =
          await session.decrypt(ratchetMessage, associatedData: associatedData);
      await _store.saveSession(envelope.senderAccountId, session);
      return plaintext;
    }

    throw StateError('unsupported envelope type: ${envelope.envelopeType}');
  }
}
