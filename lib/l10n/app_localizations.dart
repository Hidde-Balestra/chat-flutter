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
