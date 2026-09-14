import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/security/app_lock_controller.dart';
import 'package:privacychat/core/settings/locale_controller.dart';
import 'package:privacychat/core/storage/app_database.dart';
import 'package:privacychat/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_secure_storage.dart';
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
  });
}
