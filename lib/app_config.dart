/// Where the PHP/MySQL backend lives. Override at build/run time with
/// `--dart-define=BACKEND_BASE_URL=https://jouw-domein.tld/` if you deploy
/// your own — see backend/README.md. Must end with a slash.
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'https://chat.awake-music.co/api/',
);
