import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/messaging/session_manager.dart';
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
  });

  final SessionManager sessionManager;
  final LocalStore store;
  final LocaleController localeController;
  final AppLockController appLock;

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
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
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

  void _openChat(String contactAccountId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ChatPage(
        sessionManager: widget.sessionManager,
        store: widget.store,
        contactAccountId: contactAccountId,
      ),
    ));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
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
          : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title:
                      Text(contact.displayName ?? _shorten(contact.accountId)),
                  subtitle: Text(_shorten(contact.accountId)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.editName,
                    onPressed: () => _showRenameDialog(contact),
                  ),
                  onTap: () => _openChat(contact.accountId),
                  onLongPress: () => _showRenameDialog(contact),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        tooltip: l10n.addContact,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _shorten(String accountId) => accountId.length > 16
      ? '${accountId.substring(0, 8)}…${accountId.substring(accountId.length - 6)}'
      : accountId;
}
