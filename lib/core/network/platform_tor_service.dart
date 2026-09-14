import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tor_service.dart';

/// Talks to the native `TorController` on the Android side (see
/// `android/app/.../tor/TorController.kt`) over a MethodChannel (to start
/// it) and an EventChannel (to receive bootstrap progress).
class PlatformTorService implements TorService {
  PlatformTorService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('privacychat/tor'),
        _eventChannel =
            eventChannel ?? const EventChannel('privacychat/tor/status');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  final _status = ValueNotifier<TorStatus>(TorStatus.initial);
  final _socksPort = Completer<int>();
  bool _started = false;

  @override
  ValueListenable<TorStatus> get status => _status;

  @override
  Future<int> get socksPort => _socksPort.future;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _eventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      switch (map['state']) {
        case 'connecting':
          _status.value = TorStatus(TorConnectionState.connecting,
              percent: map['percent'] as int? ?? 0);
        case 'connected':
          _status.value =
              const TorStatus(TorConnectionState.connected, percent: 100);
          if (!_socksPort.isCompleted) {
            _socksPort.complete(map['socksPort'] as int);
          }
        case 'failed':
          _status.value = TorStatus(TorConnectionState.failed,
              error: map['message'] as String?);
      }
    });

    await _methodChannel.invokeMethod<void>('start');
  }

  @override
  Future<List<TorCircuit>> fetchCircuits() async {
    final raw = await _methodChannel.invokeMethod<List<dynamic>>('getCircuits');
    return (raw ?? [])
        .map((entry) => TorCircuit.fromMap(entry as Map<dynamic, dynamic>))
        .toList();
  }
}
