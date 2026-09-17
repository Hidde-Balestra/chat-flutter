import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../crypto/crypto_algorithms.dart';
import '../crypto/double_ratchet.dart';
import '../crypto/prekey_bundle.dart';
import 'app_database.dart';
import 'local_store.dart';

/// SQLCipher-backed implementation of [LocalStore] used by the real app.
class SqliteLocalStore implements LocalStore {
  SqliteLocalStore(this._db);

  final AppDatabase _db;

  /// Exposed only for the debug-only "new test account" reset (see
  /// `lib/core/debug/fake_account_reset.dart`), which needs to close the
  /// underlying connection before the file beneath it can be deleted.
  AppDatabase get database => _db;

  @override
  Future<void> upsertContact(
    String accountId, {
    String? displayName,
    ContactStatus status = ContactStatus.accepted,
  }) async {
    final existing = await _db.raw.query(
      'contacts',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await _db.raw.insert('contacts', {
        'account_id': accountId,
        'display_name': displayName,
        'added_at': DateTime.now().millisecondsSinceEpoch,
        'status': status.name,
      });
    } else if (displayName != null) {
      await _db.raw.update(
        'contacts',
        {'display_name': displayName},
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
    }
  }

  @override
  Future<void> setDisplayName(String accountId, String? displayName) async {
    await _db.raw.update(
      'contacts',
      {'display_name': displayName},
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  @override
  Future<void> setContactStatus(String accountId, ContactStatus status) async {
    await _db.raw.update(
      'contacts',
      {'status': status.name},
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  @override
  Future<void> deleteContact(String accountId) async {
    await _db.raw
        .delete('contacts', where: 'account_id = ?', whereArgs: [accountId]);
    await _db.raw
        .delete('messages', where: 'contact_id = ?', whereArgs: [accountId]);
  }

  @override
  Future<ContactRecord?> getContact(String accountId) async {
    final rows = await _db.raw.query(
      'contacts',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ContactRecord(
      accountId: rows.first['account_id'] as String,
      displayName: rows.first['display_name'] as String?,
      status:
          ContactStatus.fromDb(rows.first['status'] as String? ?? 'accepted'),
    );
  }

  @override
  Future<List<ContactRecord>> listContacts() async {
    final rows = await _db.raw.query('contacts', orderBy: 'added_at DESC');
    return rows
        .map((row) => ContactRecord(
              accountId: row['account_id'] as String,
              displayName: row['display_name'] as String?,
              status:
                  ContactStatus.fromDb(row['status'] as String? ?? 'accepted'),
            ))
        .toList();
  }

  @override
  Future<void> saveMessage({
    required String contactId,
    required String direction,
    required String body,
    DateTime? sentAt,
  }) async {
    await _db.raw.insert('messages', {
      'contact_id': contactId,
      'direction': direction,
      'body': body,
      'sent_at': (sentAt ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<MessageRecord>> messagesWith(String contactId) async {
    final rows = await _db.raw.query(
      'messages',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'sent_at ASC',
    );
    return rows
        .map((row) => MessageRecord(
              id: row['id'] as int,
              contactId: row['contact_id'] as String,
              direction: row['direction'] as String,
              body: row['body'] as String,
              sentAt:
                  DateTime.fromMillisecondsSinceEpoch(row['sent_at'] as int),
            ))
        .toList();
  }

  @override
  Future<void> deleteMessagesWith(String accountId) async {
    await _db.raw
        .delete('messages', where: 'contact_id = ?', whereArgs: [accountId]);
  }

  @override
  Future<void> saveSession(
      String contactId, DoubleRatchetSession session) async {
    final stateJson = jsonEncode(await session.toStorage());
    await _db.raw.insert(
      'ratchet_sessions',
      {'contact_id': contactId, 'state_json': stateJson},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DoubleRatchetSession?> loadSession(String contactId) async {
    final rows = await _db.raw.query(
      'ratchet_sessions',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final json =
        jsonDecode(rows.first['state_json'] as String) as Map<String, dynamic>;
    return DoubleRatchetSession.fromStorage(json);
  }

  @override
  Future<void> saveOwnSignedPreKey(SignedPreKey key) async {
    final privateKeyBytes = await key.keyPair.extractPrivateKeyBytes();
    final publicKeyBytes = (await key.keyPair.extractPublicKey()).bytes;
    await _db.raw.insert(
      'own_signed_prekeys',
      {
        'id': key.id,
        'private_key': base64Encode(privateKeyBytes),
        'public_key': base64Encode(publicKeyBytes),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<SignedPreKey?> loadLatestSignedPreKey() async {
    final rows = await _db.raw
        .query('own_signed_prekeys', orderBy: 'created_at DESC', limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final keyPair = await CryptoAlgorithms.x25519
        .newKeyPairFromSeed(base64Decode(row['private_key'] as String));
    return SignedPreKey(id: row['id'] as int, keyPair: keyPair);
  }

  @override
  Future<void> saveOwnOneTimePreKeys(List<OneTimePreKey> keys) async {
    final batch = _db.raw.batch();
    for (final key in keys) {
      final privateKeyBytes = await key.keyPair.extractPrivateKeyBytes();
      final publicKeyBytes = (await key.keyPair.extractPublicKey()).bytes;
      batch.insert(
        'own_one_time_prekeys',
        {
          'id': key.id,
          'private_key': base64Encode(privateKeyBytes),
          'public_key': base64Encode(publicKeyBytes),
          'used': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<OneTimePreKey?> takeOneTimePreKeyById(int id) async {
    final rows = await _db.raw.query(
      'own_one_time_prekeys',
      where: 'id = ? AND used = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    await _db.raw.update('own_one_time_prekeys', {'used': 1},
        where: 'id = ?', whereArgs: [id]);
    final keyPair = await CryptoAlgorithms.x25519
        .newKeyPairFromSeed(base64Decode(rows.first['private_key'] as String));
    return OneTimePreKey(id: id, keyPair: keyPair);
  }

  @override
  Future<int> countUnusedOneTimePreKeys() async {
    final result = await _db.raw.rawQuery(
        'SELECT COUNT(*) AS c FROM own_one_time_prekeys WHERE used = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> upsertGroup(
    String groupId, {
    String? displayName,
    required List<String> memberAccountIds,
  }) async {
    await _db.raw.transaction((txn) async {
      final existing = await txn.query(
        'groups',
        where: 'group_id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('groups', {
          'group_id': groupId,
          'display_name': displayName,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else if (displayName != null) {
        await txn.update('groups', {'display_name': displayName},
            where: 'group_id = ?', whereArgs: [groupId]);
      }

      await txn
          .delete('group_members', where: 'group_id = ?', whereArgs: [groupId]);
      final batch = txn.batch();
      for (final accountId in memberAccountIds) {
        batch.insert(
            'group_members', {'group_id': groupId, 'account_id': accountId});
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> setGroupDisplayName(String groupId, String? displayName) async {
    await _db.raw.update('groups', {'display_name': displayName},
        where: 'group_id = ?', whereArgs: [groupId]);
  }

  @override
  Future<GroupRecord?> getGroup(String groupId) async {
    final rows = await _db.raw
        .query('groups', where: 'group_id = ?', whereArgs: [groupId], limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    final members = await _db.raw
        .query('group_members', where: 'group_id = ?', whereArgs: [groupId]);
    return GroupRecord(
      groupId: rows.first['group_id'] as String,
      displayName: rows.first['display_name'] as String?,
      memberAccountIds:
          members.map((row) => row['account_id'] as String).toList(),
    );
  }

  @override
  Future<List<GroupRecord>> listGroups() async {
    final rows = await _db.raw.query('groups', orderBy: 'created_at DESC');
    final groups = <GroupRecord>[];
    for (final row in rows) {
      final groupId = row['group_id'] as String;
      final members = await _db.raw
          .query('group_members', where: 'group_id = ?', whereArgs: [groupId]);
      groups.add(GroupRecord(
        groupId: groupId,
        displayName: row['display_name'] as String?,
        memberAccountIds:
            members.map((m) => m['account_id'] as String).toList(),
      ));
    }
    return groups;
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _db.raw.delete('groups', where: 'group_id = ?', whereArgs: [groupId]);
    await _db.raw
        .delete('group_members', where: 'group_id = ?', whereArgs: [groupId]);
    await _db.raw
        .delete('messages', where: 'contact_id = ?', whereArgs: [groupId]);
  }
}
