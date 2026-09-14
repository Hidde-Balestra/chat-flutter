package nl.hiddebalestra.privacychat

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the biometric prompt to work on Android.
class MainActivity : FlutterFragmentActivity()
