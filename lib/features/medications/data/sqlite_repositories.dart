import 'package:clock/clock.dart';
import 'package:medipulse/core/storage/local_database.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class SqliteMedicationRepository implements MedicationRepository {
  SqliteMedicationRepository(this._db);
  final LocalDatabase _db;

  @override
  Future<List<Medication>> list(String userId, {bool includeArchived = false}) =>
      _db.medicationsForUser(userId, includeArchived: includeArchived);

  @override
  Future<Medication?> getById(String id) => _db.medicationById(id);

  @override
  Future<void> save(Medication medication) =>
      _db.upsertMedication(medication.copyWith(updatedAt: clock.now().toUtc()));

  @override
  Future<int> activeCount(String userId) => _db.activeMedicationCount(userId);
}

class SqliteDoseRepository implements DoseRepository {
  SqliteDoseRepository(this._db);
  final LocalDatabase _db;

  @override
  Future<void> replacePending(String medicationId, List<MedicationDose> doses) =>
      _db.replacePendingDoses(medicationId, doses);

  @override
  Future<void> save(MedicationDose dose) => _db.upsertDose(dose);

  @override
  Future<MedicationDose?> getById(String id) => _db.doseById(id);

  @override
  Future<List<MedicationDose>> forUser(String userId, {DateTime? from, DateTime? to}) =>
      _db.dosesForUser(userId, from: from, to: to);

  @override
  Future<List<MedicationDose>> pending(String userId) => _db.pendingDoses(userId);
}
