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

  static const _passphraseKey = 'local_db_passphrase_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<AppDatabase> open({String fileName = 'privacychat.db'}) async {
    var passphrase = await _secureStorage.read(key: _passphraseKey);
    if (passphrase == null) {
      passphrase = _randomPassphrase();
      await _secureStorage.write(key: _passphraseKey, value: passphrase);
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, fileName);

    final db = await openDatabase(
      dbPath,
      password: passphrase,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contacts (
            account_id TEXT PRIMARY KEY,
            display_name TEXT,
            added_at INTEGER NOT NULL
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
        await db.execute('CREATE INDEX idx_messages_contact ON messages(contact_id, sent_at)');
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
      },
    );

    return AppDatabase._(db);
  }

  static String _randomPassphrase() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
