import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's chosen app language, persisted locally. A null [locale] means
/// "follow the system language" (falling back to English if the system
/// language isn't one of [supportedLocales]).
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  static const _prefsKey = 'app_locale_v1';

  static const supportedLocales = [Locale('en'), Locale('nl')];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      value = Locale(code);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}
