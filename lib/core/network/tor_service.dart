import 'package:flutter/foundation.dart';

enum TorConnectionState { connecting, connected, failed }

class TorStatus {
  const TorStatus(this.state, {this.percent = 0, this.error});

  final TorConnectionState state;
  final int percent;
  final String? error;

  static const initial = TorStatus(TorConnectionState.connecting);
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
}
