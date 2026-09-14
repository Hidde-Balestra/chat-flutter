import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:privacychat/core/security/app_lock_controller.dart';
import 'package:privacychat/core/settings/locale_controller.dart';
import 'package:privacychat/core/storage/app_database.dart';
import 'package:privacychat/features/settings/settings_page.dart';
import 'package:privacychat/features/settings/tor_status_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_local_auth.dart';
import '../../test_helpers/fake_secure_storage.dart';
import '../../test_helpers/fake_tor_service.dart';
import '../../test_helpers/localized_test_app.dart';

/// Real PBKDF2 work factor (210k iterations) is deliberately slow — fine in
/// production, but enough to make the indeterminate progress spinner shown
/// during enable()/unlock() keep `pumpAndSettle()` spinning for the whole
/// computation. A tiny iteration count keeps these tests fast and avoids
/// that entirely, without changing what's actually being verified.
const _testIterations = 10;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installFakeLocalAuth();
  });

  group('SettingsPage', () {
    testWidgets('setting up a PIN through the UI enables app-lock end to end',
        (tester) async {
      final platform = installFakeSecureStorage();
      // Simulates the database having already been opened once, like it
      // always has been by the time Settings is reachable in the real app.
      platform.values[AppDatabase.passphraseStorageKey] =
          'existing-db-passphrase';

      final appLock = AppLockController(pbkdf2Iterations: _testIterations);
      await tester.pumpWidget(localizedTestApp(SettingsPage(
        localeController: LocaleController(),
        appLock: appLock,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // Step 1: choose a PIN.
      expect(find.text('Kies een pincode'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Volgende'));
      await tester.pumpAndSettle();

      // Step 2: confirm it.
      expect(find.text('Bevestig je pincode'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Instellen'));
      await tester.pumpAndSettle();

      // Back on SettingsPage, the toggle now reflects that app-lock is on.
      expect(find.text('Instellingen'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);
      expect(await appLock.isEnabled, isTrue);
      expect(await appLock.unlock('1234'), 'existing-db-passphrase');
    });

    testWidgets('mismatched PIN confirmation asks you to start over',
        (tester) async {
      installFakeSecureStorage();
      final appLock = AppLockController(pbkdf2Iterations: _testIterations);
      // No existing passphrase needed for this test — it never reaches
      // AppLockController.enable() because the PINs don't match.

      await tester.pumpWidget(localizedTestApp(SettingsPage(
        localeController: LocaleController(),
        appLock: appLock,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Volgende'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('Instellen'));
      await tester.pumpAndSettle();

      expect(find.text('Pincodes komen niet overeen — probeer opnieuw'),
          findsOneWidget);
      expect(
          find.text('Kies een pincode'), findsOneWidget); // sent back to step 1
      expect(await appLock.isEnabled, isFalse);
    });

    testWidgets(
        'the biometric toggle only shows once a PIN is set and the device '
        'supports it, and lets you turn it on', (tester) async {
      final platform = installFakeSecureStorage();
      platform.values[AppDatabase.passphraseStorageKey] =
          'existing-db-passphrase';
      final localAuth = installFakeLocalAuth()
        ..deviceSupportsBiometricsResult = true
        ..enrolledBiometrics = [BiometricType.fingerprint];

      final appLock = AppLockController(pbkdf2Iterations: _testIterations);
      await tester.pumpWidget(localizedTestApp(SettingsPage(
        localeController: LocaleController(),
        appLock: appLock,
      )));
      await tester.pumpAndSettle();

      // No PIN yet — biometric toggle isn't offered at all.
      expect(find.text('Ontgrendelen met vingerafdruk/gezicht'), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Volgende'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Instellen'));
      await tester.pumpAndSettle();

      // Now that app-lock is on and the device supports it, it appears.
      expect(
          find.text('Ontgrendelen met vingerafdruk/gezicht'), findsOneWidget);
      expect(await appLock.isBiometricEnabled, isFalse);

      await tester.tap(find.text('Ontgrendelen met vingerafdruk/gezicht'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Ontgrendelen'));
      await tester.pumpAndSettle();

      expect(await appLock.isBiometricEnabled, isTrue);
      expect(localAuth.authenticateResult, isTrue); // sanity: fake is wired
    });

    testWidgets('opens the help page from the Help entry', (tester) async {
      installFakeSecureStorage();
      final appLock = AppLockController(pbkdf2Iterations: _testIterations);
      await tester.pumpWidget(localizedTestApp(SettingsPage(
        localeController: LocaleController(),
        appLock: appLock,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hoe werkt de app?'));
      await tester.pumpAndSettle();

      expect(find.text('Wat is PrivacyChat?'), findsOneWidget);
    });

    testWidgets(
        'lock-now and auto-lock only show once a PIN is set, and lock-now '
        'asks for confirmation before calling onLockNow', (tester) async {
      final platform = installFakeSecureStorage();
      platform.values[AppDatabase.passphraseStorageKey] =
          'existing-db-passphrase';
      final appLock = AppLockController(pbkdf2Iterations: _testIterations);
      var lockedNow = false;

      await tester.pumpWidget(localizedTestApp(SettingsPage(
        localeController: LocaleController(),
        appLock: appLock,
        onLockNow: () => lockedNow = true,
      )));
      await tester.pumpAndSettle();

      // No PIN yet — neither row is offered.
      expect(find.text('Nu vergrendelen'), findsNothing);
      expect(find.text('Automatisch vergrendelen'), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Volgende'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Instellen'));
      await tester.pumpAndSettle();

      expect(find.text('Nu vergrendelen'), findsOneWidget);
      expect(find.text('Automatisch vergrendelen'), findsOneWidget);

      await tester.tap(find.text('Nu vergrendelen'));
      await tester.pumpAndSettle();
      expect(find.text('Nu vergrendelen?'), findsOneWidget);
      expect(lockedNow, isFalse); // not yet — still needs confirming

      await tester.tap(find.text('Vergrendelen'));
      await tester.pumpAndSettle();

      expect(lockedNow, isTrue);
    });

    testWidgets('picking an auto-lock duration persists and displays it',
        (tester) async {
      final platform = installFakeSecureStorage();
      platform.values[AppDatabase.passphraseStorageKey] =
          'existing-db-passphrase';
      final appLock = AppLockController(pbkdf2Iterations: _testIterations);

      await tester.pumpWidget(localizedTestApp(SettingsPage(
        localeController: LocaleController(),
        appLock: appLock,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Volgende'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Instellen'));
      await tester.pumpAndSettle();

      expect(find.text('Nooit'), findsOneWidget); // default

      await tester.tap(find.text('Automatisch vergrendelen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 minuten'));
      await tester.pumpAndSettle();

      expect(find.text('5 minuten'), findsOneWidget);
    });

    testWidgets('opens the Tor status page from the Tor entry', (tester) async {
      installFakeSecureStorage();
      final appLock = AppLockController(pbkdf2Iterations: _testIterations);
      final torService = FakeTorService();

      await tester.pumpWidget(localizedTestApp(SettingsPage(
        localeController: LocaleController(),
        appLock: appLock,
        torService: torService,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.security));
      await tester.pumpAndSettle();

      expect(find.byType(TorStatusPage), findsOneWidget);
    });
  });
}
