import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nl')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PrivacyChat'**
  String get appTitle;

  /// No description provided for @startupPreparingIdentity.
  ///
  /// In en, this message translates to:
  /// **'Preparing your identity…'**
  String get startupPreparingIdentity;

  /// No description provided for @startupLocalStorageErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open the local, encrypted storage.'**
  String get startupLocalStorageErrorTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @myAccountId.
  ///
  /// In en, this message translates to:
  /// **'My Account ID'**
  String get myAccountId;

  /// No description provided for @shareAccountIdExplanation.
  ///
  /// In en, this message translates to:
  /// **'Share this with someone you want to chat with. It contains no personal data.'**
  String get shareAccountIdExplanation;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @contactAccountIdHint.
  ///
  /// In en, this message translates to:
  /// **'Your contact\'s Account ID'**
  String get contactAccountIdHint;

  /// No description provided for @contactNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (optional, only on this device)'**
  String get contactNameHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @editNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (only on this device, empty = no name)'**
  String get editNameHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @noContactsYet.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet. Tap + and enter someone\'s Account ID to get started.'**
  String get noContactsYet;

  /// No description provided for @typeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeMessageHint;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say something!'**
  String get noMessagesYet;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send: {error}'**
  String sendFailed(String error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'Lock app with a PIN'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requires a PIN to open the app, on top of the encryption it already has'**
  String get settingsAppLockSubtitle;

  /// No description provided for @settingsAppLockSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get settingsAppLockSetTitle;

  /// No description provided for @settingsAppLockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get settingsAppLockConfirmTitle;

  /// No description provided for @settingsAppLockDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to turn this off'**
  String get settingsAppLockDisableTitle;

  /// No description provided for @settingsAppLockUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get settingsAppLockUnlockTitle;

  /// No description provided for @settingsAppLockPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match — try again'**
  String get settingsAppLockPinMismatch;

  /// No description provided for @settingsAppLockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get settingsAppLockWrongPin;

  /// No description provided for @settingsAppLockMinLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 digits'**
  String get settingsAppLockMinLength;

  /// No description provided for @pinHint.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinHint;

  /// No description provided for @settingsAppLockChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get settingsAppLockChooseTitle;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @setPinAction.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setPinAction;

  /// No description provided for @unlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockAction;

  /// No description provided for @turnOffAction.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOffAction;

  /// No description provided for @messageRequests.
  ///
  /// In en, this message translates to:
  /// **'Message requests'**
  String get messageRequests;

  /// No description provided for @contactsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsSectionTitle;

  /// No description provided for @deleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteContact;

  /// No description provided for @deleteContactConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this contact?'**
  String get deleteContactConfirmTitle;

  /// No description provided for @deleteContactConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the conversation and all messages with {name}. This can\'t be undone.'**
  String deleteContactConfirmMessage(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @messageRequestBanner.
  ///
  /// In en, this message translates to:
  /// **'Message request — accept to reply, or decline/block.'**
  String get messageRequestBanner;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @blockContactConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block this contact?'**
  String get blockContactConfirmTitle;

  /// No description provided for @blockContactConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be able to message you. This clears the current conversation.'**
  String blockContactConfirmMessage(String name);

  /// No description provided for @blockedBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'ve blocked this contact. They can no longer message you.'**
  String get blockedBanner;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @settingsBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint/face'**
  String get settingsBiometricUnlock;

  /// No description provided for @settingsBiometricUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A faster stand-in for typing your PIN — the PIN is still what actually protects your data'**
  String get settingsBiometricUnlockSubtitle;

  /// No description provided for @useFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get useFingerprint;

  /// No description provided for @biometricUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock PrivacyChat'**
  String get biometricUnlockReason;

  /// No description provided for @settingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHelp;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'How does the app work?'**
  String get helpTitle;

  /// No description provided for @helpMenuEntry.
  ///
  /// In en, this message translates to:
  /// **'How does the app work?'**
  String get helpMenuEntry;

  /// No description provided for @helpMenuEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'A short explanation in plain language'**
  String get helpMenuEntrySubtitle;

  /// No description provided for @helpIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'What is PrivacyChat?'**
  String get helpIntroTitle;

  /// No description provided for @helpIntroBody.
  ///
  /// In en, this message translates to:
  /// **'PrivacyChat is a chat app that nobody — not even us — can read along with. You don\'t need a phone number, email address, or password. Everything you need is right here on this screen.'**
  String get helpIntroBody;

  /// No description provided for @helpAccountIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Account ID'**
  String get helpAccountIdTitle;

  /// No description provided for @helpAccountIdBody.
  ///
  /// In en, this message translates to:
  /// **'The first time you opened the app, a long code was automatically created for you: your Account ID. Think of it as an address other people can use to reach you, without it revealing anything about who you are. You can find it by tapping the badge icon in the top right. Only share this code with people you actually want to talk to — for example over WhatsApp, text message, or in person.'**
  String get helpAccountIdBody;

  /// No description provided for @helpAddContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Adding someone to chat with'**
  String get helpAddContactTitle;

  /// No description provided for @helpAddContactBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the round + button in the bottom right. Paste or type in the Account ID the other person gave you, and optionally give them a name so you know who it is (that name stays only on your own device). Then you can start chatting right away.'**
  String get helpAddContactBody;

  /// No description provided for @helpRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'What are \"message requests\"?'**
  String get helpRequestsTitle;

  /// No description provided for @helpRequestsBody.
  ///
  /// In en, this message translates to:
  /// **'If someone messages you first, before you\'ve added them, it shows up at the top as a \"message request\", separate from your regular conversations. Open it and choose: Accept (start chatting normally), Decline (the request disappears), or Block (they can no longer bother you).'**
  String get helpRequestsBody;

  /// No description provided for @helpSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Is it actually secure?'**
  String get helpSecurityTitle;

  /// No description provided for @helpSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Yes. Every message is locked up on your own device before it\'s even sent, and nobody can open it along the way — not even the server. Only the recipient\'s device holds the key to open it again.'**
  String get helpSecurityBody;

  /// No description provided for @helpLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Locking the app itself'**
  String get helpLockTitle;

  /// No description provided for @helpLockBody.
  ///
  /// In en, this message translates to:
  /// **'Want to make sure nobody who picks up your unlocked phone can casually look through your conversations? Turn on a PIN under Settings → Security. You can also choose to use your fingerprint or face instead of typing that PIN every time.'**
  String get helpLockBody;

  /// No description provided for @helpDelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Why does a message sometimes take a few seconds to arrive?'**
  String get helpDelayTitle;

  /// No description provided for @helpDelayBody.
  ///
  /// In en, this message translates to:
  /// **'The app checks every few seconds whether new messages are waiting for you, instead of the server actively notifying it. This is deliberate, so the server needs to know as little about you as possible. A message usually shows up within 1-2 seconds while you have the conversation open.'**
  String get helpDelayBody;

  /// No description provided for @helpLostAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Important: deleted the app or got a new phone?'**
  String get helpLostAccessTitle;

  /// No description provided for @helpLostAccessBody.
  ///
  /// In en, this message translates to:
  /// **'There is currently no way to restore your account on another device. If you delete the app, or lose your phone, you also lose access to your conversations and your Account ID, and you (and your contacts) will need to start over. So be careful before deleting it.'**
  String get helpLostAccessBody;

  /// No description provided for @torConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting via Tor… {percent}%'**
  String torConnecting(int percent);

  /// No description provided for @torConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected via Tor'**
  String get torConnected;

  /// No description provided for @torFailed.
  ///
  /// In en, this message translates to:
  /// **'Tor connection failed — retrying…'**
  String get torFailed;

  /// No description provided for @helpTorTitle.
  ///
  /// In en, this message translates to:
  /// **'Why do I have to wait for \"connecting via Tor\"?'**
  String get helpTorTitle;

  /// No description provided for @helpTorBody.
  ///
  /// In en, this message translates to:
  /// **'This app sends all its traffic through Tor, a worldwide network of volunteer-run servers that hides your IP address by routing your connection through a few relays. Because of that, the server can never see where or which device you\'re connecting from. This happens automatically every time you open the app — you don\'t need to do anything, just wait for the icon at the top to change from a loading circle to a shield.'**
  String get helpTorBody;

  /// No description provided for @settingsTorStatus.
  ///
  /// In en, this message translates to:
  /// **'Tor connection'**
  String get settingsTorStatus;

  /// No description provided for @settingsTorStatusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See whether you\'re connected, and which relays you\'re using'**
  String get settingsTorStatusSubtitle;

  /// No description provided for @torStatusPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tor connection'**
  String get torStatusPageTitle;

  /// No description provided for @torCircuitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active circuit'**
  String get torCircuitsTitle;

  /// No description provided for @torCircuitsExplanation.
  ///
  /// In en, this message translates to:
  /// **'These are the relays your traffic is currently passing through, from you to the server.'**
  String get torCircuitsExplanation;

  /// No description provided for @torCircuitsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get torCircuitsRefresh;

  /// No description provided for @torCircuitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active circuit found yet — try again in a few seconds.'**
  String get torCircuitsEmpty;

  /// No description provided for @torCircuitsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch circuit info: {error}'**
  String torCircuitsError(String error);

  /// No description provided for @torHopGuard.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get torHopGuard;

  /// No description provided for @torHopMiddle.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get torHopMiddle;

  /// No description provided for @torHopExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get torHopExit;

  /// No description provided for @torHopUnknownAddress.
  ///
  /// In en, this message translates to:
  /// **'address unknown'**
  String get torHopUnknownAddress;

  /// No description provided for @settingsAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get settingsAutoLock;

  /// No description provided for @settingsAutoLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock the app on its own if you haven\'t used it for a while'**
  String get settingsAutoLockSubtitle;

  /// No description provided for @autoLockPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock after'**
  String get autoLockPickerTitle;

  /// No description provided for @autoLockNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get autoLockNever;

  /// No description provided for @autoLockMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}}'**
  String autoLockMinutes(num minutes);

  /// No description provided for @settingsLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get settingsLockNow;

  /// No description provided for @settingsLockNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Closes the app right away and asks for your PIN again next time'**
  String get settingsLockNowSubtitle;

  /// No description provided for @lockNowConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock now?'**
  String get lockNowConfirmTitle;

  /// No description provided for @lockNowConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The app will close. Next time you\'ll need to enter your PIN (or fingerprint) again.'**
  String get lockNowConfirmMessage;

  /// No description provided for @lockNowAction.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lockNowAction;

  /// No description provided for @viewAccountId.
  ///
  /// In en, this message translates to:
  /// **'View Account ID'**
  String get viewAccountId;

  /// No description provided for @contactAccountIdTitle.
  ///
  /// In en, this message translates to:
  /// **'This contact\'s Account ID'**
  String get contactAccountIdTitle;

  /// No description provided for @stillConnecting.
  ///
  /// In en, this message translates to:
  /// **'Still connecting — try again in a few seconds.'**
  String get stillConnecting;

  /// No description provided for @helpContactOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocking a contact or deleting the conversation'**
  String get helpContactOptionsTitle;

  /// No description provided for @helpContactOptionsBody.
  ///
  /// In en, this message translates to:
  /// **'In an open conversation, tap your contact\'s name at the top. From there you can give them a name, block them, or delete the whole conversation.'**
  String get helpContactOptionsBody;

  /// No description provided for @helpAutoLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Locking the app remotely or automatically'**
  String get helpAutoLockTitle;

  /// No description provided for @helpAutoLockBody.
  ///
  /// In en, this message translates to:
  /// **'Under Settings → Security you\'ll find \"Lock now\": it closes the app right away and asks for your PIN again next time. You can also set it to do that on its own after you haven\'t used the app for a while.'**
  String get helpAutoLockBody;

  /// No description provided for @scanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQrTitle;

  /// No description provided for @scanQrButton.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQrButton;

  /// No description provided for @safetyNumberMenuEntry.
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get safetyNumberMenuEntry;

  /// No description provided for @safetyNumberPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get safetyNumberPageTitle;

  /// No description provided for @safetyNumberExplanation.
  ///
  /// In en, this message translates to:
  /// **'Compare this number with {name}\'s — for example by reading it aloud over the phone, or by scanning each other\'s QR code. Does it match? Then you know for sure no one is in between you.'**
  String safetyNumberExplanation(String name);

  /// No description provided for @safetyNumberLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get safetyNumberLoading;

  /// No description provided for @helpQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Adding a contact with a QR code'**
  String get helpQrTitle;

  /// No description provided for @helpQrBody.
  ///
  /// In en, this message translates to:
  /// **'In \"Add contact\", you can tap the scan icon to scan someone\'s QR code instead of typing out their Account ID. It also works the other way round: have someone scan your Account ID screen (tap the badge icon in the top right) to add you.'**
  String get helpQrBody;

  /// No description provided for @helpSafetyNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Making sure you\'re talking to the right person'**
  String get helpSafetyNumberTitle;

  /// No description provided for @helpSafetyNumberBody.
  ///
  /// In en, this message translates to:
  /// **'In a conversation, tap your contact\'s name at the top and choose \"Safety number\". That\'s a string of digits that only matches if your two apps are talking directly to each other, with no one in between. Agree on a way to compare it together — for example by reading it aloud — and check that it matches.'**
  String get helpSafetyNumberBody;

  /// No description provided for @myNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Yourself'**
  String get myNotesTitle;

  /// No description provided for @myNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted notes, kept only on this device'**
  String get myNotesSubtitle;

  /// No description provided for @clearMessagesMenuEntry.
  ///
  /// In en, this message translates to:
  /// **'Clear messages'**
  String get clearMessagesMenuEntry;

  /// No description provided for @myNotesClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear messages?'**
  String get myNotesClearConfirmTitle;

  /// No description provided for @myNotesClearConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes all your saved notes. This can\'t be undone.'**
  String get myNotesClearConfirmMessage;

  /// No description provided for @helpMyNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes to yourself'**
  String get helpMyNotesTitle;

  /// No description provided for @helpMyNotesBody.
  ///
  /// In en, this message translates to:
  /// **'At the top of your contacts list there\'s always \"Yourself\" — a spot to save things for yourself, like a notepad. It also works without internet, and never leaves your device.'**
  String get helpMyNotesBody;

  /// No description provided for @newContactMenuEntry.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get newContactMenuEntry;

  /// No description provided for @newGroupMenuEntry.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroupMenuEntry;

  /// No description provided for @createGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new group'**
  String get createGroupTitle;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name (only visible on this device)'**
  String get groupNameHint;

  /// No description provided for @selectMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose members'**
  String get selectMembersLabel;

  /// No description provided for @noAcceptedContactsForGroup.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any contacts to add to a group yet. Add someone first.'**
  String get noAcceptedContactsForGroup;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @groupsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsSectionTitle;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String memberCount(num count);

  /// No description provided for @groupMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembersTitle;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'(you)'**
  String get youLabel;

  /// No description provided for @addMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMemberAction;

  /// No description provided for @addMemberHint.
  ///
  /// In en, this message translates to:
  /// **'New member\'s Account ID'**
  String get addMemberHint;

  /// No description provided for @renameGroupAction.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get renameGroupAction;

  /// No description provided for @leaveGroupMenuEntry.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroupMenuEntry;

  /// No description provided for @leaveGroupConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this group?'**
  String get leaveGroupConfirmTitle;

  /// No description provided for @leaveGroupConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll stop receiving messages from this group, and it (plus its messages) will be removed from this device. Other members aren\'t notified, but can see that you\'ve left.'**
  String get leaveGroupConfirmMessage;

  /// No description provided for @viewMembersMenuEntry.
  ///
  /// In en, this message translates to:
  /// **'View members'**
  String get viewMembersMenuEntry;

  /// No description provided for @helpGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group chats'**
  String get helpGroupsTitle;

  /// No description provided for @helpGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + and choose \"New group\" to start a conversation with several people at once — pick a name (only visible to you) and the contacts to include. Every message is individually end-to-end encrypted and sent to each member separately, so it takes a little longer for large groups. Tap the name at the top to view/add members, or to leave the group.'**
  String get helpGroupsBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
