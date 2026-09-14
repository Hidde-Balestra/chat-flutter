import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

/// Stand-in for the platform channel behind `local_auth`. Without this
/// installed, calling any `LocalAuthentication` method in a widget test
/// hangs forever (there's no real platform to answer), which makes
/// `pumpAndSettle()` time out on anything that touches
/// `AppLockController.isBiometricAvailable` et al. Install it once per
/// test via [installFakeLocalAuth].
class FakeLocalAuthPlatform extends LocalAuthPlatform {
  bool deviceSupportsBiometricsResult = false;
  List<BiometricType> enrolledBiometrics = const [];
  bool authenticateResult = true;

  @override
  Future<bool> deviceSupportsBiometrics() async =>
      deviceSupportsBiometricsResult;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async =>
      enrolledBiometrics;

  @override
  Future<bool> isDeviceSupported() async => deviceSupportsBiometricsResult;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      authenticateResult;

  @override
  Future<bool> stopAuthentication() async => true;
}

/// Installs a fresh [FakeLocalAuthPlatform] (biometrics unavailable by
/// default, matching "no fingerprint sensor in a test VM") and returns it so
/// a test can flip it on and control the simulated authenticate() result.
FakeLocalAuthPlatform installFakeLocalAuth() {
  final platform = FakeLocalAuthPlatform();
  LocalAuthPlatform.instance = platform;
  return platform;
}
