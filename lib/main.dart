import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'core/api/http_chat_backend.dart';
import 'core/debug/fake_account_reset.dart';
import 'core/messaging/session_manager.dart';
import 'core/network/platform_tor_service.dart';
import 'core/network/tor_http_client.dart';
import 'core/network/tor_service.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/auto_lock_settings.dart';
import 'core/settings/locale_controller.dart';
import 'core/storage/app_database.dart';
import 'core/storage/local_store.dart';
import 'core/storage/secure_identity_store.dart';
import 'core/storage/sqlite_local_store.dart';
import 'features/contacts/contacts_page.dart';
import 'features/settings/pin_pages.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const PrivacyChatApp());
}

class PrivacyChatApp extends StatefulWidget {
  const PrivacyChatApp({super.key});

  @override
  State<PrivacyChatApp> createState() => _PrivacyChatAppState();
}

class _PrivacyChatAppState extends State<PrivacyChatApp> {
  final _localeController = LocaleController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: _localeController,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'PrivacyChat',
          theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: StartupPage(localeController: _localeController),
        );
      },
    );
  }
}

enum _Stage { loading, needsPin, ready, error }

/// The entire onboarding flow, by design: no form, no phone number, no
/// e-mail. Generates (or loads) a local identity and lands straight on the
/// contacts list — which always works offline, since contacts and message
/// history live entirely in the local (encrypted) database. Registering
/// with the backend happens separately in the background and is retried
/// automatically whenever the app polls, so a missing connection at launch
/// never blocks access to anything already on the device.
///
/// If app-lock is enabled (see [AppLockController]), a PIN screen is shown
/// first — the on-device database literally cannot be opened without it.
class StartupPage extends StatefulWidget {
  const StartupPage({
    super.key,
    required this.localeController,
    this.appLock,
    this.autoLockSettings,
    this.sessionBuilder,
  });

  final LocaleController localeController;

  /// Overridable so tests can supply a fake-secure-storage-backed instance
  /// instead of a fresh production one; defaults to a real
  /// [AppLockController] when not given.
  final AppLockController? appLock;
  final AutoLockSettings? autoLockSettings;

  /// Overridable so tests can skip real secure storage / SQLite / Tor
  /// entirely and hand back an already-built [AppSession] synchronously;
  /// defaults to the real production flow ([_buildProductionSession]).
  final Future<AppSession> Function(String? passphrase)? sessionBuilder;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> with WidgetsBindingObserver {
  late final _appLock = widget.appLock ?? AppLockController();
  late final _autoLockSettings = widget.autoLockSettings ?? AutoLockSettings();
  _Stage _stage = _Stage.loading;
  Object? _error;
  AppSession? _session;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = clock.now();
    } else if (state == AppLifecycleState.resumed) {
      _maybeAutoLock();
    }
  }

  Future<void> _maybeAutoLock() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null || _stage != _Stage.ready) return;
    if (!await _appLock.isEnabled) return;
    final minutes = await _autoLockSettings.minutes;
    if (AutoLockSettings.shouldLock(
        minutes: minutes, pausedAt: pausedAt, now: clock.now())) {
      // Unlike the manual "lock now" button, this doesn't also close the
      // app: the user just brought it back to the foreground themselves,
      // so re-closing it on top of that would be a confusing loop. Dropping
      // the session and requiring the PIN again has the same practical
      // effect — nothing decrypted stays reachable without it.
      _forceRelock();
    }
  }

  void _forceRelock() {
    if (!mounted) return;
    // Without this, a screen pushed on top of the contacts list (an open
    // ChatPage, Settings, ...) stays exactly where it was: rebuilding
    // StartupPage only swaps what route "/" itself shows underneath, it
    // doesn't touch routes already pushed above it. The user would keep
    // looking at (and being able to use) the old screen, still holding a
    // live reference to the very session this is supposed to drop, until
    // they happened to navigate back down to "/" on their own.
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _session = null;
      _stage = _Stage.needsPin;
    });
  }

  /// The Settings "lock now" button: drops every reference to decrypted
  /// in-memory state (session, messages, contacts) so it becomes eligible
  /// for garbage collection, then actually closes the app — matching what
  /// was asked for literally, and the surest way to make sure nothing
  /// decrypted lingers in memory. Next launch requires the PIN again,
  /// exactly like any other cold start with app-lock enabled.
  void _lockNow() {
    // Same reasoning as _forceRelock: pop back to "/" first, in case
    // SystemNavigator.pop() doesn't tear the process down immediately.
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _session = null;
      _stage = _Stage.needsPin;
    });
    SystemNavigator.pop();
  }

  /// Debug-only testing helper wired up from Settings (see
  /// `resetToFreshTestAccount` there for why it's gated on app-lock being
  /// off): wipes the current identity and local database, then re-runs the
  /// exact same bootstrap a cold start with no PIN would — generating a
  /// fresh identity and registering it with the backend as a brand-new
  /// account.
  Future<void> _resetToFreshTestAccount() async {
    final session = _session;
    if (session == null) return;
    await resetToFreshTestAccount(session.store);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _session = null;
      _stage = _Stage.loading;
    });
    await _prepare(passphrase: null);
  }

  Future<void> _checkLock() async {
    setState(() => _stage = _Stage.loading);
    try {
      if (await _appLock.isEnabled) {
        if (!mounted) return;
        setState(() => _stage = _Stage.needsPin);
      } else {
        await _prepare(passphrase: null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _stage = _Stage.error;
      });
    }
  }

  Future<void> _prepare({required String? passphrase}) async {
    try {
      final session =
          await (widget.sessionBuilder ?? _buildProductionSession)(passphrase);
      if (!mounted) return;
      setState(() {
        _session = session;
        _stage = _Stage.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _stage = _Stage.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.startupPreparingIdentity),
              ],
            ),
          ),
        );
      case _Stage.needsPin:
        return PinUnlockPage(
          appLock: _appLock,
          onUnlocked: (passphrase) => _prepare(passphrase: passphrase),
        );
      case _Stage.error:
        // Only a genuinely local failure lands here now (e.g. the on-device
        // database couldn't be opened) — there's no missing-connection case
        // left to show, since bootstrap() no longer blocks this.
        return Scaffold(
          body: _StartupError(error: _error!, onRetry: _checkLock),
        );
      case _Stage.ready:
        final session = _session!;
        return ContactsPage(
          sessionManager: session.sessionManager,
          store: session.store,
          localeController: widget.localeController,
          appLock: _appLock,
          torService: session.torService,
          onLockNow: _lockNow,
          onResetToFreshTestAccount: _resetToFreshTestAccount,
        );
    }
  }
}

/// The real production flow: generate/load the on-device identity, open the
/// encrypted local database, and start the (mandatory) Tor client. Separate
/// from [_StartupPageState._prepare] so tests can substitute a fake
/// (via [StartupPage.sessionBuilder]) without touching real secure storage,
/// SQLite, or a platform channel to a Tor process.
Future<AppSession> _buildProductionSession(String? passphrase) async {
  final identity = await SecureIdentityStore().loadOrCreate();
  final database = await AppDatabase.open(passphrase: passphrase);
  final store = SqliteLocalStore(database);

  // The app has no non-Tor networking path: every request the backend
  // ever sees arrives over Tor, so it never learns the device's real
  // IP address. Requests made before Tor finishes connecting simply
  // wait — same offline-first spirit as the rest of this flow.
  final torService = PlatformTorService();
  unawaited(torService.start());
  final backend = HttpChatBackend(
    baseUrl: Uri.parse(backendBaseUrl),
    client: TorHttpClient(torService),
  );
  final sessionManager =
      SessionManager(identity: identity, backend: backend, store: store);

  // Best-effort, non-blocking: if there's no connection right now, the
  // UI below still opens normally with whatever is already stored
  // locally. ContactsPage/ChatPage retry this on every poll tick.
  unawaited(sessionManager.ensureBootstrapped());

  return AppSession(
    sessionManager: sessionManager,
    store: store,
    torService: torService,
  );
}

class AppSession {
  AppSession({
    required this.sessionManager,
    required this.store,
    required this.torService,
  });

  final SessionManager sessionManager;
  final LocalStore store;
  final TorService torService;
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 48),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.startupLocalStorageErrorTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}
