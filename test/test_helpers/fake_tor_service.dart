import 'package:flutter/foundation.dart';
import 'package:privacychat/core/network/tor_service.dart';

/// A [TorService] a test can drive directly, without any platform channel.
class FakeTorService implements TorService {
  final _status = ValueNotifier<TorStatus>(TorStatus.initial);
  List<TorCircuit> circuits = [];
  Object? circuitsError;

  @override
  ValueListenable<TorStatus> get status => _status;

  @override
  Future<int> get socksPort async {
    while (_status.value.state != TorConnectionState.connected) {
      await Future<void>.delayed(Duration.zero);
    }
    return 19050;
  }

  @override
  Future<void> start() async {}

  @override
  Future<List<TorCircuit>> fetchCircuits() async {
    final error = circuitsError;
    if (error != null) throw error;
    return circuits;
  }

  void setProgress(int percent) {
    _status.value = TorStatus(TorConnectionState.connecting, percent: percent);
  }

  void setConnected() {
    _status.value = const TorStatus(TorConnectionState.connected, percent: 100);
  }

  void setFailed(String message) {
    _status.value = TorStatus(TorConnectionState.failed, error: message);
  }
}
