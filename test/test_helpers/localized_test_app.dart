import 'package:flutter/material.dart';
import 'package:privacychat/l10n/app_localizations.dart';

/// Wraps [home] in a MaterialApp configured with the app's real
/// localization delegates (in Dutch, matching the ARB source's original
/// strings), so widgets using `AppLocalizations.of(context)!` work in tests
/// exactly like they do in the real app.
Widget localizedTestApp(Widget home) {
  return MaterialApp(
    locale: const Locale('nl'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}
