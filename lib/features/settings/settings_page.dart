import 'package:flutter/material.dart';

import '../../core/security/app_lock_controller.dart';
import '../../core/settings/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import 'pin_pages.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.localeController,
    required this.appLock,
  });

  final LocaleController localeController;
  final AppLockController appLock;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _lockEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.appLock.isEnabled;
    if (!mounted) return;
    setState(() {
      _lockEnabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggleLock(bool enable) async {
    if (enable) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
            builder: (_) => PinSetupPage(appLock: widget.appLock)),
      );
      if (result == true && mounted) {
        setState(() => _lockEnabled = true);
      }
    } else {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
            builder: (_) => PinDisablePage(appLock: widget.appLock)),
      );
      if (result == true && mounted) {
        setState(() => _lockEnabled = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _SectionHeader(l10n.settingsLanguage),
                ValueListenableBuilder<Locale?>(
                  valueListenable: widget.localeController,
                  builder: (context, locale, _) {
                    return RadioGroup<Locale?>(
                      groupValue: locale,
                      onChanged: widget.localeController.setLocale,
                      child: Column(
                        children: [
                          RadioListTile<Locale?>(
                            title: Text(l10n.settingsLanguageSystem),
                            value: null,
                          ),
                          // Language names are shown in their own language,
                          // regardless of the app's current locale — that's
                          // the standard convention for language pickers.
                          const RadioListTile<Locale?>(
                            title: Text('Nederlands'),
                            value: Locale('nl'),
                          ),
                          const RadioListTile<Locale?>(
                            title: Text('English'),
                            value: Locale('en'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                _SectionHeader(l10n.settingsSecurity),
                SwitchListTile(
                  title: Text(l10n.settingsAppLock),
                  subtitle: Text(l10n.settingsAppLockSubtitle),
                  value: _lockEnabled,
                  onChanged: _toggleLock,
                ),
              ],
            ),
    );
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
