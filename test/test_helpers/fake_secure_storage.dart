import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory stand-in for the platform channel behind `FlutterSecureStorage`,
/// so code using it (identity storage, AppLockController, ...) can run in
/// plain `flutter_test` without a device/emulator. Install it once per test
/// via [installFakeSecureStorage].
class FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return values.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll(
      {required Map<String, String> options}) async {
    return Map.of(values);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    values.clear();
  }
}

/// Installs a fresh [FakeSecureStoragePlatform] as the active
/// `FlutterSecureStoragePlatform.instance` and returns it, so a test can also
/// inspect/seed its contents directly.
FakeSecureStoragePlatform installFakeSecureStorage() {
  final platform = FakeSecureStoragePlatform();
  FlutterSecureStoragePlatform.instance = platform;
  return platform;
}
