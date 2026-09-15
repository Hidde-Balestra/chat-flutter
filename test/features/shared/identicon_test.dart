import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/features/shared/identicon.dart';

void main() {
  group('IdenticonPattern', () {
    test('is deterministic for the same account id', () {
      final accountId = '05${'ab' * 32}';

      final first = IdenticonPattern(accountId);
      final second = IdenticonPattern(accountId);

      expect(first.hue, second.hue);
      expect(first.grid, second.grid);
    });

    test('differs between different account ids', () {
      final a = IdenticonPattern('05${'11' * 32}');
      final b = IdenticonPattern('05${'99' * 32}');

      // Extremely unlikely to collide on both hue *and* the full grid for
      // two very different seeds — a reasonable sanity check that this
      // isn't secretly a constant pattern.
      expect(a.hue == b.hue && a.grid.toString() == b.grid.toString(), isFalse);
    });

    test('grid is horizontally symmetric (columns 3-4 mirror 1-0)', () {
      final pattern = IdenticonPattern('05${'7c' * 32}');

      for (final row in pattern.grid) {
        expect(row, hasLength(5));
        expect(row[3], row[1]);
        expect(row[4], row[0]);
      }
    });
  });
}
