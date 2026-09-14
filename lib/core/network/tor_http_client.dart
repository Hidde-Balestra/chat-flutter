import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:socks5_proxy/socks.dart';

import 'tor_service.dart';

/// An [http.Client] that routes every request through the local Tor SOCKS5
/// proxy — this is the only HTTP client the app ever constructs, so there
/// is no accidental non-Tor request path.
///
/// A request made before Tor has finished bootstrapping simply waits: this
/// mirrors the rest of the app's offline-first design, where the UI never
/// blocks and callers already retry on their own poll tick.
class TorHttpClient extends http.BaseClient {
  TorHttpClient(this._torService, {Duration? requestTimeout})
      : _requestTimeout = requestTimeout ?? const Duration(seconds: 45);

  final TorService _torService;
  final Duration _requestTimeout;
  http.Client? _inner;

  Future<http.Client> _client() async {
    final existing = _inner;
    if (existing != null) return existing;

    final port = await _torService.socksPort;
    // Without a connection timeout, a stalled circuit (Tor connects to
    // *some* relay but the request to the destination never actually gets
    // a response — silently dropped rather than actively refused, which
    // happens over Tor more than on a normal connection) would hang this
    // forever with no error at all, not even a slow one.
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    SocksTCPClient.assignToHttpClient(httpClient, [
      ProxySettings(InternetAddress.loopbackIPv4, port),
    ]);
    return _inner = io_client.IOClient(httpClient);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final client = await _client();
    return client.send(request).timeout(_requestTimeout);
  }
}
