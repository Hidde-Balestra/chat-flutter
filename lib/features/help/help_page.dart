import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topics = <_HelpTopic>[
      _HelpTopic(l10n.helpIntroTitle, l10n.helpIntroBody),
      _HelpTopic(l10n.helpAccountIdTitle, l10n.helpAccountIdBody),
      _HelpTopic(l10n.helpAddContactTitle, l10n.helpAddContactBody),
      _HelpTopic(l10n.helpRequestsTitle, l10n.helpRequestsBody),
      _HelpTopic(l10n.helpSecurityTitle, l10n.helpSecurityBody),
      _HelpTopic(l10n.helpLockTitle, l10n.helpLockBody),
      _HelpTopic(l10n.helpDelayTitle, l10n.helpDelayBody),
      _HelpTopic(l10n.helpLostAccessTitle, l10n.helpLostAccessBody),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: topics.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final topic = topics[index];
          return ExpansionTile(
            title: Text(
              topic.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            initiallyExpanded: index == 0,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.body,
                style: const TextStyle(height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HelpTopic {
  const _HelpTopic(this.title, this.body);

  final String title;
  final String body;
}
