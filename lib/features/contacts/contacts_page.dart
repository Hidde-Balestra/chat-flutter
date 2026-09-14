import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/messaging/session_manager.dart';
import '../../core/storage/local_store.dart';
import '../chat/chat_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage(
      {super.key, required this.sessionManager, required this.store});

  final SessionManager sessionManager;
  final LocalStore store;

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
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact toevoegen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'Account ID van je contact'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Naam (optioneel, alleen op dit toestel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(context,
                (idController.text.trim(), nameController.text.trim())),
            child: const Text('Toevoegen'),
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
    final controller = TextEditingController(text: contact.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naam aanpassen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Naam (alleen op dit toestel, leeg = geen naam)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Opslaan'),
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jouw Account ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Deel dit met iemand om te kunnen chatten. Er zit geen persoonlijke data in.'),
            const SizedBox(height: 12),
            SelectableText(
              _myAccountId ?? '…',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Sluiten'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PrivacyChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Mijn Account ID',
            onPressed: _showMyAccountId,
          ),
        ],
      ),
      body: _contacts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nog geen contacten. Tik op + en voer het Account ID van iemand in om te beginnen.',
                  textAlign: TextAlign.center,
                ),
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
                    tooltip: 'Naam aanpassen',
                    onPressed: () => _showRenameDialog(contact),
                  ),
                  onTap: () => _openChat(contact.accountId),
                  onLongPress: () => _showRenameDialog(contact),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        tooltip: 'Contact toevoegen',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _shorten(String accountId) => accountId.length > 16
      ? '${accountId.substring(0, 8)}…${accountId.substring(accountId.length - 6)}'
      : accountId;
}
