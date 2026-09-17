import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/network/tor_service.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/auto_lock_settings.dart';
import '../../core/settings/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../help/help_page.dart';
import 'pin_pages.dart';
import 'tor_status_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.localeController,
    required this.appLock,
    this.torService,
    this.onLockNow,
    this.onResetToFreshTestAccount,
  });

  final LocaleController localeController;
  final AppLockController appLock;

  /// Null in contexts (like most tests) that don't care about Tor status —
  /// when present, a "Tor connection" entry is offered.
  final TorService? torService;

  /// Closes and locks the app; null in contexts (like most tests) that
  /// don't exercise that flow. The "Lock now" row only appears when this
  /// is set (and a PIN is enabled — there'd be nothing to lock back into
  /// otherwise).
  final VoidCallback? onLockNow;

  /// Testing-only: wipes the current identity/database and starts a brand
  /// new one. Null in contexts (like most tests) that don't exercise that
  /// flow; even when set, the entry only appears in [kDebugMode] and only
  /// while app-lock is off (see [_confirmResetToFreshTestAccount]).
  final Future<void> Function()? onResetToFreshTestAccount;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _autoLockSettings = AutoLockSettings();
  bool _lockEnabled = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  int _autoLockMinutes = 0;
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
    final autoLockMinutes = await _autoLockSettings.minutes;
    if (!mounted) return;
    setState(() {
      _lockEnabled = lockEnabled;
      _biometricAvailable = biometricAvailable;
      _biometricEnabled = biometricEnabled;
      _autoLockMinutes = autoLockMinutes;
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

  Future<void> _pickAutoLock() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.autoLockPickerTitle),
        children: [
          for (final minutes in AutoLockSettings.options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, minutes),
              child: Text(minutes == 0
                  ? l10n.autoLockNever
                  : l10n.autoLockMinutes(minutes)),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await _autoLockSettings.setMinutes(selected);
    if (mounted) setState(() => _autoLockMinutes = selected);
  }

  Future<void> _confirmLockNow() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lockNowConfirmTitle),
        content: Text(l10n.lockNowConfirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.lockNowAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onLockNow?.call();
    }
  }

  Future<void> _confirmResetToFreshTestAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsFakeAccountConfirmTitle),
        content: Text(l10n.settingsFakeAccountConfirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsFakeAccountConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onResetToFreshTestAccount?.call();
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
                if (_lockEnabled)
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(l10n.settingsAutoLock),
                    subtitle: Text(l10n.settingsAutoLockSubtitle),
                    trailing: Text(_autoLockMinutes == 0
                        ? l10n.autoLockNever
                        : l10n.autoLockMinutes(_autoLockMinutes)),
                    onTap: _pickAutoLock,
                  ),
                if (_lockEnabled && widget.onLockNow != null)
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l10n.settingsLockNow),
                    subtitle: Text(l10n.settingsLockNowSubtitle),
                    onTap: _confirmLockNow,
                  ),
                if (widget.torService != null) ...[
                  const Divider(),
                  _SectionHeader(l10n.settingsTorStatus),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: Text(l10n.settingsTorStatus),
                    subtitle: Text(l10n.settingsTorStatusSubtitle),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          TorStatusPage(torService: widget.torService!),
                    )),
                  ),
                ],
                if (kDebugMode && widget.onResetToFreshTestAccount != null) ...[
                  const Divider(),
                  _SectionHeader(l10n.settingsDebugSection),
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: Text(l10n.settingsFakeAccount),
                    subtitle: Text(_lockEnabled
                        ? l10n.settingsFakeAccountBlockedByLock
                        : l10n.settingsFakeAccountSubtitle),
                    enabled: !_lockEnabled,
                    onTap: _confirmResetToFreshTestAccount,
                  ),
                ],
                const Divider(),
                _SectionHeader(l10n.settingsHelp),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(l10n.helpMenuEntry),
                  subtitle: Text(l10n.helpMenuEntrySubtitle),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpPage()),
                    );
                  },
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
