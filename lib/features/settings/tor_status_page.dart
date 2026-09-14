import 'package:flutter/material.dart';

import '../../core/network/tor_service.dart';
import '../../l10n/app_localizations.dart';

class TorStatusPage extends StatefulWidget {
  const TorStatusPage({super.key, required this.torService});

  final TorService torService;

  @override
  State<TorStatusPage> createState() => _TorStatusPageState();
}

class _TorStatusPageState extends State<TorStatusPage> {
  List<TorCircuit>? _circuits;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.torService.status.value.state == TorConnectionState.connected) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final circuits = await widget.torService.fetchCircuits();
      if (!mounted) return;
      setState(() => _circuits = circuits);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.torStatusPageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.torCircuitsRefresh,
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: ValueListenableBuilder<TorStatus>(
        valueListenable: widget.torService.status,
        builder: (context, status, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(status: status),
              const SizedBox(height: 24),
              Text(l10n.torCircuitsTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.torCircuitsExplanation,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (!_loading && _error != null)
                Text(l10n.torCircuitsError('$_error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (!_loading && _error == null && (_circuits?.isEmpty ?? true))
                Text(l10n.torCircuitsEmpty),
              if (!_loading && _circuits != null)
                for (final circuit in _circuits!)
                  _CircuitCard(circuit: circuit, l10n: l10n),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final TorStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, text, color) = switch (status.state) {
      TorConnectionState.connecting => (
          Icons.sync,
          l10n.torConnecting(status.percent),
          Theme.of(context).colorScheme.primary,
        ),
      TorConnectionState.connected => (
          Icons.security,
          l10n.torConnected,
          Theme.of(context).colorScheme.primary,
        ),
      TorConnectionState.failed => (
          Icons.warning_amber,
          l10n.torFailed,
          Theme.of(context).colorScheme.error,
        ),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text),
      ),
    );
  }
}

class _CircuitCard extends StatelessWidget {
  const _CircuitCard({required this.circuit, required this.l10n});

  final TorCircuit circuit;
  final AppLocalizations l10n;

  String _hopLabel(int index, int total) {
    if (index == 0) return l10n.torHopGuard;
    if (index == total - 1) return l10n.torHopExit;
    return l10n.torHopMiddle;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < circuit.hops.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.lens, size: 10),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_hopLabel(i, circuit.hops.length)}: '
                        '${circuit.hops[i].nickname} '
                        '(${circuit.hops[i].ip.isEmpty ? l10n.torHopUnknownAddress : circuit.hops[i].ip})',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
