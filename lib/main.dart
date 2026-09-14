import 'dart:async';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'core/api/http_chat_backend.dart';
import 'core/messaging/session_manager.dart';
import 'core/security/app_lock_controller.dart';
import 'core/settings/locale_controller.dart';
import 'core/storage/app_database.dart';
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
  const StartupPage({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  final _appLock = AppLockController();
  _Stage _stage = _Stage.loading;
  Object? _error;
  _Session? _session;

  @override
  void initState() {
    super.initState();
    _checkLock();
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
      final identity = await SecureIdentityStore().loadOrCreate();
      final database = await AppDatabase.open(passphrase: passphrase);
      final store = SqliteLocalStore(database);
      final backend = HttpChatBackend(baseUrl: Uri.parse(backendBaseUrl));
      final sessionManager =
          SessionManager(identity: identity, backend: backend, store: store);

      // Best-effort, non-blocking: if there's no connection right now, the
      // UI below still opens normally with whatever is already stored
      // locally. ContactsPage/ChatPage retry this on every poll tick.
      unawaited(sessionManager.ensureBootstrapped());

      if (!mounted) return;
      setState(() {
        _session = _Session(sessionManager: sessionManager, store: store);
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
        );
    }
  }
}

class _Session {
  _Session({required this.sessionManager, required this.store});

  final SessionManager sessionManager;
  final SqliteLocalStore store;
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
