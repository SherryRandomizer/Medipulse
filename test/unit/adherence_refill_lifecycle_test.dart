import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/features/adherence/domain/adherence_calculator.dart';
import 'package:medipulse/features/adherence/domain/refill_calculator.dart';
import 'package:medipulse/features/reminders/domain/dose_lifecycle.dart';
import 'package:medipulse/shared/models/entities.dart';

MedicationDose _dose(DoseStatus status) {
  final now = DateTime.utc(2026, 6, 1, 12);
  return MedicationDose(
    id: 'd1',
    medicationId: 'm1',
    userId: 'u1',
    scheduledAt: now,
    remindAt: now,
    status: status,
    snoozeCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Medication _med({double amount = 1, double? quantity, double? threshold}) {
  final now = DateTime.utc(2026, 6, 1);
  return Medication(
    id: 'm1',
    userId: 'u1',
    name: 'Example',
    form: MedicationForm.tablet,
    doseAmount: amount,
    doseUnit: 'tablet',
    startDate: now,
    timeZone: 'UTC',
    status: MedicationStatus.active,
    createdAt: now,
    updatedAt: now,
    quantity: quantity,
    refillThreshold: threshold,
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

void main() {
  test('adherence is taken divided by completed doses', () {
    final summary = AdherenceCalculator().summarize([
      _dose(DoseStatus.taken),
      _dose(DoseStatus.taken),
      _dose(DoseStatus.taken),
      _dose(DoseStatus.missed),
      _dose(DoseStatus.skipped),
      _dose(DoseStatus.pending),
    ]);
    expect(summary.taken, 3);
    expect(summary.missed, 1);
    expect(summary.skipped, 1);
    expect(summary.completed, 5);
    expect(summary.percentage, 60);
  });

  test('refill estimate floors remaining doses and warns at threshold', () {
    final calc = RefillCalculator();
    final ok = calc.estimate(_med(quantity: 10, threshold: 4));
    expect(ok.remainingDoses, 10);
    expect(ok.warning, isFalse);
    final warn = calc.estimate(_med(quantity: 4, threshold: 4));
    expect(warn.warning, isTrue);
  });

  test('overdue pending doses become missed after grace', () {
    final scheduled = DateTime.utc(2026, 6, 1, 8);
    final dose = MedicationDose(
      id: 'd1',
      medicationId: 'm1',
      userId: 'u1',
      scheduledAt: scheduled,
      remindAt: scheduled,
      status: DoseStatus.pending,
      snoozeCount: 0,
      createdAt: scheduled,
      updatedAt: scheduled,
    );
    final updated = withClock(Clock.fixed(scheduled.add(const Duration(hours: 2))), () {
      return DoseLifecycle().markMissedIfOverdue(dose);
    });
    expect(updated.status, DoseStatus.missed);
  });

  test('snooze moves remindAt forward', () {
    final now = DateTime.utc(2026, 6, 1, 8);
    final dose = MedicationDose(
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
    final updated = withClock(Clock.fixed(now), () {
      return DoseLifecycle().snooze(dose, const Duration(minutes: 10));
    });
    expect(updated.status, DoseStatus.snoozed);
    expect(updated.remindAt, now.add(const Duration(minutes: 10)));
  });
}
