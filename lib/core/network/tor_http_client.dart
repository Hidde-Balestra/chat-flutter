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
  TorHttpClient(this._torService);

  final TorService _torService;
  http.Client? _inner;

  Future<http.Client> _client() async {
    final existing = _inner;
    if (existing != null) return existing;

    final port = await _torService.socksPort;
    final httpClient = HttpClient();
    SocksTCPClient.assignToHttpClient(httpClient, [
      ProxySettings(InternetAddress.loopbackIPv4, port),
    ]);
    return _inner = io_client.IOClient(httpClient);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final client = await _client();
    return client.send(request);
  }
}
