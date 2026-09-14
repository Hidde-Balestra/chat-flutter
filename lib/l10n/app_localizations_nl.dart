// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'PrivacyChat';

  @override
  String get startupPreparingIdentity => 'Je identiteit wordt voorbereid…';

  @override
  String get startupLocalStorageErrorTitle =>
      'Kan de lokale, versleutelde opslag niet openen.';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String get myAccountId => 'Jouw Account ID';

  @override
  String get shareAccountIdExplanation =>
      'Deel dit met iemand om te kunnen chatten. Er zit geen persoonlijke data in.';

  @override
  String get close => 'Sluiten';

  @override
  String get addContact => 'Contact toevoegen';

  @override
  String get contactAccountIdHint => 'Account ID van je contact';

  @override
  String get contactNameHint => 'Naam (optioneel, alleen op dit toestel)';

  @override
  String get cancel => 'Annuleren';

  @override
  String get add => 'Toevoegen';

  @override
  String get editName => 'Naam aanpassen';

  @override
  String get editNameHint => 'Naam (alleen op dit toestel, leeg = geen naam)';

  @override
  String get save => 'Opslaan';

  @override
  String get noContactsYet =>
      'Nog geen contacten. Tik op + en voer het Account ID van iemand in om te beginnen.';

  @override
  String get typeMessageHint => 'Typ een bericht…';

  @override
  String get noMessagesYet => 'Nog geen berichten. Zeg iets!';

  @override
  String sendFailed(String error) {
    return 'Versturen mislukt: $error';
  }

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsLanguage => 'Taal';

  @override
  String get settingsLanguageSystem => 'Systeemtaal';

  @override
  String get settingsSecurity => 'Beveiliging';

  @override
  String get settingsAppLock => 'App vergrendelen met pincode';

  @override
  String get settingsAppLockSubtitle =>
      'Vereist een pincode om de app te openen, bovenop de versleuteling die er al is';

  @override
  String get settingsAppLockSetTitle => 'Stel een pincode in';

  @override
  String get settingsAppLockConfirmTitle => 'Bevestig je pincode';

  @override
  String get settingsAppLockDisableTitle =>
      'Voer je pincode in om dit uit te zetten';

  @override
  String get settingsAppLockUnlockTitle => 'Voer je pincode in';

  @override
  String get settingsAppLockPinMismatch =>
      'Pincodes komen niet overeen — probeer opnieuw';

  @override
  String get settingsAppLockWrongPin => 'Onjuiste pincode';

  @override
  String get settingsAppLockMinLength => 'Gebruik minstens 4 cijfers';

  @override
  String get pinHint => 'Pincode';

  @override
  String get settingsAppLockChooseTitle => 'Kies een pincode';

  @override
  String get next => 'Volgende';

  @override
  String get setPinAction => 'Instellen';

  @override
  String get unlockAction => 'Ontgrendelen';

  @override
  String get turnOffAction => 'Uitzetten';

  @override
  String get messageRequests => 'Berichtverzoeken';

  @override
  String get contactsSectionTitle => 'Contacten';

  @override
  String get deleteContact => 'Verwijderen';

  @override
  String get deleteContactConfirmTitle => 'Dit contact verwijderen?';

  @override
  String deleteContactConfirmMessage(String name) {
    return 'Dit verwijdert het gesprek en alle berichten met $name. Dit kan niet ongedaan gemaakt worden.';
  }

  @override
  String get delete => 'Verwijderen';

  @override
  String get messageRequestBanner =>
      'Berichtverzoek — accepteer om te reageren, of weiger/blokkeer.';

  @override
  String get accept => 'Accepteren';

  @override
  String get decline => 'Weigeren';

  @override
  String get block => 'Blokkeren';

  @override
  String get blockContactConfirmTitle => 'Dit contact blokkeren?';

  @override
  String blockContactConfirmMessage(String name) {
    return '$name kan je dan niet meer berichten. Dit maakt het huidige gesprek leeg.';
  }

  @override
  String get blockedBanner =>
      'Je hebt dit contact geblokkeerd. Diegene kan je niet meer berichten.';

  @override
  String get unblock => 'Deblokkeren';
}
