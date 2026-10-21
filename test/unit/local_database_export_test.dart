import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/core/storage/local_database.dart';
import 'package:medipulse/shared/models/entities.dart';

class _ExportTestDatabase extends LocalDatabase {
  _ExportTestDatabase({
    required this.profile,
    required this.medications,
    required this.doses,
  });

  final UserProfile profile;
  final List<Medication> medications;
  final List<MedicationDose> doses;
  bool? includeArchivedRequested;
  Object? medicationFailure;

  @override
  Future<UserProfile?> userById(String id) async {
    return id == profile.id ? profile : null;
  }

  @override
  Future<List<Medication>> medicationsForUser(
    String userId, {
    bool includeArchived = false,
  }) async {
    includeArchivedRequested = includeArchived;
    if (medicationFailure != null) {
      throw medicationFailure!;
    }
    return userId == profile.id ? medications : [];
  }

  @override
  Future<List<MedicationDose>> dosesForUser(
    String userId, {
    DateTime? from,
    DateTime? to,
  }) async {
    return userId == profile.id ? doses : [];
  }
}

void main() {
  test(
    'exports the expected JSON shape and includes archived medications',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      final user = UserProfile(
        id: 'test-user',
        email: 'sample@example.test',
        displayName: 'Sample Person',
        timeZone: 'UTC',
        preferredLanguage: 'en',
        emailVerified: false,
        isGuest: true,
        createdAt: now,
        updatedAt: now,
      );

      const medicationId = 'test-medication';
      final medication = Medication(
        id: medicationId,
        userId: user.id,
        name: 'Sample medicine',
        form: MedicationForm.tablet,
        doseAmount: 1,
        doseUnit: 'tablet',
        schedule: MedicationSchedule(
          id: 'test-schedule',
          medicationId: medicationId,
          frequency: FrequencyType.onceDaily,
          timesMinutes: [480],
          createdAt: now,
          updatedAt: now,
        ),
        startDate: now,
        timeZone: 'UTC',
        status: MedicationStatus.archived,
        createdAt: now,
        updatedAt: now,
      );
      final dose = MedicationDose(
        id: 'test-dose',
        medicationId: medicationId,
        userId: user.id,
        scheduledAt: now,
        remindAt: now,
        status: DoseStatus.taken,
        snoozeCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final database = _ExportTestDatabase(
        profile: user,
        medications: [medication],
        doses: [dose],
      );

      final json = await database.exportUserJson(user.id);
      final export = jsonDecode(json) as Map<String, dynamic>;

      expect(DateTime.tryParse(export['exportedAt'] as String), isNotNull);
      expect(export['disclaimer'], isA<String>());
      expect(export['user'], containsPair('id', user.id));
      expect(export['user'], containsPair('email', user.email));

      final exportedMedications = export['medications'] as List<dynamic>;
      expect(exportedMedications, hasLength(1));
      expect(exportedMedications.single, containsPair('name', medication.name));
      expect(exportedMedications.single, containsPair('status', 'archived'));

      final exportedDoses = export['doses'] as List<dynamic>;
      expect(exportedDoses, hasLength(1));
      expect(exportedDoses.single, containsPair('id', dose.id));
      expect(exportedDoses.single, containsPair('status', 'taken'));

      expect(database.includeArchivedRequested, isTrue);
    },
  );
  test('propagates medication loading failures', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final user = UserProfile(
      id: 'test-user',
      email: 'sample@example.test',
      displayName: 'Sample Person',
      timeZone: 'UTC',
      preferredLanguage: 'en',
      emailVerified: false,
      isGuest: true,
      createdAt: now,
      updatedAt: now,
    );
    final database = _ExportTestDatabase(
      profile: user,
      medications: [],
      doses: [],
    )..medicationFailure = StateError('test failure');

    await expectLater(
      database.exportUserJson(user.id),
      throwsA(isA<StateError>()),
    );
  });
}
