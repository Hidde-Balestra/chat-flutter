import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/messaging/session_manager.dart';
import '../../core/storage/local_store.dart';
import '../../l10n/app_localizations.dart';
import '../shared/identicon.dart';
import '../shared/message_bubble.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({
    super.key,
    required this.sessionManager,
    required this.store,
    required this.groupId,
  });

  final SessionManager sessionManager;
  final LocalStore store;
  final String groupId;

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  List<MessageRecord> _messages = [];
  GroupRecord? _group;
  String? _myAccountId;
  final _controller = TextEditingController();
  Timer? _pollTimer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadGroup();
    _loadMyAccountId();
    // Same cadence as ChatPage's 1:1 polling — see its comment for why.
    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMyAccountId() async {
    final id = await widget.sessionManager.accountId;
    if (!mounted) return;
    setState(() => _myAccountId = id);
  }

  Future<void> _loadGroup() async {
    final group = await widget.store.getGroup(widget.groupId);
    if (!mounted) return;
    setState(() => _group = group);
  }

  Future<void> _poll() async {
    if (!await widget.sessionManager.ensureBootstrapped()) {
      return; // still offline — try again next tick
    }
    try {
      await widget.sessionManager.pollAndDecrypt();
    } catch (_) {
      // transient network error — just retry on the next tick
    }
    await _refresh();
    await _loadGroup();
  }

  Future<void> _refresh() async {
    final messages = await widget.store.messagesWith(widget.groupId);
    if (!mounted) return;
    setState(() => _messages = messages);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final group = _group;
    if (text.isEmpty || _sending || group == null) return;

    setState(() => _sending = true);
    try {
      if (!await widget.sessionManager.ensureBootstrapped()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(AppLocalizations.of(context)!.stillConnecting)),
          );
        }
        return;
      }
      _controller.clear();
      await widget.sessionManager
          .sendGroupMessage(widget.groupId, group.memberAccountIds, text);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.sendFailed(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showRenameDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _group?.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameGroupAction),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.groupNameHint),
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
    if (name == null) return;
    await widget.store
        .setGroupDisplayName(widget.groupId, name.isEmpty ? null : name);
    await _loadGroup();
  }

  Future<void> _showAddMemberDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final accountId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addMemberAction),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.addMemberHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
    if (accountId == null || accountId.isEmpty) return;

    try {
      if (!await widget.sessionManager.ensureBootstrapped()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.stillConnecting)),
          );
        }
        return;
      }
      await widget.sessionManager.addGroupMember(widget.groupId, accountId);
      final updated = {...?_group?.memberAccountIds, accountId}.toList();
      await widget.store.upsertGroup(widget.groupId, memberAccountIds: updated);
      await _loadGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sendFailed(e.toString()))),
        );
      }
    }
  }

  void _showMembers() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.groupMembersTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final memberId in _group?.memberAccountIds ?? <String>[])
                ListTile(
                  leading: Identicon(accountId: memberId, size: 32),
                  title: Text(
                    memberId == _myAccountId
                        ? '${_shorten(memberId)} ${l10n.youLabel}'
                        : _shorten(memberId),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(l10n.close))
        ],
      ),
    );
  }

  Future<void> _confirmLeaveGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveGroupConfirmTitle),
        content: Text(l10n.leaveGroupConfirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leaveGroupMenuEntry),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (!await widget.sessionManager.ensureBootstrapped()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.stillConnecting)),
          );
        }
        return;
      }
      await widget.sessionManager.leaveGroup(widget.groupId);
      await widget.store.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sendFailed(e.toString()))),
        );
      }
    }
  }

  void _showGroupOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.renameGroupAction),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenameDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(l10n.viewMembersMenuEntry),
              onTap: () {
                Navigator.pop(sheetContext);
                _showMembers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: Text(l10n.addMemberAction),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddMemberDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.logout,
                  color: Theme.of(context).colorScheme.error),
              title: Text(l10n.leaveGroupMenuEntry,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmLeaveGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showGroupOptions,
          child: Text(_group?.displayName ?? _shorten(widget.groupId)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text(l10n.noMessagesYet))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return MessageBubble(message: message);
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
                      decoration: InputDecoration(
                        hintText: l10n.typeMessageHint,
                        border: const OutlineInputBorder(),
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

  String _shorten(String id) => id.length > 16
      ? '${id.substring(0, 8)}…${id.substring(id.length - 6)}'
      : id;
}
