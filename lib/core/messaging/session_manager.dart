import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../api/chat_backend.dart';
import '../crypto/double_ratchet.dart';
import '../crypto/identity_key_pair.dart';
import '../crypto/prekey_bundle.dart';
import '../crypto/x3dh.dart';
import '../storage/local_store.dart';
import 'wire_format.dart';

/// Orchestrates everything needed for a working, persisted, end-to-end
/// encrypted 1:1 conversation: publishing prekeys, establishing new sessions
/// via X3DH on first contact, and encrypting/decrypting messages through the
/// Double Ratchet afterwards — with session state durable across restarts.
class SessionManager {
  SessionManager({
    required IdentityKeyPair identity,
    required ChatBackend backend,
    required LocalStore store,
    this.oneTimePreKeyBatchSize = 20,
    this.oneTimePreKeyLowWaterMark = 5,
  })  : _identity = identity,
        _backend = backend,
        _store = store;

  final IdentityKeyPair _identity;
  final ChatBackend _backend;
  final LocalStore _store;
  final int oneTimePreKeyBatchSize;
  final int oneTimePreKeyLowWaterMark;

  String? _accountId;

  Future<String> get accountId async =>
      _accountId ??= await _identity.accountId();

  /// Publishes this device's prekeys (idempotent — safe on every launch) and
  /// logs in via the passwordless challenge/response flow. Call once at
  /// startup before sending or polling.
  Future<void> bootstrap() async {
    final id = await accountId;

    var signedPreKey = await _store.loadLatestSignedPreKey();
    signedPreKey ??= await _generateAndStoreSignedPreKey();

    final signedPreKeyPublic = await signedPreKey.keyPair.extractPublicKey();
    final signature = await _identity.sign(signedPreKeyPublic.bytes);

    await _backend.registerAccount(
      identitySigningKey: await _identity.signingPublicKey,
      identityAgreementKey: await _identity.agreementPublicKey,
      signedPreKey: signedPreKeyPublic,
      signedPreKeySignature: signature.bytes,
      signedPreKeyId: signedPreKey.id,
    );

    final nonce = await _backend.requestAuthChallenge(id);
    final nonceSignature = await _identity.sign(nonce);
    await _backend.verifyAuthChallenge(id, nonceSignature.bytes);

    await _replenishOneTimePreKeysIfNeeded();
  }

  Future<SignedPreKey> _generateAndStoreSignedPreKey() async {
    final key = await SignedPreKey.generate(1);
    await _store.saveOwnSignedPreKey(key);
    return key;
  }

  Future<void> _replenishOneTimePreKeysIfNeeded() async {
    final remaining = await _store.countUnusedOneTimePreKeys();
    if (remaining >= oneTimePreKeyLowWaterMark) {
      return;
    }

    final random = Random.secure();
    final newKeys = <OneTimePreKey>[];
    for (var i = 0; i < oneTimePreKeyBatchSize; i++) {
      newKeys.add(await OneTimePreKey.generate(random.nextInt(1 << 31)));
    }
    await _store.saveOwnOneTimePreKeys(newKeys);

    final byId = <int, SimplePublicKey>{
      for (final key in newKeys) key.id: await key.keyPair.extractPublicKey(),
    };
    await _backend.uploadOneTimePreKeys(byId);
  }

  /// Associated data binds a ciphertext to a specific conversation direction
  /// so a message can't be replayed into a different context. Always
  /// ordered `sender:recipient` so both sides compute the same bytes.
  Future<List<int>> _associatedData(
      String senderAccountId, String recipientAccountId) async {
    return utf8.encode('$senderAccountId:$recipientAccountId');
  }

  Future<void> sendMessage(String contactAccountId, String text) async {
    final myAccountId = await accountId;
    var session = await _store.loadSession(contactAccountId);
    final plaintext = utf8.encode(text);
    final associatedData = await _associatedData(myAccountId, contactAccountId);

    final List<int> wireBytes;
    final String envelopeType;

    if (session == null) {
      final bundle = await _backend.fetchPrekeyBundle(contactAccountId);
      final initiation =
          await X3dh.initiate(localIdentity: _identity, remoteBundle: bundle);
      session = await DoubleRatchetSession.initAsInitiator(
        sharedSecret: initiation.sharedSecret,
        remoteRatchetPublicKey: bundle.signedPreKey,
      );

      final ratchetMessage =
          await session.encrypt(plaintext, associatedData: associatedData);
      wireBytes = WireFormat.encodePrekeyMessage(
        senderIdentityAgreementKey: await _identity.agreementPublicKey,
        senderEphemeralKey: initiation.ephemeralPublicKey,
        signedPreKeyId: bundle.signedPreKeyId,
        oneTimePreKeyId: initiation.usedOneTimePreKeyId,
        ratchetMessage: ratchetMessage,
      );
      envelopeType = 'prekey_msg';
    } else {
      final ratchetMessage =
          await session.encrypt(plaintext, associatedData: associatedData);
      wireBytes = WireFormat.encodeNormalMessage(ratchetMessage);
      envelopeType = 'normal_msg';
    }

    await _backend.postEnvelope(
      recipientAccountId: contactAccountId,
      envelopeType: envelopeType,
      ciphertext: wireBytes,
    );
    await _store.saveSession(contactAccountId, session);
    await _store.upsertContact(contactAccountId);
    await _store.saveMessage(
        contactId: contactAccountId, direction: 'out', body: text);
  }

  /// Polls the mailbox, decrypts everything it can, persists the results and
  /// acknowledges every processed envelope so the server can delete it.
  /// Returns the contact ids that received a new message.
  Future<Set<String>> pollAndDecrypt() async {
    final envelopes = await _backend.pollMailbox();
    final updatedContacts = <String>{};
    final toAck = <int>[];

    for (final envelope in envelopes) {
      try {
        final plaintext = await _decryptEnvelope(envelope);
        await _store.upsertContact(envelope.senderAccountId);
        await _store.saveMessage(
          contactId: envelope.senderAccountId,
          direction: 'in',
          body: utf8.decode(plaintext),
        );
        updatedContacts.add(envelope.senderAccountId);
      } catch (e, stackTrace) {
        // Malformed, out-of-window or already-processed (duplicate
        // delivery) — this can never succeed on retry, so ack it anyway
        // rather than let a single bad envelope wedge the whole mailbox.
        // Still logged (visible via `flutter logs` / adb logcat) so a real
        // bug doesn't silently look like "message never arrived".
        debugPrint(
          'privacychat: dropping undecryptable envelope ${envelope.envelopeId} '
          'from ${envelope.senderAccountId} (${envelope.envelopeType}): $e\n$stackTrace',
        );
      }
      toAck.add(envelope.envelopeId);
    }

    await _backend.ackEnvelopes(toAck);
    return updatedContacts;
  }

  Future<List<int>> _decryptEnvelope(MailboxEnvelope envelope) async {
    final myAccountId = await accountId;
    final associatedData =
        await _associatedData(envelope.senderAccountId, myAccountId);

    if (envelope.envelopeType == 'prekey_msg') {
      final decoded = WireFormat.decodePrekeyMessage(envelope.ciphertext);
      var session = await _store.loadSession(envelope.senderAccountId);

      if (session == null) {
        final signedPreKey = await _store.loadLatestSignedPreKey();
        if (signedPreKey == null || signedPreKey.id != decoded.signedPreKeyId) {
          throw StateError(
              'no matching local signed prekey for id ${decoded.signedPreKeyId}');
        }
        final oneTimePreKey = decoded.oneTimePreKeyId == null
            ? null
            : await _store.takeOneTimePreKeyById(decoded.oneTimePreKeyId!);

        final sharedSecret = await X3dh.respond(
          localIdentity: _identity,
          localSignedPreKeyPair: signedPreKey.keyPair,
          localOneTimePreKeyPair: oneTimePreKey?.keyPair,
          remoteIdentityAgreementKey: decoded.senderIdentityAgreementKey,
          remoteEphemeralKey: decoded.senderEphemeralKey,
        );
        session = DoubleRatchetSession.initAsResponder(
          sharedSecret: sharedSecret,
          selfRatchetKeyPair: signedPreKey.keyPair,
        );
      }

      final plaintext = await session.decrypt(decoded.ratchetMessage,
          associatedData: associatedData);
      await _store.saveSession(envelope.senderAccountId, session);
      return plaintext;
    }

    if (envelope.envelopeType == 'normal_msg') {
      final session = await _store.loadSession(envelope.senderAccountId);
      if (session == null) {
        throw StateError(
            'received a normal_msg with no existing session for this contact');
      }
      final ratchetMessage =
          WireFormat.decodeNormalMessage(envelope.ciphertext);
      final plaintext =
          await session.decrypt(ratchetMessage, associatedData: associatedData);
      await _store.saveSession(envelope.senderAccountId, session);
      return plaintext;
    }

    throw StateError('unsupported envelope type: ${envelope.envelopeType}');
  }
}
