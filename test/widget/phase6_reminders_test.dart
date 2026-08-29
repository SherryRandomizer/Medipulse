import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/core/notifications/pending_dose_action.dart';
import 'package:medipulse/features/medications/presentation/add_medication_screen.dart';

void main() {
  test('pending dose action codec round-trips and rejects junk', () {
    final encoded = PendingDoseActionCodec.encode(actionId: 'taken', doseId: 'dose-1');
    final decoded = PendingDoseActionCodec.decode(encoded);
    expect(decoded?.actionId, 'taken');
    expect(decoded?.doseId, 'dose-1');
    expect(PendingDoseActionCodec.decode(null), isNull);
    expect(PendingDoseActionCodec.decode('taken'), isNull);
    expect(PendingDoseActionCodec.decode('|only'), isNull);
  });

  testWidgets('add medication wizard starts with manual scan and catalog choices', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddMedicationScreen()),
      ),
    );
    expect(find.text('Enter manually'), findsOneWidget);
    expect(find.text('Scan prescription'), findsOneWidget);
    expect(find.text('Licensed catalog'), findsOneWidget);
  });
}
