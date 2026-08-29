import 'package:clock/clock.dart';
import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/shared/models/entities.dart';

class DoseLifecycle {
  MedicationDose markTaken(MedicationDose dose) {
    final now = clock.now().toUtc();
    return dose.copyWith(status: DoseStatus.taken, actedAt: now, updatedAt: now);
  }

  MedicationDose markSkipped(MedicationDose dose) {
    final now = clock.now().toUtc();
    return dose.copyWith(status: DoseStatus.skipped, actedAt: now, updatedAt: now);
  }

  MedicationDose snooze(MedicationDose dose, Duration delay) {
    final now = clock.now().toUtc();
    return dose.copyWith(
      status: DoseStatus.snoozed,
      remindAt: now.add(delay),
      snoozeCount: dose.snoozeCount + 1,
      actedAt: now,
      updatedAt: now,
    );
  }

  MedicationDose markMissedIfOverdue(
    MedicationDose dose, {
    Duration grace = const Duration(minutes: AppConstants.missedGraceMinutes),
  }) {
    if (dose.status != DoseStatus.pending && dose.status != DoseStatus.snoozed) {
      return dose;
    }
    final deadline = dose.remindAt.add(grace);
    if (clock.now().toUtc().isAfter(deadline)) {
      return dose.copyWith(
        status: DoseStatus.missed,
        actedAt: clock.now().toUtc(),
        updatedAt: clock.now().toUtc(),
      );
    }
    return dose;
  }
}
