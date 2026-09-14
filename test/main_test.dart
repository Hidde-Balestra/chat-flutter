import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/identity_key_pair.dart';
import 'package:privacychat/core/messaging/session_manager.dart';
import 'package:privacychat/core/security/app_lock_controller.dart';
import 'package:privacychat/core/security/auto_lock_settings.dart';
import 'package:privacychat/core/settings/locale_controller.dart';
import 'package:privacychat/core/storage/app_database.dart';
import 'package:privacychat/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/messaging/fakes.dart';
import 'test_helpers/fake_local_auth.dart';
import 'test_helpers/fake_secure_storage.dart';
import 'test_helpers/fake_tor_service.dart';
import 'test_helpers/localized_test_app.dart';

// Tiny on purpose — see settings_page_test.dart for why.
const _testIterations = 10;

Widget _testApp({
  required AppLockController appLock,
  AutoLockSettings? autoLockSettings,
}) {
  Future<AppSession> buildSession(String? passphrase) async {
    final server = FakeServer();
    final sessionManager = SessionManager(
      identity: await IdentityKeyPair.generateRandom(),
      backend: FakeChatBackend(server),
      store: InMemoryLocalStore(),
    );
    return AppSession(
      sessionManager: sessionManager,
      store: InMemoryLocalStore(),
      torService: FakeTorService()..setConnected(),
    );
  }

  return localizedTestApp(StartupPage(
    localeController: LocaleController(),
    appLock: appLock,
    autoLockSettings: autoLockSettings,
    sessionBuilder: buildSession,
  ));
}

/// Gets a fresh [AppLockController] with a PIN of '1234' already enabled,
/// so tests can start from the "needs PIN" stage.
Future<AppLockController> _lockedAppLock() async {
  final platform = installFakeSecureStorage();
  platform.values[AppDatabase.passphraseStorageKey] = 'irrelevant-here';
  final appLock = AppLockController(pbkdf2Iterations: _testIterations);
  await appLock.enable('1234');
  return appLock;
}

Future<void> _unlock(WidgetTester tester) async {
  expect(find.text('Voer je pincode in'), findsOneWidget);
  await tester.enterText(find.byType(TextField), '1234');
  await tester.tap(find.text('Ontgrendelen'));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installFakeLocalAuth();
  });

  group('StartupPage', () {
    testWidgets('with no PIN set, goes straight to the contacts list',
        (tester) async {
      installFakeSecureStorage();
      final appLock = AppLockController(pbkdf2Iterations: _testIterations);

      await tester.pumpWidget(_testApp(appLock: appLock));
      await tester.pump();
      await tester.pump();

      expect(find.text('PrivacyChat'), findsOneWidget);
    });

    testWidgets('with a PIN set, unlocking leads to the contacts list',
        (tester) async {
      final appLock = await _lockedAppLock();

      await tester.pumpWidget(_testApp(appLock: appLock));
      await tester.pump();
      await _unlock(tester);

      expect(find.text('PrivacyChat'), findsOneWidget);
    });

    testWidgets(
        '"lock now" pops back past a pushed screen and shows the PIN screen '
        'again, instead of leaving it reachable', (tester) async {
      final appLock = await _lockedAppLock();

      await tester.pumpWidget(_testApp(appLock: appLock));
      await tester.pump();
      await _unlock(tester);

      // Navigate down into Settings — a screen pushed on top of "/".
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Instellingen'), findsOneWidget);

      await tester.tap(find.text('Nu vergrendelen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vergrendelen'));
      // pumpAndSettle, not a single pump: popUntil's route transition
      // animation needs to finish before the popped screen is actually
      // gone from the tree, not just no longer the topmost route.
      await tester.pumpAndSettle();

      expect(find.text('Voer je pincode in'), findsOneWidget);
      expect(find.text('Instellingen'), findsNothing);
    });

    testWidgets(
        'auto-locks — popping back past a pushed screen too — once the '
        'configured duration has elapsed in the background', (tester) async {
      final appLock = await _lockedAppLock();
      final autoLockSettings = AutoLockSettings();
      await autoLockSettings.setMinutes(5);

      // _maybeAutoLock() compares clock.now() (real wall-clock time,
      // normally) against when the app was paused — tester.pump(Duration)
      // fast-forwards timers/animations, but not DateTime.now() itself, so
      // driving this test through a real elapsed-time comparison needs an
      // actual fake Clock rather than relying on pump's virtual time.
      var now = DateTime(2026, 1, 1, 12);
      final testClock = Clock(() => now);

      await withClock(testClock, () async {
        await tester.pumpWidget(
            _testApp(appLock: appLock, autoLockSettings: autoLockSettings));
        await tester.pump();
        await _unlock(tester);

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Instellingen'), findsOneWidget);

        WidgetsBinding.instance
            .handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        now = now.add(const Duration(minutes: 10));
        WidgetsBinding.instance
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        expect(find.text('Voer je pincode in'), findsOneWidget);
        expect(find.text('Instellingen'), findsNothing);
      });
    });

    testWidgets('does not auto-lock before the configured duration has elapsed',
        (tester) async {
      final appLock = await _lockedAppLock();
      final autoLockSettings = AutoLockSettings();
      await autoLockSettings.setMinutes(5);

      var now = DateTime(2026, 1, 1, 12);
      final testClock = Clock(() => now);

      await withClock(testClock, () async {
        await tester.pumpWidget(
            _testApp(appLock: appLock, autoLockSettings: autoLockSettings));
        await tester.pump();
        await _unlock(tester);

        WidgetsBinding.instance
            .handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        now = now.add(const Duration(minutes: 2));
        WidgetsBinding.instance
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();

        expect(find.text('PrivacyChat'), findsOneWidget);
      });
    });

    testWidgets(
        'does not auto-lock at all when no duration is configured (default)',
        (tester) async {
      final appLock = await _lockedAppLock();

      var now = DateTime(2026, 1, 1, 12);
      final testClock = Clock(() => now);

      await withClock(testClock, () async {
        await tester.pumpWidget(_testApp(appLock: appLock));
        await tester.pump();
        await _unlock(tester);

        WidgetsBinding.instance
            .handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        now = now.add(const Duration(days: 1));
        WidgetsBinding.instance
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();

        expect(find.text('PrivacyChat'), findsOneWidget);
      });
    });
  });
}
