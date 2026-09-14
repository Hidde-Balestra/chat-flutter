import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:privacychat/core/security/app_lock_controller.dart';
import 'package:privacychat/core/storage/app_database.dart';

import '../../test_helpers/fake_local_auth.dart';
import '../../test_helpers/fake_secure_storage.dart';

void main() {
  group('AppLockController', () {
    late FakeSecureStoragePlatform platform;
    late FakeLocalAuthPlatform localAuth;
    late AppLockController appLock;

    setUp(() {
      platform = installFakeSecureStorage();
      localAuth = installFakeLocalAuth();
      appLock = AppLockController();
    });

    test('is not enabled until a PIN is set', () async {
      expect(await appLock.isEnabled, isFalse);
    });

    test('enable() requires an existing database passphrase', () async {
      expect(() => appLock.enable('1234'), throwsStateError);
    });

    test(
        'enable() then unlock() with the right PIN returns the original passphrase',
        () async {
      platform.values[AppDatabase.passphraseStorageKey] =
          'super-secret-db-passphrase';

      await appLock.enable('1234');

      expect(await appLock.isEnabled, isTrue);
      // The raw passphrase must no longer sit in plain storage once wrapped.
      expect(platform.values.containsKey(AppDatabase.passphraseStorageKey),
          isFalse);

      final unlocked = await appLock.unlock('1234');
      expect(unlocked, 'super-secret-db-passphrase');
    });

    test('unlock() with the wrong PIN returns null, not the passphrase',
        () async {
      platform.values[AppDatabase.passphraseStorageKey] =
          'super-secret-db-passphrase';
      await appLock.enable('1234');

      final unlocked = await appLock.unlock('0000');

      expect(unlocked, isNull);
    });

    test('unlock() returns null when no PIN has ever been set', () async {
      expect(await appLock.unlock('1234'), isNull);
    });

    test('disable() with the right PIN restores the plain passphrase',
        () async {
      platform.values[AppDatabase.passphraseStorageKey] =
          'super-secret-db-passphrase';
      await appLock.enable('1234');

      await appLock.disable('1234');

      expect(await appLock.isEnabled, isFalse);
      expect(
        platform.values[AppDatabase.passphraseStorageKey],
        'super-secret-db-passphrase',
      );
    });

    test('disable() with the wrong PIN throws and leaves the lock in place',
        () async {
      platform.values[AppDatabase.passphraseStorageKey] =
          'super-secret-db-passphrase';
      await appLock.enable('1234');

      expect(() => appLock.disable('0000'), throwsStateError);
      expect(await appLock.isEnabled, isTrue);
    });

    group('biometric unlock', () {
      test('is unavailable when the device reports no enrolled biometrics',
          () async {
        localAuth.deviceSupportsBiometricsResult = false;
        expect(await appLock.isBiometricAvailable, isFalse);
      });

      test('is available when the device supports and has enrolled biometrics',
          () async {
        localAuth.deviceSupportsBiometricsResult = true;
        localAuth.enrolledBiometrics = [BiometricType.fingerprint];
        expect(await appLock.isBiometricAvailable, isTrue);
      });

      test('enableBiometric() requires the correct PIN', () async {
        platform.values[AppDatabase.passphraseStorageKey] = 'secret';
        await appLock.enable('1234');

        expect(() => appLock.enableBiometric('0000'), throwsStateError);
        expect(await appLock.isBiometricEnabled, isFalse);
      });

      test(
          'unlockWithBiometric() returns the passphrase after a successful prompt',
          () async {
        platform.values[AppDatabase.passphraseStorageKey] = 'secret';
        await appLock.enable('1234');
        await appLock.enableBiometric('1234');

        localAuth.authenticateResult = true;
        expect(await appLock.unlockWithBiometric(), 'secret');
      });

      test(
          'unlockWithBiometric() returns null if the prompt is cancelled/fails',
          () async {
        platform.values[AppDatabase.passphraseStorageKey] = 'secret';
        await appLock.enable('1234');
        await appLock.enableBiometric('1234');

        localAuth.authenticateResult = false;
        expect(await appLock.unlockWithBiometric(), isNull);
      });

      test('unlockWithBiometric() returns null when never set up', () async {
        expect(await appLock.unlockWithBiometric(), isNull);
      });

      test('disable() also turns off biometric unlock', () async {
        platform.values[AppDatabase.passphraseStorageKey] = 'secret';
        await appLock.enable('1234');
        await appLock.enableBiometric('1234');
        expect(await appLock.isBiometricEnabled, isTrue);

        await appLock.disable('1234');

        expect(await appLock.isBiometricEnabled, isFalse);
      });
    });
  });
}
