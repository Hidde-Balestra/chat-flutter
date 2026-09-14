import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release Android manifest declares the INTERNET permission', () {
    // Release builds only merge android/app/src/main/AndroidManifest.xml —
    // NOT the debug/profile ones, which get INTERNET for free (Flutter adds
    // it there for hot reload). That masks this exact bug: the app talks to
    // the backend fine via `flutter run`, but a release APK silently has no
    // network access at all, failing every request with something that
    // looks like a DNS error ("Failed host lookup") instead of a permission
    // error.
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue, reason: 'expected ${manifest.path} to exist');

    expect(
      manifest.readAsStringSync(),
      contains('android.permission.INTERNET'),
      reason: 'Without this permission declared in the *main* manifest specifically, '
          'release APK builds have no network access even though debug builds work fine.',
    );
  });
}
