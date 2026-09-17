import '../storage/app_database.dart';
import '../storage/local_store.dart';
import '../storage/secure_identity_store.dart';
import '../storage/sqlite_local_store.dart';

/// Testing-only helper: wipes the current on-device identity and local
/// message database, so the next app start generates (and registers with
/// the backend) a brand-new, throwaway account. Only reachable from the
/// `kDebugMode`-gated entry in [SettingsPage] — never shipped to real users,
/// and never available while app-lock is on (see the gating there for why).
Future<void> resetToFreshTestAccount(LocalStore store) async {
  if (store is SqliteLocalStore) {
    // The file can't be deleted out from under an open connection.
    await store.database.close();
  }
  await SecureIdentityStore().delete();
  await AppDatabase.deleteFile();
}
