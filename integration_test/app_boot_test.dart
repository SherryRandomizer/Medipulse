import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medipulse/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to onboarding or home without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MediPulseApp()),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MediPulseApp), findsOneWidget);
  });
}
