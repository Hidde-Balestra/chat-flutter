// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PrivacyChat';

  @override
  String get startupPreparingIdentity => 'Preparing your identity…';

  @override
  String get startupLocalStorageErrorTitle =>
      'Can\'t open the local, encrypted storage.';

  @override
  String get retry => 'Try again';

  @override
  String get myAccountId => 'My Account ID';

  @override
  String get shareAccountIdExplanation =>
      'Share this with someone you want to chat with. It contains no personal data.';

  @override
  String get close => 'Close';

  @override
  String get addContact => 'Add contact';

  @override
  String get contactAccountIdHint => 'Your contact\'s Account ID';

  @override
  String get contactNameHint => 'Name (optional, only on this device)';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get editName => 'Edit name';

  @override
  String get editNameHint => 'Name (only on this device, empty = no name)';

  @override
  String get save => 'Save';

  @override
  String get noContactsYet =>
      'No contacts yet. Tap + and enter someone\'s Account ID to get started.';

  @override
  String get typeMessageHint => 'Type a message…';

  @override
  String get noMessagesYet => 'No messages yet. Say something!';

  @override
  String sendFailed(String error) {
    return 'Couldn\'t send: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System language';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsAppLock => 'Lock app with a PIN';

  @override
  String get settingsAppLockSubtitle =>
      'Requires a PIN to open the app, on top of the encryption it already has';

  @override
  String get settingsAppLockSetTitle => 'Set a PIN';

  @override
  String get settingsAppLockConfirmTitle => 'Confirm your PIN';

  @override
  String get settingsAppLockDisableTitle => 'Enter your PIN to turn this off';

  @override
  String get settingsAppLockUnlockTitle => 'Enter your PIN';

  @override
  String get settingsAppLockPinMismatch => 'PINs don\'t match — try again';

  @override
  String get settingsAppLockWrongPin => 'Incorrect PIN';

  @override
  String get settingsAppLockMinLength => 'Use at least 4 digits';

  @override
  String get pinHint => 'PIN';

  @override
  String get settingsAppLockChooseTitle => 'Choose a PIN';

  @override
  String get next => 'Next';

  @override
  String get setPinAction => 'Set';

  @override
  String get unlockAction => 'Unlock';

  @override
  String get turnOffAction => 'Turn off';

  @override
  String get messageRequests => 'Message requests';

  @override
  String get contactsSectionTitle => 'Contacts';

  @override
  String get deleteContact => 'Delete';

  @override
  String get deleteContactConfirmTitle => 'Delete this contact?';

  @override
  String deleteContactConfirmMessage(String name) {
    return 'This removes the conversation and all messages with $name. This can\'t be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get messageRequestBanner =>
      'Message request — accept to reply, or decline/block.';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get block => 'Block';

  @override
  String get blockContactConfirmTitle => 'Block this contact?';

  @override
  String blockContactConfirmMessage(String name) {
    return '$name will no longer be able to message you. This clears the current conversation.';
  }

  @override
  String get blockedBanner =>
      'You\'ve blocked this contact. They can no longer message you.';

  @override
  String get unblock => 'Unblock';

  @override
  String get settingsBiometricUnlock => 'Unlock with fingerprint/face';

  @override
  String get settingsBiometricUnlockSubtitle =>
      'A faster stand-in for typing your PIN — the PIN is still what actually protects your data';

  @override
  String get useFingerprint => 'Use fingerprint';

  @override
  String get biometricUnlockReason => 'Unlock PrivacyChat';
}
