import 'package:flutter/material.dart';

import '../../core/security/app_lock_controller.dart';
import '../../l10n/app_localizations.dart';

const _minPinLength = 4;

/// Shared numeric PIN input: obscured, digits-only, with an error line and
/// a submit button. Each page below wires its own submit behaviour.
class _PinInput extends StatefulWidget {
  const _PinInput({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final String submitLabel;

  /// Return an error message to show, or null on success.
  final Future<String?> Function(String pin) onSubmit;

  @override
  State<_PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<_PinInput> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.length < _minPinLength) {
      setState(() =>
          _error = AppLocalizations.of(context)!.settingsAppLockMinLength);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: l10n.pinHint,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

/// Shown at app launch when app-lock is enabled. Used as root content (not
/// pushed as a route — there's nothing to pop back to yet), so it reports
/// success via [onUnlocked] instead of Navigator.pop. If biometric unlock
/// is set up, it's attempted automatically as soon as this page appears,
/// with the PIN field always available as a fallback (cancelled/failed
/// biometrics, or the user just prefers typing).
class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage(
      {super.key, required this.appLock, required this.onUnlocked});

  final AppLockController appLock;
  final void Function(String passphrase) onUnlocked;

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  bool _biometricAvailable = false;
  bool _biometricAttempting = false;

  @override
  void initState() {
    super.initState();
    _tryBiometricOnLaunch();
  }

  Future<void> _tryBiometricOnLaunch() async {
    final enabled = await widget.appLock.isBiometricEnabled;
    if (!mounted) return;
    setState(() => _biometricAvailable = enabled);
    if (enabled) {
      await _attemptBiometric();
    }
  }

  Future<void> _attemptBiometric() async {
    if (!mounted) return;
    setState(() => _biometricAttempting = true);
    final passphrase = await widget.appLock.unlockWithBiometric(
      reason: AppLocalizations.of(context)!.biometricUnlockReason,
    );
    if (!mounted) return;
    setState(() => _biometricAttempting = false);
    if (passphrase != null) {
      widget.onUnlocked(passphrase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PinInput(
              title: l10n.settingsAppLockUnlockTitle,
              submitLabel: l10n.unlockAction,
              onSubmit: (pin) async {
                final passphrase = await widget.appLock.unlock(pin);
                if (passphrase == null) {
                  return l10n.settingsAppLockWrongPin;
                }
                widget.onUnlocked(passphrase);
                return null;
              },
            ),
            if (_biometricAvailable)
              TextButton.icon(
                onPressed: _biometricAttempting ? null : _attemptBiometric,
                icon: const Icon(Icons.fingerprint),
                label: Text(l10n.useFingerprint),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two-step PIN setup: enter, then confirm. Pops `true` once
/// [AppLockController.enable] has succeeded.
class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key, required this.appLock});

  final AppLockController appLock;

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String? _firstPin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppLockSetTitle)),
      body: Center(
        child: _firstPin == null
            ? _PinInput(
                title: l10n.settingsAppLockChooseTitle,
                submitLabel: l10n.next,
                onSubmit: (pin) async {
                  setState(() => _firstPin = pin);
                  return null;
                },
              )
            : _PinInput(
                title: l10n.settingsAppLockConfirmTitle,
                submitLabel: l10n.setPinAction,
                onSubmit: (pin) async {
                  if (pin != _firstPin) {
                    setState(() => _firstPin = null);
                    return l10n.settingsAppLockPinMismatch;
                  }
                  await widget.appLock.enable(pin);
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                  return null;
                },
              ),
      ),
    );
  }
}

/// Confirms the current PIN before turning on biometric unlock. Pops `true`
/// once [AppLockController.enableBiometric] has succeeded.
class BiometricEnablePage extends StatelessWidget {
  const BiometricEnablePage({super.key, required this.appLock});

  final AppLockController appLock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsBiometricUnlock)),
      body: Center(
        child: _PinInput(
          title: l10n.settingsAppLockUnlockTitle,
          submitLabel: l10n.unlockAction,
          onSubmit: (pin) async {
            try {
              await appLock.enableBiometric(pin);
            } on StateError {
              return l10n.settingsAppLockWrongPin;
            }
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
            return null;
          },
        ),
      ),
    );
  }
}

/// Confirms the current PIN before turning app-lock back off. Pops `true`
/// once [AppLockController.disable] has succeeded.
class PinDisablePage extends StatelessWidget {
  const PinDisablePage({super.key, required this.appLock});

  final AppLockController appLock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppLock)),
      body: Center(
        child: _PinInput(
          title: l10n.settingsAppLockDisableTitle,
          submitLabel: l10n.turnOffAction,
          onSubmit: (pin) async {
            try {
              await appLock.disable(pin);
            } on StateError {
              return l10n.settingsAppLockWrongPin;
            }
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
            return null;
          },
        ),
      ),
    );
  }
}
