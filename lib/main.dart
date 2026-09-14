import 'dart:async';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'core/api/http_chat_backend.dart';
import 'core/messaging/session_manager.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_identity_store.dart';
import 'core/storage/sqlite_local_store.dart';
import 'features/contacts/contacts_page.dart';

void main() {
  runApp(const PrivacyChatApp());
}

class PrivacyChatApp extends StatelessWidget {
  const PrivacyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrivacyChat',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const StartupPage(),
    );
  }
}

/// The entire onboarding flow, by design: no form, no phone number, no
/// e-mail. Generates (or loads) a local identity and lands straight on the
/// contacts list — which always works offline, since contacts and message
/// history live entirely in the local (encrypted) database. Registering
/// with the backend happens separately in the background and is retried
/// automatically whenever the app polls, so a missing connection at launch
/// never blocks access to anything already on the device.
class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  Future<_Session>? _prepare;

  @override
  void initState() {
    super.initState();
    _prepare = _prepareSession();
  }

  Future<_Session> _prepareSession() async {
    final identity = await SecureIdentityStore().loadOrCreate();
    final database = await AppDatabase.open();
    final store = SqliteLocalStore(database);
    final backend = HttpChatBackend(baseUrl: Uri.parse(backendBaseUrl));
    final sessionManager =
        SessionManager(identity: identity, backend: backend, store: store);

    // Best-effort, non-blocking: if there's no connection right now, the UI
    // below still opens normally with whatever is already stored locally.
    // ContactsPage/ChatPage retry this on every poll tick, so it recovers
    // automatically once connectivity returns.
    unawaited(sessionManager.ensureBootstrapped());

    return _Session(sessionManager: sessionManager, store: store);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_Session>(
        future: _prepare,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Je identiteit wordt voorbereid…'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            // Only a genuinely local failure lands here now (e.g. the
            // on-device database couldn't be opened) — there's no missing
            // connection case left to show, since bootstrap() no longer
            // blocks this future.
            return _StartupError(
              error: snapshot.error!,
              onRetry: () => setState(() => _prepare = _prepareSession()),
            );
          }
          final session = snapshot.data!;
          return ContactsPage(
              sessionManager: session.sessionManager, store: session.store);
        },
      ),
    );
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
            const Text(
              'Kan de lokale, versleutelde opslag niet openen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onRetry, child: const Text('Opnieuw proberen')),
          ],
        ),
      ),
    );
  }
}
