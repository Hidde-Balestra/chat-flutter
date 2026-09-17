import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// The local, on-device database: contacts, messages and (crucially) the
/// private ratchet/prekey material needed to keep conversations working
/// across app restarts. Encrypted at rest with SQLCipher, using a random
/// passphrase generated once and kept in the platform keystore — never
/// derived from anything a user could forget or that could double as a
/// weak, guessable "password".
class AppDatabase {
  AppDatabase._(this.raw);

  final Database raw;

  Future<void> close() => raw.close();

  /// Deletes the on-device database file outright — used only by the
  /// debug-only "new test account" reset (see
  /// `lib/core/debug/fake_account_reset.dart`). The passphrase in the
  /// keystore is deliberately left untouched: [open] will happily reuse it
  /// to create a brand-new (empty) encrypted file, and leaving it alone
  /// avoids disturbing [AppLockController]'s PIN-wrapped copy of it.
  static Future<void> deleteFile({String fileName = 'privacychat.db'}) async {
    final directory = await getApplicationDocumentsDirectory();
    await deleteDatabase(path.join(directory.path, fileName));
  }

  /// Shared with [AppLockController], which moves the value living under
  /// this key into a PIN-encrypted form instead — see its doc comment.
  static const passphraseStorageKey = 'local_db_passphrase_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Opens the encrypted local database. If [passphrase] is given, it's used
  /// as-is (the caller — [AppLockController] — already unwrapped it with the
  /// user's PIN); otherwise the passphrase is read from (or, on first ever
  /// launch, generated into) the platform keystore, unlocking automatically.
  static Future<AppDatabase> open({
    String fileName = 'privacychat.db',
    String? passphrase,
  }) async {
    passphrase ??= await _secureStorage.read(key: passphraseStorageKey);
    if (passphrase == null) {
      passphrase = _randomPassphrase();
      await _secureStorage.write(key: passphraseStorageKey, value: passphrase);
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, fileName);

    final db = await openDatabase(
      dbPath,
      password: passphrase,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contacts (
            account_id TEXT PRIMARY KEY,
            display_name TEXT,
            added_at INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'accepted'
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contact_id TEXT NOT NULL,
            direction TEXT NOT NULL,
            body TEXT NOT NULL,
            sent_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_messages_contact ON messages(contact_id, sent_at)');
        await db.execute('''
          CREATE TABLE ratchet_sessions (
            contact_id TEXT PRIMARY KEY,
            state_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE own_signed_prekeys (
            id INTEGER PRIMARY KEY,
            private_key TEXT NOT NULL,
            public_key TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE own_one_time_prekeys (
            id INTEGER PRIMARY KEY,
            private_key TEXT NOT NULL,
            public_key TEXT NOT NULL,
            used INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await _createGroupTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Message requests: every contact that already existed before
          // this feature shipped was already a normal, active conversation
          // — 'accepted' is the correct default for all of them.
          await db.execute(
              "ALTER TABLE contacts ADD COLUMN status TEXT NOT NULL DEFAULT 'accepted'");
        }
        if (oldVersion < 3) {
          await _createGroupTables(db);
        }
      },
    );

    return AppDatabase._(db);
  }

  static String _randomPassphrase() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static Future<void> _createGroupTables(Database db) async {
    await db.execute('''
      CREATE TABLE groups (
        group_id TEXT PRIMARY KEY,
        display_name TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE group_members (
        group_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        PRIMARY KEY (group_id, account_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_group_members_group ON group_members(group_id)');
  }
}
