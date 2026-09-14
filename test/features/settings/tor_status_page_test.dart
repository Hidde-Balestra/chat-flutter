import 'package:flutter_test/flutter_test.dart';
import 'package:privacychat/core/network/tor_service.dart';
import 'package:privacychat/features/settings/tor_status_page.dart';

import '../../test_helpers/fake_tor_service.dart';
import '../../test_helpers/localized_test_app.dart';

void main() {
  group('TorStatusPage', () {
    testWidgets('shows connecting status without fetching circuits yet',
        (tester) async {
      final torService = FakeTorService()..setProgress(42);

      await tester
          .pumpWidget(localizedTestApp(TorStatusPage(torService: torService)));
      await tester.pump();

      expect(find.textContaining('42%'), findsOneWidget);
    });

    testWidgets('fetches and shows circuit hops once connected',
        (tester) async {
      final torService = FakeTorService()
        ..circuits = [
          const TorCircuit(id: '9', hops: [
            TorRelay(
                fingerprint: 'AAAA',
                nickname: 'GuardNode',
                ip: '1.2.3.4',
                orPort: 443),
            TorRelay(
                fingerprint: 'BBBB',
                nickname: 'MiddleNode',
                ip: '5.6.7.8',
                orPort: 443),
            TorRelay(
                fingerprint: 'CCCC',
                nickname: 'ExitNode',
                ip: '9.9.9.9',
                orPort: 443),
          ]),
        ];
      torService.setConnected();

      await tester
          .pumpWidget(localizedTestApp(TorStatusPage(torService: torService)));
      await tester.pumpAndSettle();

      expect(find.textContaining('GuardNode'), findsOneWidget);
      expect(find.textContaining('MiddleNode'), findsOneWidget);
      expect(find.textContaining('ExitNode'), findsOneWidget);
      expect(find.textContaining('1.2.3.4'), findsOneWidget);
    });

    testWidgets('shows an error if fetching circuits fails', (tester) async {
      final torService = FakeTorService()..circuitsError = Exception('boom');
      torService.setConnected();

      await tester
          .pumpWidget(localizedTestApp(TorStatusPage(torService: torService)));
      await tester.pumpAndSettle();

      expect(find.textContaining('boom'), findsOneWidget);
    });
  });
}
