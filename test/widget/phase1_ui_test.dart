import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/widgets/app_components.dart';
import 'package:medipulse/shared/widgets/medication_widgets.dart';

Medication _med() {
  final now = DateTime.utc(2026, 6, 1);
  return Medication(
    id: 'm1',
    userId: 'u1',
    name: 'Example Medicine',
    form: MedicationForm.tablet,
    doseAmount: 1,
    doseUnit: 'tablet',
    foodInstruction: 'After breakfast',
    startDate: now,
    timeZone: 'UTC',
    status: MedicationStatus.active,
    createdAt: now,
    updatedAt: now,
    schedule: MedicationSchedule(
      id: 's1',
      medicationId: 'm1',
      frequency: FrequencyType.onceDaily,
      timesMinutes: const [480],
      createdAt: now,
      updatedAt: now,
    ),
  );
}

MedicationDose _pending() {
  final now = DateTime.utc(2026, 6, 1, 8);
  return MedicationDose(
    id: 'd1',
    medicationId: 'm1',
    userId: 'u1',
    scheduledAt: now,
    remindAt: now,
    status: DoseStatus.pending,
    snoozeCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('dashboard empty state explains the next action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'No doses scheduled today',
            message: 'Add a medication to start receiving reminders.',
            actionLabel: 'Add medication',
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.text('Add medication'), findsOneWidget);
    expect(find.text('No doses scheduled today'), findsOneWidget);
  });

  testWidgets('reminder card exposes taken snooze and skip', (tester) async {
    var taken = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReminderCard(
            item: TimelineItem(dose: _pending(), medication: _med()),
            onTaken: () => taken = true,
            onSnooze: () {},
            onSkip: () {},
          ),
        ),
      ),
    );
    expect(find.text('Example Medicine'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    await tester.tap(find.text('Taken'));
    expect(taken, isTrue);
  });

  testWidgets('medication details show name and dose', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedicationCard(medication: _med(), onTap: () {}),
        ),
      ),
    );
    expect(find.text('Example Medicine'), findsOneWidget);
    expect(find.textContaining('Once daily'), findsOneWidget);
  });
}
