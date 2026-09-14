import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/messaging/session_manager.dart';
import '../../core/network/tor_service.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/settings/locale_controller.dart';
import '../../core/storage/local_store.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_page.dart';
import '../settings/settings_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    required this.sessionManager,
    required this.store,
    required this.localeController,
    required this.appLock,
    this.torStatus,
  });

  final SessionManager sessionManager;
  final LocalStore store;
  final LocaleController localeController;
  final AppLockController appLock;

  /// Null in contexts (like most tests) that don't care about Tor status —
  /// when present, a small indicator is shown in the app bar.
  final ValueListenable<TorStatus>? torStatus;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<ContactRecord> _contacts = [];
  Timer? _pollTimer;
  String? _myAccountId;

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final id = await widget.sessionManager.accountId;
    if (!mounted) return;
    setState(() => _myAccountId = id);
    await _refreshContacts();
    await _poll();
  }

  Future<void> _poll() async {
    // Keeps working offline: retries login/registration until it succeeds,
    // and a poll failure (no connection right now) is silently swallowed —
    // there's always a next tick to try again once connectivity returns.
    if (!await widget.sessionManager.ensureBootstrapped()) {
      return;
    }
    try {
      await widget.sessionManager.pollAndDecrypt();
    } catch (_) {
      // transient network error — just retry on the next tick
    }
    await _refreshContacts();
  }

  Future<void> _refreshContacts() async {
    final contacts = await widget.store.listContacts();
    if (!mounted) return;
    setState(() => _contacts = contacts);
  }

  Future<void> _showAddContactDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addContact),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.contactAccountIdHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: l10n.contactNameHint),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context,
                (idController.text.trim(), nameController.text.trim())),
            child: Text(l10n.add),
          ),
        ],
      ),
    );

    if (result == null || result.$1.isEmpty) {
      return;
    }
    final (accountId, name) = result;
    await widget.store
        .upsertContact(accountId, displayName: name.isEmpty ? null : name);
    await _refreshContacts();
    if (!mounted) return;
    _openChat(accountId);
  }

  Future<void> _showRenameDialog(ContactRecord contact) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: contact.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.editNameHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (name == null) {
      return;
    }
    await widget.store
        .setDisplayName(contact.accountId, name.isEmpty ? null : name);
    await _refreshContacts();
  }

  Future<bool> _confirmDelete(ContactRecord contact) async {
    final l10n = AppLocalizations.of(context)!;
    final name = contact.displayName ?? _shorten(contact.accountId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteContactConfirmTitle),
        content: Text(l10n.deleteContactConfirmMessage(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.deleteContact(contact.accountId);
      await _refreshContacts();
    }
    return confirmed ?? false;
  }

  void _openChat(String contactAccountId) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (context) => ChatPage(
            sessionManager: widget.sessionManager,
            store: widget.store,
            contactAccountId: contactAccountId,
          ),
        ))
        .then((_) => _refreshContacts());
  }

  void _showMyAccountId() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.myAccountId),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shareAccountIdExplanation),
            const SizedBox(height: 12),
            SelectableText(
              _myAccountId ?? '…',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(l10n.close))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final requests =
        _contacts.where((c) => c.status == ContactStatus.pending).toList();
    final accepted =
        _contacts.where((c) => c.status != ContactStatus.pending).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (widget.torStatus != null) _TorStatusIndicator(widget.torStatus!),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: l10n.myAccountId,
            onPressed: _showMyAccountId,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => SettingsPage(
                localeController: widget.localeController,
                appLock: widget.appLock,
              ),
            )),
          ),
        ],
      ),
      body: _contacts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noContactsYet, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                if (requests.isNotEmpty) ...[
                  _SectionHeader(l10n.messageRequests),
                  for (final contact in requests) _contactTile(contact, l10n),
                  const Divider(),
                ],
                if (requests.isNotEmpty && accepted.isNotEmpty)
                  _SectionHeader(l10n.contactsSectionTitle),
                for (final contact in accepted) _contactTile(contact, l10n),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        tooltip: l10n.addContact,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _contactTile(ContactRecord contact, AppLocalizations l10n) {
    return Dismissible(
      key: ValueKey(contact.accountId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (_) => _confirmDelete(contact),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(contact.status == ContactStatus.pending
              ? Icons.mail_outline
              : Icons.person),
        ),
        title: Text(contact.displayName ?? _shorten(contact.accountId)),
        subtitle: Text(_shorten(contact.accountId)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.editName,
          onPressed: () => _showRenameDialog(contact),
        ),
        onTap: () => _openChat(contact.accountId),
        onLongPress: () => _showRenameDialog(contact),
      ),
    );
  }

  String _shorten(String accountId) => accountId.length > 16
      ? '${accountId.substring(0, 8)}…${accountId.substring(accountId.length - 6)}'
      : accountId;
}

/// A small always-visible app-bar indicator of the mandatory Tor
/// connection: a spinner with a percentage while bootstrapping, a plain
/// onion icon once connected, and a warning icon if it failed. There's no
/// "skip Tor" option — this only ever reflects status, it can't turn it off.
class _TorStatusIndicator extends StatelessWidget {
  const _TorStatusIndicator(this.torStatus);

  final ValueListenable<TorStatus> torStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<TorStatus>(
      valueListenable: torStatus,
      builder: (context, status, _) {
        switch (status.state) {
          case TorConnectionState.connecting:
            return IconButton(
              tooltip: l10n.torConnecting(status.percent),
              icon: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: status.percent / 100,
                ),
              ),
              onPressed: () =>
                  _showStatus(context, l10n.torConnecting(status.percent)),
            );
          case TorConnectionState.connected:
            return IconButton(
              tooltip: l10n.torConnected,
              icon: const Icon(Icons.security),
              onPressed: () => _showStatus(context, l10n.torConnected),
            );
          case TorConnectionState.failed:
            return IconButton(
              tooltip: l10n.torFailed,
              icon: Icon(Icons.warning_amber,
                  color: Theme.of(context).colorScheme.error),
              onPressed: () => _showStatus(context, l10n.torFailed),
            );
        }
      },
    );
  }

  void _showStatus(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
