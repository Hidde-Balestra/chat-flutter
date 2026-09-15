import 'dart:math';

import '../../core/crypto/hex.dart';

/// A random 64-character hex id (32 bytes) — used for group ids, which the
/// backend requires to match exactly this shape (see
/// GroupController::create's validation). Not a secret: it's just an
/// unguessable identifier, the same role a UUID would normally play.
String randomHexId() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytesToHex(bytes);
}
