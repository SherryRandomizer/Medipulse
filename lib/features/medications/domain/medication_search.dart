import 'package:medipulse/shared/models/entities.dart';

class MedicationSearch {
  static List<Medication> apply(
    Iterable<Medication> medications, {
    required String query,
    bool includeArchived = false,
  }) {
    final q = query.trim().toLowerCase();
    return [
      for (final med in medications)
        if ((includeArchived || med.status != MedicationStatus.archived) &&
            (q.isEmpty || _matches(med, q)))
          med,
    ];
  }

  static bool _matches(Medication med, String q) {
    return med.name.toLowerCase().contains(q) ||
        (med.genericName ?? '').toLowerCase().contains(q) ||
        (med.doctorName ?? '').toLowerCase().contains(q);
  }
}
