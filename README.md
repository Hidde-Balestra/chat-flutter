# PrivacyChat (Flutter client)

Vriendelijke, privacy-first chat-app: geen telefoonnummer, e-mail of
wachtwoord nodig, en berichten (en zoveel mogelijk metadata) zijn end-to-end
versleuteld met een Signal-achtig protocol (X3DH + Double Ratchet). Zie het
volledige plan: `/home/admin/.claude/plans/zippy-soaring-pearl.md`.

## Status

Fase 1–3 van het plan zijn klaar: cryptografische kern (X3DH + Double
Ratchet), lokale versleutelde opslag (SQLCipher), een REST/polling-client
voor de PHP-backend, en een eenvoudige contacten- + chat-UI. Alles is
geverifieerd met `flutter analyze` (geen issues) en `flutter test` (22/22
groen). Groepschats (fase 4) en verdere afwerking (fase 5) volgen nog — zie
het volledige plan voor de architectuur.

Je moet zelf nog een PHP-backend draaien (zie de `backend/`-map in het
hoofdproject) en de URL ervan instellen — zie **Backend-URL instellen**
hieronder.

## Setup

```bash
flutter pub get
flutter test        # crypto-core + sessiebeheer unit-tests
flutter run --dart-define=BACKEND_BASE_URL=https://jouw-backend.tld/
```

Zonder `--dart-define` gebruikt de app `http://localhost:8080/` (zie
`lib/app_config.dart`).

## Structuur

```
lib/core/crypto/       # identity, X3DH, Double Ratchet — geen UI- of netwerkcode
lib/core/api/          # ChatBackend-interface + echte HTTP-implementatie
lib/core/messaging/    # wire-format + SessionManager (koppelt crypto aan backend)
lib/core/storage/      # LocalStore-interface + SQLCipher-implementatie
lib/features/          # contacten- en chat-UI
test/core/             # round-trip tests + een end-to-end test met een
                        # in-memory nep-server (geen echte backend nodig)
```

## Releases (GitHub Actions)

`.github/workflows/release-apk.yml` bouwt bij het aanmaken van een GitHub
Release (of handmatig via "Run workflow") een release-APK (`flutter build
apk --release`, dus één universeel bestand, geen per-ABI-splits) en hangt
'm aan de release. De APK is ondertekend met de standaard debug-key van het
Flutter-template — prima om te zij-laden/testen, niet geschikt voor de Play
Store zonder een eigen signing-config.

## Cryptografische ontwerpkeuzes

- **Identiteit**: een lokaal gegenereerde Ed25519/X25519-sleutelset. De
  Account ID (`"05" + hex(Ed25519 public key)`) is puur wiskundig afgeleid,
  bevat geen persoonsgegevens en wordt nooit naar een centrale identity
  provider gestuurd.
- **Sessie-opbouw**: X3DH (`lib/core/crypto/x3dh.dart`) — laat twee partijen
  een gedeeld geheim afspreken zelfs als de ontvanger offline is, via
  prekeys die de (blinde) server namens hen bewaart.
- **Berichten**: Double Ratchet (`lib/core/crypto/double_ratchet.dart`) — elk
  bericht krijgt een eigen sleutel (forward secrecy), en de sessie herstelt
  vanzelf na een sleutel-lek zodra beide kanten weer een bericht sturen
  (break-in recovery).
- Alle AEAD-versleuteling gebruikt ChaCha20-Poly1305; sleutelafleiding
  gebeurt met HKDF/HMAC-SHA256, via het onderhouden `cryptography`
  Dart-pakket (geen eigen, ongeteste primitieven).
