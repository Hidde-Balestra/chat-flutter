import 'crypto_algorithms.dart';
import 'hex.dart';

/// A human-comparable fingerprint of a conversation, in the same spirit as
/// Signal's "safety number": derived only from both sides' public Account
/// IDs (already public-key material — see [IdentityKeyPair.accountId]), so
/// no extra key storage is needed. If it matches on both devices — read
/// aloud, or compared by scanning each other's QR code — the conversation
/// genuinely has no one in the middle of it.
class SafetyNumber {
  SafetyNumber._();

  static const _groupCount = 8;

  /// Deterministic regardless of who's "me" and who's "them": both sides
  /// combine their two account IDs in the same (sorted) order, so they
  /// always compute the identical number for the same pair.
  static Future<String> compute(String accountIdA, String accountIdB) async {
    final bytesA = _identityBytes(accountIdA);
    final bytesB = _identityBytes(accountIdB);
    final ordered = _compareBytes(bytesA, bytesB) <= 0
        ? [bytesA, bytesB]
        : [bytesB, bytesA];

    final digest =
        await CryptoAlgorithms.sha256.hash([...ordered[0], ...ordered[1]]);
    return _formatGroups(digest.bytes);
  }

  static List<int> _identityBytes(String accountId) {
    // Account ids are "05" + hex(identity public key) — see
    // IdentityKeyPair.accountId(). Strip that fixed 2-character prefix.
    return hexToBytes(accountId.substring(2));
  }

  static int _compareBytes(List<int> a, List<int> b) {
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// [_groupCount] groups of 5 decimal digits, each derived from 3 bytes of
  /// the digest — 3 bytes (up to 16,777,215) spread across the full 0-99999
  /// range much more evenly than 2 bytes (which tops out at 65,535) would.
  static String _formatGroups(List<int> digestBytes) {
    final groups = <String>[];
    for (var i = 0; i < _groupCount; i++) {
      final offset = i * 3;
      final value = (digestBytes[offset] << 16 |
              digestBytes[offset + 1] << 8 |
              digestBytes[offset + 2]) %
          100000;
      groups.add(value.toString().padLeft(5, '0'));
    }
    return groups.join(' ');
  }
}
