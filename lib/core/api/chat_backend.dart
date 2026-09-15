import 'package:cryptography/cryptography.dart';

import '../crypto/prekey_bundle.dart';

/// A single encrypted envelope as handed back by a mailbox poll. The server
/// never interprets [ciphertext] — it's opaque bytes produced by
/// [WireFormat] on the sending side.
class MailboxEnvelope {
  MailboxEnvelope({
    required this.envelopeId,
    required this.senderAccountId,
    required this.envelopeType,
    required this.ciphertext,
  });

  final int envelopeId;
  final String senderAccountId;
  final String
      envelopeType; // 'prekey_msg' | 'normal_msg' | 'sender_key_distribution'
  final List<int> ciphertext;
}

/// Everything [SessionManager] needs from a server, kept as an interface so
/// it can be exercised in tests against an in-memory fake instead of a real
/// PHP/MySQL backend.
abstract class ChatBackend {
  Future<String> registerAccount({
    required SimplePublicKey identitySigningKey,
    required SimplePublicKey identityAgreementKey,
    required SimplePublicKey signedPreKey,
    required List<int> signedPreKeySignature,
    required int signedPreKeyId,
  });

  Future<List<int>> requestAuthChallenge(String accountId);

  /// On success, the backend should remember the resulting bearer token
  /// internally and attach it to every subsequent authenticated call.
  Future<void> verifyAuthChallenge(String accountId, List<int> signature);

  Future<void> uploadOneTimePreKeys(Map<int, SimplePublicKey> prekeysById);

  Future<RemotePreKeyBundle> fetchPrekeyBundle(String accountId);

  Future<int> postEnvelope({
    required String recipientAccountId,
    required String envelopeType,
    required List<int> ciphertext,
  });

  Future<List<MailboxEnvelope>> pollMailbox();

  Future<void> ackEnvelopes(List<int> envelopeIds);

  /// Registers group membership with the server — bookkeeping only, so it
  /// knows which mailboxes to expect fan-out to. [memberAccountIds] should
  /// not include this device's own account id; the server adds the caller
  /// as a member automatically.
  Future<void> createGroup(String groupId, List<String> memberAccountIds);

  Future<void> addGroupMember(String groupId, String accountId);

  Future<List<String>> fetchGroupMembers(String groupId);

  /// Removes this device's own account from the group — never another
  /// member's.
  Future<void> leaveGroup(String groupId);
}
