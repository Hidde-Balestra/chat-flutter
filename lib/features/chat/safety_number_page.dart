import 'package:flutter/material.dart';

import '../../core/crypto/safety_number.dart';
import '../../l10n/app_localizations.dart';
import '../shared/qr_code_box.dart';

class SafetyNumberPage extends StatefulWidget {
  const SafetyNumberPage({
    super.key,
    required this.myAccountId,
    required this.contactAccountId,
    required this.contactName,
  });

  final String myAccountId;
  final String contactAccountId;
  final String contactName;

  @override
  State<SafetyNumberPage> createState() => _SafetyNumberPageState();
}

class _SafetyNumberPageState extends State<SafetyNumberPage> {
  String? _number;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    final number =
        await SafetyNumber.compute(widget.myAccountId, widget.contactAccountId);
    if (!mounted) return;
    setState(() => _number = number);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final number = _number;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyNumberPageTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (number == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l10n.safetyNumberLoading),
              ] else ...[
                QrCodeBox(data: number),
                const SizedBox(height: 24),
                Text(
                  number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.safetyNumberExplanation(widget.contactName),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
