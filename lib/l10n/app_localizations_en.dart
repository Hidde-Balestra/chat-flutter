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

  @override
  String get settingsHelp => 'Help';

  @override
  String get helpTitle => 'How does the app work?';

  @override
  String get helpMenuEntry => 'How does the app work?';

  @override
  String get helpMenuEntrySubtitle => 'A short explanation in plain language';

  @override
  String get helpIntroTitle => 'What is PrivacyChat?';

  @override
  String get helpIntroBody =>
      'PrivacyChat is a chat app that nobody — not even us — can read along with. You don\'t need a phone number, email address, or password. Everything you need is right here on this screen.';

  @override
  String get helpAccountIdTitle => 'Your Account ID';

  @override
  String get helpAccountIdBody =>
      'The first time you opened the app, a long code was automatically created for you: your Account ID. Think of it as an address other people can use to reach you, without it revealing anything about who you are. You can find it by tapping the badge icon in the top right. Only share this code with people you actually want to talk to — for example over WhatsApp, text message, or in person.';

  @override
  String get helpAddContactTitle => 'Adding someone to chat with';

  @override
  String get helpAddContactBody =>
      'Tap the round + button in the bottom right. Paste or type in the Account ID the other person gave you, and optionally give them a name so you know who it is (that name stays only on your own device). Then you can start chatting right away.';

  @override
  String get helpRequestsTitle => 'What are \"message requests\"?';

  @override
  String get helpRequestsBody =>
      'If someone messages you first, before you\'ve added them, it shows up at the top as a \"message request\", separate from your regular conversations. Open it and choose: Accept (start chatting normally), Decline (the request disappears), or Block (they can no longer bother you).';

  @override
  String get helpSecurityTitle => 'Is it actually secure?';

  @override
  String get helpSecurityBody =>
      'Yes. Every message is locked up on your own device before it\'s even sent, and nobody can open it along the way — not even the server. Only the recipient\'s device holds the key to open it again.';

  @override
  String get helpLockTitle => 'Locking the app itself';

  @override
  String get helpLockBody =>
      'Want to make sure nobody who picks up your unlocked phone can casually look through your conversations? Turn on a PIN under Settings → Security. You can also choose to use your fingerprint or face instead of typing that PIN every time.';

  @override
  String get helpDelayTitle =>
      'Why does a message sometimes take a few seconds to arrive?';

  @override
  String get helpDelayBody =>
      'The app checks every few seconds whether new messages are waiting for you, instead of the server actively notifying it. This is deliberate, so the server needs to know as little about you as possible. A message usually shows up within 1-2 seconds while you have the conversation open.';

  @override
  String get helpLostAccessTitle =>
      'Important: deleted the app or got a new phone?';

  @override
  String get helpLostAccessBody =>
      'There is currently no way to restore your account on another device. If you delete the app, or lose your phone, you also lose access to your conversations and your Account ID, and you (and your contacts) will need to start over. So be careful before deleting it.';

  @override
  String torConnecting(int percent) {
    return 'Connecting via Tor… $percent%';
  }

  @override
  String get torConnected => 'Connected via Tor';

  @override
  String get torFailed => 'Tor connection failed — retrying…';

  @override
  String get helpTorTitle =>
      'Why do I have to wait for \"connecting via Tor\"?';

  @override
  String get helpTorBody =>
      'This app sends all its traffic through Tor, a worldwide network of volunteer-run servers that hides your IP address by routing your connection through a few relays. Because of that, the server can never see where or which device you\'re connecting from. This happens automatically every time you open the app — you don\'t need to do anything, just wait for the icon at the top to change from a loading circle to a shield.';

  @override
  String get settingsTorStatus => 'Tor connection';

  @override
  String get settingsTorStatusSubtitle =>
      'See whether you\'re connected, and which relays you\'re using';

  @override
  String get torStatusPageTitle => 'Tor connection';

  @override
  String get torCircuitsTitle => 'Active circuit';

  @override
  String get torCircuitsExplanation =>
      'These are the relays your traffic is currently passing through, from you to the server.';

  @override
  String get torCircuitsRefresh => 'Refresh';

  @override
  String get torCircuitsEmpty =>
      'No active circuit found yet — try again in a few seconds.';

  @override
  String torCircuitsError(String error) {
    return 'Couldn\'t fetch circuit info: $error';
  }

  @override
  String get torHopGuard => 'Entry';

  @override
  String get torHopMiddle => 'Middle';

  @override
  String get torHopExit => 'Exit';

  @override
  String get torHopUnknownAddress => 'address unknown';

  @override
  String get settingsAutoLock => 'Auto-lock';

  @override
  String get settingsAutoLockSubtitle =>
      'Lock the app on its own if you haven\'t used it for a while';

  @override
  String get autoLockPickerTitle => 'Auto-lock after';

  @override
  String get autoLockNever => 'Never';

  @override
  String autoLockMinutes(num minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get settingsLockNow => 'Lock now';

  @override
  String get settingsLockNowSubtitle =>
      'Closes the app right away and asks for your PIN again next time';

  @override
  String get lockNowConfirmTitle => 'Lock now?';

  @override
  String get lockNowConfirmMessage =>
      'The app will close. Next time you\'ll need to enter your PIN (or fingerprint) again.';

  @override
  String get lockNowAction => 'Lock';

  @override
  String get viewAccountId => 'View Account ID';

  @override
  String get contactAccountIdTitle => 'This contact\'s Account ID';

  @override
  String get helpContactOptionsTitle =>
      'Blocking a contact or deleting the conversation';

  @override
  String get helpContactOptionsBody =>
      'In an open conversation, tap your contact\'s name at the top. From there you can give them a name, block them, or delete the whole conversation.';

  @override
  String get helpAutoLockTitle => 'Locking the app remotely or automatically';

  @override
  String get helpAutoLockBody =>
      'Under Settings → Security you\'ll find \"Lock now\": it closes the app right away and asks for your PIN again next time. You can also set it to do that on its own after you haven\'t used the app for a while.';
}
