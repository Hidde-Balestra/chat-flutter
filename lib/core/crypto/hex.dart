/// Minimal hex helpers — avoids pulling in a whole package for two one-liners.
String bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

List<int> hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw ArgumentError('hex string must have an even length');
  }
  return [
    for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}
