import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/features/medications/domain/medication_search.dart';
import 'package:medipulse/shared/models/entities.dart';

Medication _med(String id, {String? generic, String? doctor, MedicationStatus status = MedicationStatus.active}) {
  final now = DateTime.utc(2026, 6, 1);
  return Medication(
    id: id,
    userId: 'u1',
    name: id,
    genericName: generic,
    doctorName: doctor,
    form: MedicationForm.tablet,
    doseAmount: 1,
    doseUnit: 'tablet',
    startDate: now,
    timeZone: 'UTC',
    status: status,
    createdAt: now,
    updatedAt: now,
    schedule: MedicationSchedule(
      id: 's$id',
      medicationId: id,
      frequency: FrequencyType.onceDaily,
      timesMinutes: const [480],
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  final meds = [
    _med('Metformin', generic: 'metformin hcl', doctor: 'Dr Lee'),
    _med('OldRx', status: MedicationStatus.archived, doctor: 'Dr Lee'),
  ];

  test('empty query hides archived unless requested', () {
    expect(MedicationSearch.apply(meds, query: '').map((m) => m.name), ['Metformin']);
    expect(
      MedicationSearch.apply(meds, query: '', includeArchivedWhenEmpty: true).map((m) => m.name),
      ['Metformin', 'OldRx'],
    );
  });

  test('query matches name generic or doctor including archived', () {
    expect(MedicationSearch.apply(meds, query: 'metformin').single.name, 'Metformin');
    expect(MedicationSearch.apply(meds, query: 'lee').map((m) => m.name), ['Metformin', 'OldRx']);
  });
}
