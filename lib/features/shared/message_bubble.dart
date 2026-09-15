import 'package:flutter/material.dart';

import '../../core/storage/local_store.dart';

/// A single chat bubble, aligned right (and tinted) for anything sent from
/// this device, left otherwise. Shared between 1:1 and group chats — a
/// [MessageRecord] doesn't know or care which kind of conversation it
/// belongs to.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

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
