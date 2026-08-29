import 'package:medipulse/shared/models/entities.dart';

class AdherenceCalculator {
  AdherenceSummary summarize(Iterable<MedicationDose> doses) {
    var taken = 0, missed = 0, skipped = 0, pending = 0, snoozed = 0;
    for (final dose in doses) {
      switch (dose.status) {
        case DoseStatus.taken:
          taken++;
        case DoseStatus.missed:
          missed++;
        case DoseStatus.skipped:
          skipped++;
        case DoseStatus.pending:
          pending++;
        case DoseStatus.snoozed:
          snoozed++;
      }
    }
    return AdherenceSummary(
      scheduled: taken + missed + skipped + pending + snoozed,
      taken: taken,
      missed: missed,
      skipped: skipped,
      pending: pending,
      snoozed: snoozed,
    );
  }
}
