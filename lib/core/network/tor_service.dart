import 'package:flutter/foundation.dart';

enum TorConnectionState { connecting, connected, failed }

class TorStatus {
  const TorStatus(this.state, {this.percent = 0, this.error});

  final TorConnectionState state;
  final int percent;
  final String? error;

  static const initial = TorStatus(TorConnectionState.connecting);
}

/// One relay in a Tor circuit. [ip]/[orPort] are empty/0 if the relay
/// couldn't be resolved from the local consensus cache yet.
class TorRelay {
  const TorRelay({
    required this.fingerprint,
    required this.nickname,
    required this.ip,
    required this.orPort,
  });

  factory TorRelay.fromMap(Map<dynamic, dynamic> map) => TorRelay(
        fingerprint: map['fingerprint'] as String? ?? '',
        nickname: map['nickname'] as String? ?? '',
        ip: map['ip'] as String? ?? '',
        orPort: map['orPort'] as int? ?? 0,
      );

  final String fingerprint;
  final String nickname;
  final String ip;
  final int orPort;
}

/// A currently-built, general-purpose circuit — the path app traffic
/// actually takes: you → guard → middle → exit → the backend.
class TorCircuit {
  const TorCircuit({required this.id, required this.hops});

  factory TorCircuit.fromMap(Map<dynamic, dynamic> map) => TorCircuit(
        id: map['id'] as String? ?? '',
        hops: (map['hops'] as List<dynamic>)
            .map((hop) => TorRelay.fromMap(hop as Map<dynamic, dynamic>))
            .toList(),
      );

  final String id;
  final List<TorRelay> hops;
}

/// Routes the app's network traffic through an embedded Tor client so the
/// backend never sees the device's real IP address — this app has no
/// non-Tor networking path at all.
abstract class TorService {
  /// Starts the embedded Tor client if it isn't already running. Safe to
  /// call more than once.
  Future<void> start();

  /// Live bootstrap status, from [TorConnectionState.connecting] through
  /// to [TorConnectionState.connected] (or [TorConnectionState.failed]).
  ValueListenable<TorStatus> get status;

  /// Resolves to the local SOCKS5 proxy port once Tor has finished
  /// bootstrapping. Never completes if Tor never connects.
  Future<int> get socksPort;

  /// The circuits currently in use for app traffic. Throws if Tor isn't
  /// connected yet or the query otherwise fails — there's nothing
  /// meaningful to show in that case.
  Future<List<TorCircuit>> fetchCircuits();
}
