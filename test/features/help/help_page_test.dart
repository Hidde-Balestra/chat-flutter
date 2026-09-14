import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/features/help/help_page.dart';

import '../../test_helpers/localized_test_app.dart';

void main() {
  group('HelpPage', () {
    testWidgets('lists every help topic and expands to show its explanation',
        (tester) async {
      await tester.pumpWidget(localizedTestApp(const HelpPage()));
      await tester.pumpAndSettle();

      expect(find.text('Hoe werkt de app?'), findsOneWidget);
      expect(find.text('Wat is PrivacyChat?'), findsOneWidget);
      expect(find.text('Jouw Account ID'), findsOneWidget);

      // The last topic is off-screen until scrolled to.
      await tester.scrollUntilVisible(
        find.text('Belangrijk: app verwijderd of nieuwe telefoon?'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Belangrijk: app verwijderd of nieuwe telefoon?'),
          findsOneWidget);

      // The first topic starts expanded, showing its body text.
      expect(
        find.textContaining('niemand — ook wij niet — kan meelezen'),
        findsOneWidget,
      );

      // Expanding another topic reveals its explanation too.
      await tester.tap(find.text('Jouw Account ID'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Dit is een soort adres'),
        findsOneWidget,
      );
    });
  });
}
