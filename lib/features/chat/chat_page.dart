import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/messaging/session_manager.dart';
import '../../core/storage/local_store.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.sessionManager,
    required this.store,
    required this.contactAccountId,
  });

  final SessionManager sessionManager;
  final LocalStore store;
  final String contactAccountId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<MessageRecord> _messages = [];
  String? _displayName;
  final _controller = TextEditingController();
  Timer? _pollTimer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadContact();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _loadContact() async {
    final contact = await widget.store.getContact(widget.contactAccountId);
    if (!mounted) return;
    setState(() => _displayName = contact?.displayName);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    // Always refresh from the local store after polling — don't rely on
    // *this* poll call's own return value to decide whether to refresh.
    // ContactsPage keeps polling in the background too (it isn't disposed
    // while this page is pushed on top of it), so another poll can win the
    // race and already save the message before this one even runs; relying
    // on our own "did I just receive something" result then means we never
    // refresh even though the store already has the new message.
    if (!await widget.sessionManager.ensureBootstrapped()) {
      return; // still offline — try again next tick
    }
    try {
      await widget.sessionManager.pollAndDecrypt();
    } catch (_) {
      // transient network error — just retry on the next tick
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final messages = await widget.store.messagesWith(widget.contactAccountId);
    if (!mounted) return;
    setState(() => _messages = messages);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await widget.sessionManager.sendMessage(widget.contactAccountId, text);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Versturen mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName ?? _shorten(widget.contactAccountId)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Nog geen berichten. Zeg iets!'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return _MessageBubble(message: message);
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Typ een bericht…',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shorten(String accountId) => accountId.length > 16
      ? '${accountId.substring(0, 8)}…${accountId.substring(accountId.length - 6)}'
      : accountId;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final MessageRecord message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.direction == 'out';
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.body),
      ),
    );
  }
}
