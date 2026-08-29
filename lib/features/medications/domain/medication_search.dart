import 'package:medipulse/shared/models/entities.dart';

class MedicationSearch {
  static List<Medication> apply(
    Iterable<Medication> medications, {
    required String query,
    bool includeArchivedWhenEmpty = false,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      if (includeArchivedWhenEmpty) return medications.toList();
      return [
        for (final med in medications)
          if (med.status != MedicationStatus.archived) med,
      ];
    }
    return [
      for (final med in medications)
        if (_matches(med, q)) med,
    ];
  }

  static bool _matches(Medication med, String q) {
    return med.name.toLowerCase().contains(q) ||
        (med.genericName ?? '').toLowerCase().contains(q) ||
        (med.doctorName ?? '').toLowerCase().contains(q);
  }
}
