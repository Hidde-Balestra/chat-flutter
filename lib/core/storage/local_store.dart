import '../crypto/double_ratchet.dart';
import '../crypto/prekey_bundle.dart';

class ContactRecord {
  ContactRecord({required this.accountId, this.displayName});

  final String accountId;
  final String? displayName;
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
  Future<void> upsertContact(String accountId, {String? displayName});

  /// Sets (or clears, with null) the local nickname for a contact. Unlike
  /// [upsertContact] — where a null [displayName] means "don't touch it" —
  /// here null explicitly clears it back to showing the raw account id.
  /// This name is purely local: it's never sent to the server or to the
  /// contact, and lives in the same SQLCipher-encrypted database as
  /// everything else.
  Future<void> setDisplayName(String accountId, String? displayName);

  Future<List<ContactRecord>> listContacts();

  Future<ContactRecord?> getContact(String accountId);

  Future<void> saveMessage({
    required String contactId,
    required String direction,
    required String body,
    DateTime? sentAt,
  });

  Future<List<MessageRecord>> messagesWith(String contactId);

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
