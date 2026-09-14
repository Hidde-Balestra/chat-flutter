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
}
