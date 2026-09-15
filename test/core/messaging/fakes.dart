import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:privacychat/core/api/chat_backend.dart';
import 'package:privacychat/core/crypto/crypto_algorithms.dart';
import 'package:privacychat/core/crypto/double_ratchet.dart';
import 'package:privacychat/core/crypto/hex.dart';
import 'package:privacychat/core/crypto/prekey_bundle.dart';
import 'package:privacychat/core/storage/local_store.dart';

/// In-memory stand-ins for [ChatBackend] and [LocalStore], so the full
/// X3DH + Double Ratchet + wire-format pipeline in [SessionManager] can be
/// exercised end-to-end in plain `flutter test` — no PHP/MySQL server, no
/// SQLite platform channel required.
///
/// [FakeChatBackend] deliberately mirrors the real PHP backend's behaviour
/// (account registration, challenge/response auth, one-time-prekey
/// consumption, mailbox fan-out) closely enough that a bug in how
/// [SessionManager] *uses* the backend contract would show up here too.

class _AccountRecord {
  _AccountRecord({
    required this.identitySigningKey,
    required this.identityAgreementKey,
    required this.signedPreKey,
    required this.signedPreKeySignature,
    required this.signedPreKeyId,
  });

  SimplePublicKey identitySigningKey;
  SimplePublicKey identityAgreementKey;
  SimplePublicKey signedPreKey;
  List<int> signedPreKeySignature;
  int signedPreKeyId;
  final Map<int, SimplePublicKey> oneTimePreKeys = {};
}

class _StoredEnvelope {
  _StoredEnvelope({
    required this.id,
    required this.recipient,
    required this.sender,
    required this.type,
    required this.ciphertext,
  });

  final int id;
  final String recipient;
  final String sender;
  final String type;
  final List<int> ciphertext;
}

class FakeServer {
  // ignore: library_private_types_in_public_api
  final Map<String, _AccountRecord> accounts = {};
  // ignore: library_private_types_in_public_api
  final List<_StoredEnvelope> mailbox = [];
  final Map<String, List<int>> pendingChallenges = {};
  final Map<String, Set<String>> groups = {};
  int _nextEnvelopeId = 1;
}

class FakeChatBackend implements ChatBackend {
  FakeChatBackend(this._server);

  final FakeServer _server;
  String? _authenticatedAccountId;
  final _random = Random.secure();

  String get _authenticated {
    final id = _authenticatedAccountId;
    if (id == null) {
      throw StateError('not authenticated — call verifyAuthChallenge first');
    }
    return id;
  }

  @override
  Future<String> registerAccount({
    required SimplePublicKey identitySigningKey,
    required SimplePublicKey identityAgreementKey,
    required SimplePublicKey signedPreKey,
    required List<int> signedPreKeySignature,
    required int signedPreKeyId,
  }) async {
    final ok = await CryptoAlgorithms.ed25519.verify(
      signedPreKey.bytes,
      signature:
          Signature(signedPreKeySignature, publicKey: identitySigningKey),
    );
    if (!ok) {
      throw StateError('signed_prekey_sig does not match');
    }

    final accountId = '05${bytesToHex(identitySigningKey.bytes)}';
    _server.accounts[accountId] = _AccountRecord(
      identitySigningKey: identitySigningKey,
      identityAgreementKey: identityAgreementKey,
      signedPreKey: signedPreKey,
      signedPreKeySignature: signedPreKeySignature,
      signedPreKeyId: signedPreKeyId,
    );
    return accountId;
  }

  @override
  Future<List<int>> requestAuthChallenge(String accountId) async {
    if (!_server.accounts.containsKey(accountId)) {
      throw StateError('unknown account_id');
    }
    final nonce = List<int>.generate(32, (_) => _random.nextInt(256));
    _server.pendingChallenges[accountId] = nonce;
    return nonce;
  }

  @override
  Future<void> verifyAuthChallenge(
      String accountId, List<int> signature) async {
    final nonce = _server.pendingChallenges.remove(accountId);
    if (nonce == null) {
      throw StateError('no pending challenge for this account_id');
    }
    final account = _server.accounts[accountId]!;
    final ok = await CryptoAlgorithms.ed25519.verify(
      nonce,
      signature: Signature(signature, publicKey: account.identitySigningKey),
    );
    if (!ok) {
      throw StateError('invalid signature');
    }
    _authenticatedAccountId = accountId;
  }

  @override
  Future<void> uploadOneTimePreKeys(
      Map<int, SimplePublicKey> prekeysById) async {
    _server.accounts[_authenticated]!.oneTimePreKeys.addAll(prekeysById);
  }

  @override
  Future<RemotePreKeyBundle> fetchPrekeyBundle(String accountId) async {
    _authenticated; // just requires *some* authenticated caller, like the real server
    final account = _server.accounts[accountId];
    if (account == null) {
      throw StateError('unknown account_id');
    }

    int? oneTimePreKeyId;
    SimplePublicKey? oneTimePreKey;
    if (account.oneTimePreKeys.isNotEmpty) {
      oneTimePreKeyId = account.oneTimePreKeys.keys.first;
      oneTimePreKey = account.oneTimePreKeys.remove(oneTimePreKeyId);
    }

    return RemotePreKeyBundle(
      accountId: accountId,
      identitySigningKey: account.identitySigningKey,
      identityAgreementKey: account.identityAgreementKey,
      signedPreKey: account.signedPreKey,
      signedPreKeySignature: account.signedPreKeySignature,
      signedPreKeyId: account.signedPreKeyId,
      oneTimePreKey: oneTimePreKey,
      oneTimePreKeyId: oneTimePreKeyId,
    );
  }

  @override
  Future<int> postEnvelope({
    required String recipientAccountId,
    required String envelopeType,
    required List<int> ciphertext,
  }) async {
    final sender = _authenticated;
    if (!_server.accounts.containsKey(recipientAccountId)) {
      throw StateError('unknown recipient_account_id');
    }
    final id = _server._nextEnvelopeId++;
    _server.mailbox.add(_StoredEnvelope(
      id: id,
      recipient: recipientAccountId,
      sender: sender,
      type: envelopeType,
      ciphertext: ciphertext,
    ));
    return id;
  }

  @override
  Future<List<MailboxEnvelope>> pollMailbox() async {
    final me = _authenticated;
    return _server.mailbox
        .where((envelope) => envelope.recipient == me)
        .map((envelope) => MailboxEnvelope(
              envelopeId: envelope.id,
              senderAccountId: envelope.sender,
              envelopeType: envelope.type,
              ciphertext: envelope.ciphertext,
            ))
        .toList();
  }

  @override
  Future<void> ackEnvelopes(List<int> envelopeIds) async {
    _server.mailbox
        .removeWhere((envelope) => envelopeIds.contains(envelope.id));
  }

  @override
  Future<void> createGroup(
      String groupId, List<String> memberAccountIds) async {
    final creator = _authenticated;
    if (_server.groups.containsKey(groupId)) {
      throw StateError('group_id already exists');
    }
    final all = {creator, ...memberAccountIds};
    for (final id in all) {
      if (!_server.accounts.containsKey(id)) {
        throw StateError('unknown member account_id: $id');
      }
    }
    _server.groups[groupId] = all;
  }

  @override
  Future<void> addGroupMember(String groupId, String accountId) async {
    final requester = _authenticated;
    final members = _server.groups[groupId];
    if (members == null || !members.contains(requester)) {
      throw StateError('not a member of this group');
    }
    if (!_server.accounts.containsKey(accountId)) {
      throw StateError('unknown account_id');
    }
    members.add(accountId);
  }

  @override
  Future<List<String>> fetchGroupMembers(String groupId) async {
    final requester = _authenticated;
    final members = _server.groups[groupId];
    if (members == null || !members.contains(requester)) {
      throw StateError('not a member of this group');
    }
    return members.toList();
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final requester = _authenticated;
    _server.groups[groupId]?.remove(requester);
  }
}

/// A [ChatBackend] that can never reach the network — every call throws,
/// simulating "bootstrap hasn't succeeded yet" (e.g. Tor still connecting).
class UnreachableChatBackend implements ChatBackend {
  @override
  Future<String> registerAccount({
    required SimplePublicKey identitySigningKey,
    required SimplePublicKey identityAgreementKey,
    required SimplePublicKey signedPreKey,
    required List<int> signedPreKeySignature,
    required int signedPreKeyId,
  }) =>
      throw Exception('no connection');

  @override
  Future<List<int>> requestAuthChallenge(String accountId) =>
      throw UnimplementedError();

  @override
  Future<void> verifyAuthChallenge(String accountId, List<int> signature) =>
      throw UnimplementedError();

  @override
  Future<void> uploadOneTimePreKeys(Map<int, SimplePublicKey> prekeysById) =>
      throw UnimplementedError();

  @override
  Future<RemotePreKeyBundle> fetchPrekeyBundle(String accountId) =>
      throw UnimplementedError();

  @override
  Future<int> postEnvelope({
    required String recipientAccountId,
    required String envelopeType,
    required List<int> ciphertext,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<MailboxEnvelope>> pollMailbox() => throw UnimplementedError();

  @override
  Future<void> ackEnvelopes(List<int> envelopeIds) =>
      throw UnimplementedError();

  @override
  Future<void> createGroup(String groupId, List<String> memberAccountIds) =>
      throw UnimplementedError();

  @override
  Future<void> addGroupMember(String groupId, String accountId) =>
      throw UnimplementedError();

  @override
  Future<List<String>> fetchGroupMembers(String groupId) =>
      throw UnimplementedError();

  @override
  Future<void> leaveGroup(String groupId) => throw UnimplementedError();
}

class InMemoryLocalStore implements LocalStore {
  final Map<String, ContactRecord> _contacts = {};
  final List<MessageRecord> _messages = [];
  int _nextMessageId = 1;
  final Map<String, DoubleRatchetSession> _sessions = {};
  SignedPreKey? _signedPreKey;
  final Map<int, OneTimePreKey> _oneTimePreKeys = {};

  @override
  Future<void> upsertContact(
    String accountId, {
    String? displayName,
    ContactStatus status = ContactStatus.accepted,
  }) async {
    final existing = _contacts[accountId];
    if (existing == null) {
      _contacts[accountId] = ContactRecord(
          accountId: accountId, displayName: displayName, status: status);
    } else if (displayName != null) {
      _contacts[accountId] = ContactRecord(
        accountId: accountId,
        displayName: displayName,
        status: existing.status,
      );
    }
  }

  @override
  Future<void> setDisplayName(String accountId, String? displayName) async {
    final existing = _contacts[accountId];
    if (existing == null) return;
    _contacts[accountId] = ContactRecord(
      accountId: accountId,
      displayName: displayName,
      status: existing.status,
    );
  }

  @override
  Future<void> setContactStatus(String accountId, ContactStatus status) async {
    final existing = _contacts[accountId];
    if (existing == null) return;
    _contacts[accountId] = ContactRecord(
      accountId: accountId,
      displayName: existing.displayName,
      status: status,
    );
  }

  @override
  Future<void> deleteContact(String accountId) async {
    _contacts.remove(accountId);
    _messages.removeWhere((message) => message.contactId == accountId);
  }

  @override
  Future<ContactRecord?> getContact(String accountId) async =>
      _contacts[accountId];

  @override
  Future<List<ContactRecord>> listContacts() async => _contacts.values.toList();

  @override
  Future<void> saveMessage({
    required String contactId,
    required String direction,
    required String body,
    DateTime? sentAt,
  }) async {
    _messages.add(MessageRecord(
      id: _nextMessageId++,
      contactId: contactId,
      direction: direction,
      body: body,
      sentAt: sentAt ?? DateTime.now(),
    ));
  }

  @override
  Future<List<MessageRecord>> messagesWith(String contactId) async =>
      _messages.where((message) => message.contactId == contactId).toList();

  @override
  Future<void> deleteMessagesWith(String accountId) async {
    _messages.removeWhere((message) => message.contactId == accountId);
  }

  @override
  Future<void> saveSession(
      String contactId, DoubleRatchetSession session) async {
    _sessions[contactId] = session;
  }

  @override
  Future<DoubleRatchetSession?> loadSession(String contactId) async =>
      _sessions[contactId];

  @override
  Future<void> saveOwnSignedPreKey(SignedPreKey key) async {
    _signedPreKey = key;
  }

  @override
  Future<SignedPreKey?> loadLatestSignedPreKey() async => _signedPreKey;

  @override
  Future<void> saveOwnOneTimePreKeys(List<OneTimePreKey> keys) async {
    for (final key in keys) {
      _oneTimePreKeys[key.id] = key;
    }
  }

  @override
  Future<OneTimePreKey?> takeOneTimePreKeyById(int id) async =>
      _oneTimePreKeys.remove(id);

  @override
  Future<int> countUnusedOneTimePreKeys() async => _oneTimePreKeys.length;

  final Map<String, GroupRecord> _groups = {};

  @override
  Future<void> upsertGroup(
    String groupId, {
    String? displayName,
    required List<String> memberAccountIds,
  }) async {
    final existing = _groups[groupId];
    _groups[groupId] = GroupRecord(
      groupId: groupId,
      displayName: displayName ?? existing?.displayName,
      memberAccountIds: memberAccountIds,
    );
  }

  @override
  Future<void> setGroupDisplayName(String groupId, String? displayName) async {
    final existing = _groups[groupId];
    if (existing == null) return;
    _groups[groupId] = GroupRecord(
      groupId: groupId,
      displayName: displayName,
      memberAccountIds: existing.memberAccountIds,
    );
  }

  @override
  Future<GroupRecord?> getGroup(String groupId) async => _groups[groupId];

  @override
  Future<List<GroupRecord>> listGroups() async => _groups.values.toList();

  @override
  Future<void> deleteGroup(String groupId) async {
    _groups.remove(groupId);
    _messages.removeWhere((message) => message.contactId == groupId);
  }
}
