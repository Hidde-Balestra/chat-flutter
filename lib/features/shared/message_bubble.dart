import 'package:flutter/material.dart';

import '../../core/storage/local_store.dart';
import '../../l10n/app_localizations.dart';

/// A single chat bubble, aligned right (and tinted) for anything sent from
/// this device, left otherwise. Shared between 1:1 and group chats — a
/// [MessageRecord] doesn't know or care which kind of conversation it
/// belongs to.
///
/// For an outgoing message, a small status indicator sits in the
/// bottom-right corner (a clock while [MessageStatus.sending], a checkmark
/// once [MessageStatus.sent]) so sending never looks instantaneous when it
/// isn't, and a failure never looks like the message quietly vanished.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.onRetry});

  final MessageRecord message;

  /// Called when a [MessageStatus.failed] bubble is tapped. Only ever
  /// invoked for outgoing messages — omit it (e.g. for a read-only history
  /// view) to just hide the retry affordance instead of showing a dead tap
  /// target.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isMine = message.direction == 'out';
    final colorScheme = Theme.of(context).colorScheme;
    final isFailed = isMine && message.status == MessageStatus.failed;

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isFailed
            ? colorScheme.errorContainer
            : isMine
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message.body),
          if (isMine) ...[
            const SizedBox(height: 2),
            _StatusIndicator(status: message.status),
          ],
        ],
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: isFailed && onRetry != null
          ? InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onRetry,
              child: Tooltip(
                message:
                    AppLocalizations.of(context)!.messageStatusFailedTapToRetry,
                child: bubble,
              ),
            )
          : bubble,
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    switch (status) {
      case MessageStatus.sending:
        return Tooltip(
          message: l10n.messageStatusSending,
          child: SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
            ),
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.done,
            size: 14, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6));
      case MessageStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 14, color: colorScheme.error),
            const SizedBox(width: 4),
            Icon(Icons.refresh, size: 14, color: colorScheme.error),
          ],
        );
    }
  }
}
