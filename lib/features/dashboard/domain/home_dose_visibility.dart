import 'package:medipulse/features/medications/domain/scheduling_engine.dart';
import 'package:medipulse/shared/models/entities.dart';

/// Home-only: hide historical doses whose time is no longer on the schedule.
class HomeDoseVisibility {
  const HomeDoseVisibility(this.engine);

  final SchedulingEngine engine;

  bool isVisible({required Medication medication, required MedicationDose dose}) {
    if (dose.status == DoseStatus.pending || dose.status == DoseStatus.snoozed) {
      return true;
    }
    return engine.matchesCurrentSchedule(
      medication: medication,
      scheduledAt: dose.scheduledAt,
      location: engine.locationFor(medication.timeZone),
    );
  }

  List<MedicationDose> visibleDoses({
    required Iterable<MedicationDose> doses,
    required Map<String, Medication> medications,
  }) {
    return [
      for (final dose in doses)
        if (medications[dose.medicationId] != null &&
            isVisible(medication: medications[dose.medicationId]!, dose: dose))
          dose,
    ];
  }
}
