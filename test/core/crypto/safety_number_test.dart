import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/safety_number.dart';

void main() {
  group('SafetyNumber', () {
    final alice = '05${'11' * 32}';
    final bob = '05${'22' * 32}';
    final carol = '05${'33' * 32}';

    test('is the same regardless of argument order', () async {
      final ab = await SafetyNumber.compute(alice, bob);
      final ba = await SafetyNumber.compute(bob, alice);

      expect(ab, ba);
    });

    test('is deterministic across calls', () async {
      final first = await SafetyNumber.compute(alice, bob);
      final second = await SafetyNumber.compute(alice, bob);

      expect(first, second);
    });

    test('differs between different pairs', () async {
      final aliceBob = await SafetyNumber.compute(alice, bob);
      final aliceCarol = await SafetyNumber.compute(alice, carol);

      expect(aliceBob, isNot(aliceCarol));
    });

    test('is formatted as 8 space-separated groups of 5 digits', () async {
      final number = await SafetyNumber.compute(alice, bob);

      final groups = number.split(' ');
      expect(groups, hasLength(8));
      for (final group in groups) {
        expect(group, matches(RegExp(r'^\d{5}$')));
      }
    });
  });
}
