/// Where the PHP/MySQL backend lives. Override at build/run time with
/// `--dart-define=BACKEND_BASE_URL=https://jouw-domein.tld/` once you've
/// deployed `backend/` — see backend/README.md. Must end with a slash.
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8080/',
);
