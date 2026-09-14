import '../crypto/double_ratchet.dart';
import '../crypto/prekey_bundle.dart';

/// A contact's relationship to this device.
///
/// - [accepted]: a normal, active conversation — either you added them, or
///   you accepted a message request from them.
/// - [pending]: someone not already accepted messaged you first. Their
///   messages are stored (so opening the request shows what they said) but
///   the conversation doesn't behave normally until accepted.
/// - [blocked]: any further incoming messages from them are decrypted (to
///   keep the Double Ratchet chain healthy) but immediately discarded,
///   never stored or shown.
enum ContactStatus {
  accepted,
  pending,
  blocked;

  static ContactStatus fromDb(String value) => ContactStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => ContactStatus.accepted,
      );
}

class ContactRecord {
  ContactRecord({
    required this.accountId,
    this.displayName,
    this.status = ContactStatus.accepted,
  });

  final String accountId;
  final String? displayName;
  final ContactStatus status;
}

class MessageRecord {
  MessageRecord({
    required this.id,
    required this.contactId,
    required this.direction,
    required this.body,
    required this.sentAt,
  });

  final int id;
  final String contactId;

  /// 'out' — sent by this device. 'in' — received from the contact.
  final String direction;
  final String body;
  final DateTime sentAt;
}

/// Everything [SessionManager] and the UI need to persist locally. Kept as
/// an interface — implemented for real by [SqliteLocalStore] (SQLCipher-
/// encrypted on-device storage) and by an in-memory fake in tests, so the
/// whole X3DH + Double Ratchet + wire-format pipeline can be exercised
/// end-to-end without any platform channels.
abstract class LocalStore {
  /// Creates the contact if it doesn't exist yet (with [status] — defaults
  /// to already-[ContactStatus.accepted], since this is used when *you*
  /// add someone or start a conversation yourself). If the contact already
  /// exists, [status] is ignored — use [setContactStatus] to change an
  /// existing contact's status explicitly. [displayName], if given, always
  /// overwrites (same as before).
  Future<void> upsertContact(
    String accountId, {
    String? displayName,
    ContactStatus status = ContactStatus.accepted,
  });

  /// Sets (or clears, with null) the local nickname for a contact. Unlike
  /// [upsertContact] — where a null [displayName] means "don't touch it" —
  /// here null explicitly clears it back to showing the raw account id.
  /// This name is purely local: it's never sent to the server or to the
  /// contact, and lives in the same SQLCipher-encrypted database as
  /// everything else.
  Future<void> setDisplayName(String accountId, String? displayName);

  Future<void> setContactStatus(String accountId, ContactStatus status);

  /// Removes a contact and their message history entirely (used to decline
  /// a message request). The Double Ratchet session is deliberately left
  /// alone — if they message again, it can still be decrypted, and shows up
  /// as a fresh pending request.
  Future<void> deleteContact(String accountId);

  Future<List<ContactRecord>> listContacts();

  Future<ContactRecord?> getContact(String accountId);

  Future<void> saveMessage({
    required String contactId,
    required String direction,
    required String body,
    DateTime? sentAt,
  });

  Future<List<MessageRecord>> messagesWith(String contactId);

  /// Clears message history with a contact without removing the contact
  /// itself (used when blocking someone, so the conversation view is empty
  /// going forward but the blocked status sticks).
  Future<void> deleteMessagesWith(String accountId);

  Future<void> saveSession(String contactId, DoubleRatchetSession session);

  Future<DoubleRatchetSession?> loadSession(String contactId);

  Future<void> saveOwnSignedPreKey(SignedPreKey key);

  Future<SignedPreKey?> loadLatestSignedPreKey();

  Future<void> saveOwnOneTimePreKeys(List<OneTimePreKey> keys);

  /// Marks the prekey with [id] used and returns it, or null if it doesn't
  /// exist or was already used — X3DH one-time prekeys are single-use.
  Future<OneTimePreKey?> takeOneTimePreKeyById(int id);

  Future<int> countUnusedOneTimePreKeys();
}
