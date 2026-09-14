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
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lockEnabled = await widget.appLock.isEnabled;
    final biometricAvailable = await widget.appLock.isBiometricAvailable;
    final biometricEnabled = await widget.appLock.isBiometricEnabled;
    if (!mounted) return;
    setState(() {
      _lockEnabled = lockEnabled;
      _biometricAvailable = biometricAvailable;
      _biometricEnabled = biometricEnabled;
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
        setState(() {
          _lockEnabled = false;
          _biometricEnabled = false; // disabling the PIN clears this too
        });
      }
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
            builder: (_) => BiometricEnablePage(appLock: widget.appLock)),
      );
      if (result == true && mounted) {
        setState(() => _biometricEnabled = true);
      }
    } else {
      await widget.appLock.disableBiometric();
      if (mounted) setState(() => _biometricEnabled = false);
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
                if (_lockEnabled && _biometricAvailable)
                  SwitchListTile(
                    title: Text(l10n.settingsBiometricUnlock),
                    subtitle: Text(l10n.settingsBiometricUnlockSubtitle),
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
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
