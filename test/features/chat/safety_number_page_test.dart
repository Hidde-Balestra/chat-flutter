import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/crypto/safety_number.dart';
import 'package:privacychat/features/chat/safety_number_page.dart';

import '../../test_helpers/localized_test_app.dart';

void main() {
  group('SafetyNumberPage', () {
    final alice = '05${'11' * 32}';
    final bob = '05${'22' * 32}';

    testWidgets('shows the computed safety number', (tester) async {
      final expected = await SafetyNumber.compute(alice, bob);

      await tester.pumpWidget(localizedTestApp(SafetyNumberPage(
        myAccountId: alice,
        contactAccountId: bob,
        contactName: 'Bob',
      )));
      await tester.pump();
      await tester.pump();

      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('shows the same number no matter who is "me"', (tester) async {
      final expected = await SafetyNumber.compute(alice, bob);

      await tester.pumpWidget(localizedTestApp(SafetyNumberPage(
        myAccountId: bob,
        contactAccountId: alice,
        contactName: 'Alice',
      )));
      await tester.pump();
      await tester.pump();

      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('mentions the contact name in the explanation', (tester) async {
      await tester.pumpWidget(localizedTestApp(SafetyNumberPage(
        myAccountId: alice,
        contactAccountId: bob,
        contactName: 'Bob',
      )));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Bob'), findsOneWidget);
    });
  });
}
