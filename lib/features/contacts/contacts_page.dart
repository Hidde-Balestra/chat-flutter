import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/messaging/session_manager.dart';
import '../../core/storage/local_store.dart';
import '../chat/chat_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.sessionManager, required this.store});

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
    await widget.sessionManager.pollAndDecrypt();
    await _refreshContacts();
  }

  Future<void> _refreshContacts() async {
    final contacts = await widget.store.listContacts();
    if (!mounted) return;
    setState(() => _contacts = contacts);
  }

  Future<void> _showAddContactDialog() async {
    final controller = TextEditingController();
    final accountId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact toevoegen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Account ID van je contact'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );

    if (accountId == null || accountId.isEmpty) {
      return;
    }
    await widget.store.upsertContact(accountId);
    await _refreshContacts();
    if (!mounted) return;
    _openChat(accountId);
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
            const Text('Deel dit met iemand om te kunnen chatten. Er zit geen persoonlijke data in.'),
            const SizedBox(height: 12),
            SelectableText(
              _myAccountId ?? '…',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sluiten'))],
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
                  title: Text(contact.displayName ?? _shorten(contact.accountId)),
                  subtitle: Text(_shorten(contact.accountId)),
                  onTap: () => _openChat(contact.accountId),
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
