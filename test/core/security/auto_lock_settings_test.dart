import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/security/auto_lock_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AutoLockSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to never (0 minutes)', () async {
      expect(await AutoLockSettings().minutes, 0);
    });

    test('persists a chosen duration', () async {
      final settings = AutoLockSettings();
      await settings.setMinutes(5);

      expect(await settings.minutes, 5);
      // A fresh instance reads the same persisted value back.
      expect(await AutoLockSettings().minutes, 5);
    });

    group('shouldLock', () {
      final pausedAt = DateTime(2026, 1, 1, 12);

      test('never locks when minutes is 0, no matter how long has passed', () {
        expect(
          AutoLockSettings.shouldLock(
            minutes: 0,
            pausedAt: pausedAt,
            now: pausedAt.add(const Duration(days: 365)),
          ),
          isFalse,
        );
      });

      test('does not lock before the threshold is reached', () {
        expect(
          AutoLockSettings.shouldLock(
            minutes: 5,
            pausedAt: pausedAt,
            now: pausedAt.add(const Duration(minutes: 4, seconds: 59)),
          ),
          isFalse,
        );
      });

      test('locks exactly at the threshold', () {
        expect(
          AutoLockSettings.shouldLock(
            minutes: 5,
            pausedAt: pausedAt,
            now: pausedAt.add(const Duration(minutes: 5)),
          ),
          isTrue,
        );
      });

      test('locks once well past the threshold', () {
        expect(
          AutoLockSettings.shouldLock(
            minutes: 5,
            pausedAt: pausedAt,
            now: pausedAt.add(const Duration(hours: 2)),
          ),
          isTrue,
        );
      });

      test('treats a negative configured value the same as never', () {
        expect(
          AutoLockSettings.shouldLock(
            minutes: -1,
            pausedAt: pausedAt,
            now: pausedAt.add(const Duration(days: 1)),
          ),
          isFalse,
        );
      });
    });
  });
}
