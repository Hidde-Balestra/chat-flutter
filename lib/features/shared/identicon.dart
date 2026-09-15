import 'package:flutter/material.dart';

import '../../core/crypto/hex.dart';

/// The pure "which cells are filled, what colour" derivation behind
/// [Identicon] — separated out so it can be unit-tested directly, without
/// going through a widget/CustomPainter.
class IdenticonPattern {
  IdenticonPattern(String accountId)
      : hue = (hexToBytes(accountId.substring(2))[0] / 255) * 360,
        grid = _grid(hexToBytes(accountId.substring(2)));

  final double hue;

  /// 5 rows x 5 columns; true = filled. Horizontally symmetric (the
  /// classic GitHub-style identicon layout): only columns 0-2 are actually
  /// random, columns 3-4 mirror columns 1-0.
  final List<List<bool>> grid;

  static List<List<bool>> _grid(List<int> bytes) {
    // 15 bits needed (5 rows x 3 columns), drawn from two bytes of the
    // account id — which, being hex-encoded key material, is already
    // uniformly distributed, so no extra hashing is needed for a good
    // spread of patterns.
    final bits = <bool>[];
    for (final byte in bytes.skip(1).take(2)) {
      for (var b = 7; b >= 0; b--) {
        bits.add((byte >> b) & 1 == 1);
      }
    }
    return List.generate(
      5,
      (row) => List.generate(5, (col) {
        final sourceCol = col <= 2 ? col : 4 - col;
        return bits[row * 3 + sourceCol];
      }),
    );
  }
}

/// A deterministic, symmetric pattern + colour generated purely from an
/// Account ID — so every contact gets a distinct, recognisable "face"
/// without needing an uploaded avatar (which this app deliberately has no
/// way to do: nothing about a contact ever leaves the device except what
/// they chose to send you).
class Identicon extends StatelessWidget {
  const Identicon({super.key, required this.accountId, this.size = 40});

  final String accountId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pattern = IdenticonPattern(accountId);
    final foreground = HSLColor.fromAHSL(1, pattern.hue, 0.55, 0.45).toColor();
    final background = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _IdenticonPainter(
            grid: pattern.grid,
            foreground: foreground,
            background: background,
          ),
        ),
      ),
    );
  }
}

class _IdenticonPainter extends CustomPainter {
  _IdenticonPainter({
    required this.grid,
    required this.foreground,
    required this.background,
  });

  final List<List<bool>> grid;
  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final cell = size.width / 5;
    final paint = Paint()..color = foreground;
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        if (grid[row][col]) {
          canvas.drawRect(
            Rect.fromLTWH(col * cell, row * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_IdenticonPainter oldDelegate) =>
      oldDelegate.grid != grid ||
      oldDelegate.foreground != foreground ||
      oldDelegate.background != background;
}
