import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privacychat/core/api/http_chat_backend.dart';

void main() {
  group('HttpChatBackend', () {
    test('registerAccount sends base64 fields and returns the account_id',
        () async {
      late http.Request captured;
      final backend = HttpChatBackend(
        baseUrl: Uri.parse('https://example.test/'),
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'account_id': '05abc'}), 201);
        }),
      );

      final accountId = await backend.registerAccount(
        identitySigningKey:
            SimplePublicKey([1, 2, 3], type: KeyPairType.ed25519),
        identityAgreementKey:
            SimplePublicKey([4, 5, 6], type: KeyPairType.x25519),
        signedPreKey: SimplePublicKey([7, 8, 9], type: KeyPairType.x25519),
        signedPreKeySignature: [10, 11],
        signedPreKeyId: 1,
      );

      expect(accountId, '05abc');
      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://example.test/accounts');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['identity_pubkey_sign'], base64Encode([1, 2, 3]));
      expect(body['identity_pubkey_dh'], base64Encode([4, 5, 6]));
      expect(body['signed_prekey'], base64Encode([7, 8, 9]));
      expect(body['signed_prekey_sig'], base64Encode([10, 11]));
      expect(body['signed_prekey_id'], 1);
    });

    test('calling an authenticated endpoint before login throws', () async {
      final backend = HttpChatBackend(
        baseUrl: Uri.parse('https://example.test/'),
        client: MockClient((request) async => http.Response('{}', 200)),
      );

      expect(() => backend.pollMailbox(), throwsStateError);
    });

    test('verifyAuthChallenge stores the bearer token for later calls',
        () async {
      final headers = <String>[];
      final backend = HttpChatBackend(
        baseUrl: Uri.parse('https://example.test/'),
        client: MockClient((request) async {
          if (request.url.path == '/auth/verify') {
            return http.Response(
                jsonEncode({'bearer_token': 'dG9rZW4=', 'expires_in': 60}),
                200);
          }
          headers.add(request.headers['Authorization'] ?? '');
          return http.Response(jsonEncode({'envelopes': <dynamic>[]}), 200);
        }),
      );

      await backend.verifyAuthChallenge('05abc', [1, 2, 3]);
      await backend.pollMailbox();

      expect(headers, ['Bearer dG9rZW4=']);
    });

    test('fetchPrekeyBundle parses a bundle with no one-time prekey', () async {
      final backend = HttpChatBackend(
        baseUrl: Uri.parse('https://example.test/'),
        client: MockClient((request) async {
          if (request.url.path == '/auth/verify') {
            return http.Response(
                jsonEncode({'bearer_token': 'dG9rZW4=', 'expires_in': 60}),
                200);
          }
          return http.Response(
            jsonEncode({
              'account_id': '05bob',
              'identity_pubkey_sign': base64Encode([1]),
              'identity_pubkey_dh': base64Encode([2]),
              'signed_prekey': base64Encode([3]),
              'signed_prekey_sig': base64Encode([4]),
              'signed_prekey_id': 7,
              'one_time_prekey': null,
            }),
            200,
          );
        }),
      );
      await backend.verifyAuthChallenge('05abc', [1]);

      final bundle = await backend.fetchPrekeyBundle('05bob');

      expect(bundle.accountId, '05bob');
      expect(bundle.signedPreKeyId, 7);
      expect(bundle.oneTimePreKey, isNull);
      expect(bundle.oneTimePreKeyId, isNull);
    });

    test('pollMailbox decodes every envelope field', () async {
      final backend = HttpChatBackend(
        baseUrl: Uri.parse('https://example.test/'),
        client: MockClient((request) async {
          if (request.url.path == '/auth/verify') {
            return http.Response(
                jsonEncode({'bearer_token': 'dG9rZW4=', 'expires_in': 60}),
                200);
          }
          return http.Response(
            jsonEncode({
              'envelopes': [
                {
                  'envelope_id': 42,
                  'sender_account_id': '05alice',
                  'envelope_type': 'normal_msg',
                  'ciphertext': base64Encode([9, 9, 9]),
                  'created_at': '2026-01-01 00:00:00',
                },
              ],
            }),
            200,
          );
        }),
      );
      await backend.verifyAuthChallenge('05bob', [1]);

      final envelopes = await backend.pollMailbox();

      expect(envelopes, hasLength(1));
      expect(envelopes.single.envelopeId, 42);
      expect(envelopes.single.senderAccountId, '05alice');
      expect(envelopes.single.envelopeType, 'normal_msg');
      expect(envelopes.single.ciphertext, [9, 9, 9]);
    });

    test('ackEnvelopes skips the network call for an empty list', () async {
      var calls = 0;
      final backend = HttpChatBackend(
        baseUrl: Uri.parse('https://example.test/'),
        client: MockClient((request) async {
          if (request.url.path == '/auth/verify') {
            return http.Response(
                jsonEncode({'bearer_token': 'dG9rZW4=', 'expires_in': 60}),
                200);
          }
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await backend.verifyAuthChallenge('05abc', [1]);

      await backend.ackEnvelopes([]);

      expect(calls, 0);
    });

    test(
        'a 4xx/5xx response throws HttpChatBackendException with the server message',
        () async {
      final backend = HttpChatBackend(
        baseUrl: Uri.parse('https://example.test/'),
        client: MockClient((request) async {
          return http.Response(
              jsonEncode({'error': 'Unknown account_id'}), 404);
        }),
      );

      expect(
        () => backend.requestAuthChallenge('05doesnotexist'),
        throwsA(isA<HttpChatBackendException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Unknown account_id')),
      );
    });
  });
}
