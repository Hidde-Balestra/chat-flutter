import 'package:shared_preferences/shared_preferences.dart';

/// How long the app can sit in the background before it's forced back to
/// the PIN/biometric screen on its own — on top of the manual "lock now"
/// button. 0 means never (the default: only lock when asked to).
class AutoLockSettings {
  static const _key = 'auto_lock_minutes_v1';

  static const options = [0, 1, 5, 15, 30];

  Future<int> get minutes async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  Future<void> setMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, minutes);
  }

  /// True once at least [minutes] have elapsed between [pausedAt] (when the
  /// app went to the background) and [now]. [minutes] <= 0 means "never
  /// auto-lock" and is always false, regardless of how long has passed.
  /// A pure function on purpose — kept separate from the app-lifecycle
  /// plumbing that calls it so the boundary comparison itself (easy to get
  /// off-by-one on) can be unit-tested directly.
  static bool shouldLock({
    required int minutes,
    required DateTime pausedAt,
    required DateTime now,
  }) {
    if (minutes <= 0) return false;
    return now.difference(pausedAt) >= Duration(minutes: minutes);
  }
}
