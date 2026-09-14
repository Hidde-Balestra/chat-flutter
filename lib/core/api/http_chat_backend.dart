import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../crypto/prekey_bundle.dart';
import 'chat_backend.dart';

class HttpChatBackendException implements Exception {
  HttpChatBackendException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HttpChatBackendException($statusCode): $message';
}

/// Talks to the PHP/MySQL backend over plain REST + polling. Holds the
/// bearer token obtained from [verifyAuthChallenge] in memory and attaches
/// it to every authenticated call automatically.
class HttpChatBackend implements ChatBackend {
  HttpChatBackend({required Uri baseUrl, http.Client? client})
      : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  /// Must end with a trailing slash, e.g. `https://chat.example.com/`.
  final Uri _baseUrl;
  final http.Client _client;
  String? _bearerToken;

  Uri _uri(String path) => _baseUrl.resolve(path);

  Map<String, String> _headers({required bool authenticated}) {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated) {
      final token = _bearerToken;
      if (token == null) {
        throw StateError('not authenticated yet — call verifyAuthChallenge first');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(authenticated: authenticated),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(String path, {bool authenticated = false}) async {
    final response = await _client.get(_uri(path), headers: _headers(authenticated: authenticated));
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw HttpChatBackendException(response.statusCode, decoded['error'] as String? ?? 'request failed');
    }
    return decoded;
  }

  @override
  Future<String> registerAccount({
    required SimplePublicKey identitySigningKey,
    required SimplePublicKey identityAgreementKey,
    required SimplePublicKey signedPreKey,
    required List<int> signedPreKeySignature,
    required int signedPreKeyId,
  }) async {
    final result = await _post('accounts', {
      'identity_pubkey_sign': base64Encode(identitySigningKey.bytes),
      'identity_pubkey_dh': base64Encode(identityAgreementKey.bytes),
      'signed_prekey': base64Encode(signedPreKey.bytes),
      'signed_prekey_sig': base64Encode(signedPreKeySignature),
      'signed_prekey_id': signedPreKeyId,
    });
    return result['account_id'] as String;
  }

  @override
  Future<List<int>> requestAuthChallenge(String accountId) async {
    final result = await _post('auth/challenge', {'account_id': accountId});
    return base64Decode(result['nonce'] as String);
  }

  @override
  Future<void> verifyAuthChallenge(String accountId, List<int> signature) async {
    final result = await _post('auth/verify', {
      'account_id': accountId,
      'signature': base64Encode(signature),
    });
    _bearerToken = result['bearer_token'] as String;
  }

  @override
  Future<void> uploadOneTimePreKeys(Map<int, SimplePublicKey> prekeysById) async {
    await _post(
      'prekeys',
      {
        'prekeys': [
          for (final entry in prekeysById.entries)
            {'prekey_id': entry.key, 'pubkey': base64Encode(entry.value.bytes)},
        ],
      },
      authenticated: true,
    );
  }

  @override
  Future<RemotePreKeyBundle> fetchPrekeyBundle(String accountId) async {
    final result = await _get('prekeys/$accountId', authenticated: true);
    final oneTime = result['one_time_prekey'] as Map<String, dynamic>?;

    return RemotePreKeyBundle(
      accountId: result['account_id'] as String,
      identitySigningKey: SimplePublicKey(
        base64Decode(result['identity_pubkey_sign'] as String),
        type: KeyPairType.ed25519,
      ),
      identityAgreementKey: SimplePublicKey(
        base64Decode(result['identity_pubkey_dh'] as String),
        type: KeyPairType.x25519,
      ),
      signedPreKey: SimplePublicKey(
        base64Decode(result['signed_prekey'] as String),
        type: KeyPairType.x25519,
      ),
      signedPreKeySignature: base64Decode(result['signed_prekey_sig'] as String),
      signedPreKeyId: result['signed_prekey_id'] as int,
      oneTimePreKey: oneTime == null
          ? null
          : SimplePublicKey(base64Decode(oneTime['pubkey'] as String), type: KeyPairType.x25519),
      oneTimePreKeyId: oneTime == null ? null : oneTime['prekey_id'] as int,
    );
  }

  @override
  Future<int> postEnvelope({
    required String recipientAccountId,
    required String envelopeType,
    required List<int> ciphertext,
  }) async {
    final result = await _post(
      'mailbox/$recipientAccountId',
      {
        'ciphertext': base64Encode(ciphertext),
        'envelope_type': envelopeType,
      },
      authenticated: true,
    );
    return result['envelope_id'] as int;
  }

  @override
  Future<List<MailboxEnvelope>> pollMailbox() async {
    final result = await _get('mailbox', authenticated: true);
    final envelopes = result['envelopes'] as List<dynamic>;
    return envelopes.map((entry) {
      final map = entry as Map<String, dynamic>;
      return MailboxEnvelope(
        envelopeId: map['envelope_id'] as int,
        senderAccountId: map['sender_account_id'] as String,
        envelopeType: map['envelope_type'] as String,
        ciphertext: base64Decode(map['ciphertext'] as String),
      );
    }).toList();
  }

  @override
  Future<void> ackEnvelopes(List<int> envelopeIds) async {
    if (envelopeIds.isEmpty) {
      return;
    }
    await _post('mailbox/ack', {'envelope_ids': envelopeIds}, authenticated: true);
  }
}
