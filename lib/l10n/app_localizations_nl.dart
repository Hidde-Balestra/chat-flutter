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

  @override
  String get settingsBiometricUnlock => 'Ontgrendelen met vingerafdruk/gezicht';

  @override
  String get settingsBiometricUnlockSubtitle =>
      'Een snellere manier dan je pincode typen — de pincode beschermt je data nog steeds echt';

  @override
  String get useFingerprint => 'Vingerafdruk gebruiken';

  @override
  String get biometricUnlockReason => 'Ontgrendel PrivacyChat';

  @override
  String get settingsHelp => 'Help';

  @override
  String get helpTitle => 'Hoe werkt de app?';

  @override
  String get helpMenuEntry => 'Hoe werkt de app?';

  @override
  String get helpMenuEntrySubtitle => 'Een korte uitleg in gewone taal';

  @override
  String get helpIntroTitle => 'Wat is PrivacyChat?';

  @override
  String get helpIntroBody =>
      'PrivacyChat is een chat-app waarbij niemand — ook wij niet — kan meelezen. Je hebt er geen telefoonnummer, e-mailadres of wachtwoord voor nodig. Alles wat je nodig hebt, staat gewoon op dit scherm.';

  @override
  String get helpAccountIdTitle => 'Jouw Account ID';

  @override
  String get helpAccountIdBody =>
      'Toen je de app voor het eerst opende, is er automatisch een lange code voor je aangemaakt: je Account ID. Dit is een soort adres waarop anderen je kunnen bereiken, zonder dat het iets over wie je bent verraadt. Je vindt \'m door op het naamplaatje-icoontje rechtsboven te tikken. Deel deze code alleen met mensen die je wilt spreken — bijvoorbeeld via WhatsApp, sms, of gewoon mondeling.';

  @override
  String get helpAddContactTitle => 'Iemand toevoegen om mee te chatten';

  @override
  String get helpAddContactBody =>
      'Tik op de ronde +-knop rechtsonder. Plak of typ daar het Account ID dat de ander je heeft gegeven, en geef diegene eventueel een naam zodat je weet wie het is (die naam blijft alleen op jouw eigen toestel staan). Daarna kun je meteen chatten.';

  @override
  String get helpRequestsTitle => '\"Berichtverzoeken\" — wat is dat?';

  @override
  String get helpRequestsBody =>
      'Stuurt iemand jou als eerste een bericht, terwijl je diegene nog niet had toegevoegd? Dan verschijnt dat bovenaan als \"berichtverzoek\", los van je gewone gesprekken. Open het en kies: Accepteren (gewoon chatten), Weigeren (verzoek verdwijnt) of Blokkeren (diegene kan je niet meer lastigvallen).';

  @override
  String get helpSecurityTitle => 'Is het echt veilig?';

  @override
  String get helpSecurityBody =>
      'Ja. Elk bericht wordt al op je eigen toestel op slot gezet vóórdat het verstuurd wordt, en kan onderweg door niemand geopend worden — ook de server niet. Alleen het toestel van de ontvanger heeft de sleutel om het weer te openen.';

  @override
  String get helpLockTitle => 'De app zelf vergrendelen';

  @override
  String get helpLockBody =>
      'Wil je dat niemand die toevallig je ontgrendelde telefoon vastpakt zomaar in je gesprekken kan kijken? Zet dan bij Instellingen → Beveiliging een pincode aan. Je kunt er ook voor kiezen om voortaan je vingerafdruk of gezicht te gebruiken in plaats van elke keer die pincode te typen.';

  @override
  String get helpDelayTitle =>
      'Waarom duurt het soms een paar seconden voordat een bericht aankomt?';

  @override
  String get helpDelayBody =>
      'De app checkt elke paar seconden zelf even of er nieuwe berichten voor je klaarstaan, in plaats van dat de server je actief waarschuwt. Dat is expres zo gebouwd, zodat de server zo min mogelijk over jou hoeft te weten. Een bericht is meestal binnen 1 à 2 seconden zichtbaar als je het gesprek open hebt staan.';

  @override
  String get helpLostAccessTitle =>
      'Belangrijk: app verwijderd of nieuwe telefoon?';

  @override
  String get helpLostAccessBody =>
      'Er is op dit moment geen manier om je account terug te zetten op een ander toestel. Verwijder je de app, of ben je je telefoon kwijt, dan ben je ook de toegang tot je gesprekken en je Account ID kwijt, en moet je (en je contacten) opnieuw beginnen. Wees dus voorzichtig met verwijderen.';

  @override
  String torConnecting(int percent) {
    return 'Verbinden via Tor… $percent%';
  }

  @override
  String get torConnected => 'Verbonden via Tor';

  @override
  String get torFailed => 'Tor-verbinding mislukt — opnieuw proberen…';

  @override
  String get helpTorTitle =>
      'Waarom moet ik eerst \"verbinden via Tor\" wachten?';

  @override
  String get helpTorBody =>
      'Deze app stuurt al je verkeer via Tor, een wereldwijd netwerk van vrijwillige servers dat je IP-adres verbergt door je verbinding via een paar tussenstations om te leiden. Daardoor kan de server nooit zien vanaf welke plek of welk toestel jij verbindt. Dit gebeurt automatisch, elke keer dat je de app opent — je hoeft er niets voor te doen, alleen even wachten tot het pictogram bovenin verandert van een laadcirkel naar een schildje.';
}
