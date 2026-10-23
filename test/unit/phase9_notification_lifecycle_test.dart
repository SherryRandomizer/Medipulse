import 'package:clock/clock.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/core/logging/app_logger.dart';
import 'package:medipulse/core/notifications/local_notification_service.dart';
import 'package:medipulse/core/notifications/reminder_alarm_registry.dart';
import 'package:medipulse/features/medications/domain/medication_coordinator.dart';
import 'package:medipulse/features/medications/domain/scheduling_engine.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class _MemoryMedications implements MedicationRepository {
  final items = <String, Medication>{};

  @override
  Future<int> activeCount(String userId) async {
    return items.values
        .where(
          (m) =>
              m.userId == userId &&
              m.status == MedicationStatus.active &&
              m.deletedAt == null,
        )
        .length;
  }

  @override
  Future<Medication?> getById(String id) async => items[id];

  @override
  Future<List<Medication>> list(
    String userId, {
    bool includeArchived = false,
  }) async {
    return items.values.where((m) {
      if (m.userId != userId || m.deletedAt != null) return false;
      if (!includeArchived && m.isArchived) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> save(Medication medication) async {
    items[medication.id] = medication;
  }
}

class _MemoryDoses implements DoseRepository {
  final items = <MedicationDose>[];

  @override
  Future<List<MedicationDose>> forUser(
    String userId, {
    DateTime? from,
    DateTime? to,
  }) async {
    return items.where((d) {
      if (d.userId != userId) return false;
      if (from != null && d.scheduledAt.isBefore(from)) return false;
      if (to != null && !d.scheduledAt.isBefore(to)) return false;
      return true;
    }).toList();
  }

  @override
  Future<MedicationDose?> getById(String id) async {
    for (final dose in items) {
      if (dose.id == id) return dose;
    }
    return null;
  }

  @override
  Future<List<MedicationDose>> pending(String userId) async {
    return items
        .where(
          (d) =>
              d.userId == userId &&
              (d.status == DoseStatus.pending ||
                  d.status == DoseStatus.snoozed),
        )
        .toList();
  }

  @override
  Future<void> replacePending(
    String medicationId,
    List<MedicationDose> doses,
  ) async {
    items.removeWhere(
      (d) =>
          d.medicationId == medicationId &&
          (d.status == DoseStatus.pending || d.status == DoseStatus.snoozed),
    );
    items.addAll(doses);
  }

  @override
  Future<List<MedicationDose>> insertMissing(List<MedicationDose> doses) async {
    final inserted = <MedicationDose>[];
    for (final dose in doses) {
      final exists = items.any(
        (d) =>
            d.id == dose.id ||
            (d.medicationId == dose.medicationId &&
                d.scheduledAt.isAtSameMomentAs(dose.scheduledAt)),
      );
      if (exists) continue;
      items.add(dose);
      inserted.add(dose);
    }
    return inserted;
  }

  @override
  Future<void> save(MedicationDose dose) async {
    items.removeWhere((d) => d.id == dose.id);
    items.add(dose);
  }
}

class _PremiumSubscriptions implements SubscriptionService {
  @override
  Future<void> applyEntitlement(Subscription subscription) async {}

  @override
  Future<Subscription> current(String userId) async {
    return Subscription(
      userId: userId,
      tier: SubscriptionTier.premium,
      updatedAt: clock.now().toUtc(),
    );
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Stream<Subscription> watch(String userId) async* {
    yield await current(userId);
  }
}

class _SilentAnalytics implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object>? params}) async {}
}

/// In-memory stand-in for OS reminder alarms.
class RecordingNotifications implements NotificationService {
  final scheduled = <String, String>{};

  /// Models AlarmManager entries keyed by the legacy `doseId.hashCode` integer.
  final legacyScheduledPayloads = <int, String>{};
  final cancelledMedicationIds = <String>[];
  final cancelledPluginIds = <int>[];
  int scheduleCalls = 0;

  Set<String> doseIdsFor(String medicationId) => {
    for (final entry in scheduled.entries)
      if (entry.value == medicationId) entry.key,
  };

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> cancelDose(String doseId) async {
    scheduled.remove(doseId);
    cancelledPluginIds.add(LocalNotificationService.legacyAlarmId(doseId));
    legacyScheduledPayloads.remove(
      LocalNotificationService.legacyAlarmId(doseId),
    );
  }

  @override
  Future<void> cancelMedication(
    String medicationId, {
    Set<String> priorDoseIds = const {},
  }) async {
    cancelledMedicationIds.add(medicationId);
    for (final doseId in priorDoseIds) {
      scheduled.remove(doseId);
      final legacyId = LocalNotificationService.legacyAlarmId(doseId);
      cancelledPluginIds.add(legacyId);
      legacyScheduledPayloads.remove(legacyId);
    }
    scheduled.removeWhere((_, medId) => medId == medicationId);
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> openSystemNotificationSettings() async {}

  @override
  Future<bool> requestExactAlarms() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDoseReminder({
    required MedicationDose dose,
    required Medication medication,
  }) async {
    scheduleCalls += 1;
    scheduled[dose.id] = medication.id;
  }

  @override
  Future<void> showImmediate({
    required String title,
    required String body,
  }) async {}

  @override
  Future<List<String>> trackedMedicationIds() async =>
      scheduled.values.toSet().toList();

  @override
  Future<void> cancelAllReminders() async {
    scheduled.clear();
  }
}

Medication _med({
  required String id,
  FrequencyType frequency = FrequencyType.onceDaily,
  List<int> times = const [8 * 60],
  MedicationStatus status = MedicationStatus.active,
  DateTime? deletedAt,
}) {
  final start = DateTime.utc(2026, 6, 1);
  return Medication(
    id: id,
    userId: 'user-1',
    name: 'Medicine $id',
    form: MedicationForm.tablet,
    doseAmount: 1,
    doseUnit: 'tablet',
    startDate: start,
    timeZone: 'UTC',
    status: status,
    createdAt: start,
    updatedAt: start,
    deletedAt: deletedAt,
    schedule: MedicationSchedule(
      id: 'sched-$id',
      medicationId: id,
      frequency: frequency,
      timesMinutes: times,
      createdAt: start,
      updatedAt: start,
    ),
  );
}

void main() {
  tzdata.initializeTimeZones();

  late _MemoryMedications medications;
  late _MemoryDoses doses;
  late RecordingNotifications notifications;
  late MedicationCoordinator coordinator;
  final now = DateTime.utc(2026, 6, 1, 7);

  setUp(() {
    medications = _MemoryMedications();
    doses = _MemoryDoses();
    notifications = RecordingNotifications();
    coordinator = MedicationCoordinator(
      medications: medications,
      doses: doses,
      notifications: notifications,
      subscriptions: _PremiumSubscriptions(),
      analytics: _SilentAnalytics(),
      engine: SchedulingEngine(horizonDays: 2),
    );
  });

  Future<T> atSeven<T>(Future<T> Function() run) {
    return withClock(Clock.fixed(now), run);
  }

  test(
    'edit medication cancels previous reminders and keeps one alarm per dose',
    () async {
      await atSeven(() async {
        await coordinator.saveMedication(_med(id: 'alpha'));
        await coordinator.saveMedication(_med(id: 'beta'));
        final firstIds = notifications.doseIdsFor('alpha');
        final betaDoseIds = notifications.doseIdsFor('beta');
        final betaDoseId = betaDoseIds.first;
        expect(firstIds, isNotEmpty);
        expect(notifications.cancelledMedicationIds, contains('alpha'));
        final alphaLegacyId = LocalNotificationService.legacyAlarmId(
          firstIds.first,
        );
        final betaLegacyId = LocalNotificationService.legacyAlarmId(betaDoseId);
        notifications.legacyScheduledPayloads[alphaLegacyId] = firstIds.first;
        notifications.legacyScheduledPayloads[betaLegacyId] = betaDoseId;

        await coordinator.saveMedication(
          _med(id: 'alpha', times: const [9 * 60]),
        );
        expect(
          notifications.cancelledMedicationIds
              .where((id) => id == 'alpha')
              .length,
          greaterThanOrEqualTo(2),
        );
        expect(notifications.cancelledPluginIds, contains(alphaLegacyId));
        expect(notifications.cancelledPluginIds, isNot(contains(betaLegacyId)));
        for (final oldId in firstIds) {
          expect(notifications.scheduled.containsKey(oldId), isFalse);
        }
        expect(
          notifications.legacyScheduledPayloads.containsKey(alphaLegacyId),
          isFalse,
        );
        expect(notifications.legacyScheduledPayloads[betaLegacyId], betaDoseId);
        expect(notifications.doseIdsFor('beta'), betaDoseIds);
        expect(notifications.doseIdsFor('alpha').length, firstIds.length);
        expect(
          notifications.doseIdsFor('alpha').intersection(firstIds),
          isEmpty,
        );
      });
    },
  );

  test(
    'reschedule leaves exactly one reminder for each expected pending dose',
    () async {
      await atSeven(() async {
        await coordinator.saveMedication(_med(id: 'alpha'));
        final pending = doses.items
            .where((d) => d.medicationId == 'alpha')
            .toList();
        expect(
          notifications.doseIdsFor('alpha'),
          pending.map((d) => d.id).toSet(),
        );
        expect(notifications.doseIdsFor('alpha').length, pending.length);
      });
    },
  );

  test('pause cancels pending reminders for that medication only', () async {
    await atSeven(() async {
      await coordinator.saveMedication(_med(id: 'alpha'));
      await coordinator.saveMedication(
        _med(id: 'beta', times: const [20 * 60]),
      );
      final betaIds = notifications.doseIdsFor('beta');
      expect(betaIds, isNotEmpty);

      await coordinator.saveMedication(
        _med(id: 'alpha', status: MedicationStatus.paused),
      );
      expect(notifications.doseIdsFor('alpha'), isEmpty);
      expect(notifications.doseIdsFor('beta'), betaIds);
    });
  });

  test('archive cancels pending reminders for that medication only', () async {
    await atSeven(() async {
      await coordinator.saveMedication(_med(id: 'alpha'));
      await coordinator.saveMedication(_med(id: 'beta'));
      final betaIds = notifications.doseIdsFor('beta');

      await coordinator.saveMedication(
        _med(id: 'alpha', status: MedicationStatus.archived),
      );
      expect(notifications.doseIdsFor('alpha'), isEmpty);
      expect(notifications.doseIdsFor('beta'), betaIds);
    });
  });

  test('delete cancels pending reminders for that medication only', () async {
    await atSeven(() async {
      final alpha = _med(id: 'alpha');
      await coordinator.saveMedication(alpha);
      await coordinator.saveMedication(_med(id: 'beta'));
      final betaIds = notifications.doseIdsFor('beta');

      await coordinator.deleteMedication(alpha);
      expect(notifications.doseIdsFor('alpha'), isEmpty);
      expect(notifications.doseIdsFor('beta'), betaIds);
      expect(
        doses.items.where(
          (d) => d.medicationId == 'alpha' && d.status == DoseStatus.pending,
        ),
        isEmpty,
      );
    });
  });

  test(
    'another medication reminders remain untouched across save of a neighbor',
    () async {
      await atSeven(() async {
        await coordinator.saveMedication(_med(id: 'alpha'));
        await coordinator.saveMedication(_med(id: 'beta'));
        final alphaIds = notifications.doseIdsFor('alpha');
        final alphaCancels = notifications.cancelledMedicationIds
            .where((id) => id == 'alpha')
            .length;
        await coordinator.saveMedication(
          _med(id: 'beta', times: const [21 * 60]),
        );
        expect(notifications.doseIdsFor('alpha'), alphaIds);
        expect(
          notifications.cancelledMedicationIds
              .where((id) => id == 'alpha')
              .length,
          alphaCancels,
        );
      });
    },
  );

  test(
    'edit cancels the legacy hashCode alarm id before scheduling replacements',
    () async {
      await atSeven(() async {
        await coordinator.saveMedication(_med(id: 'alpha'));
        await coordinator.saveMedication(_med(id: 'beta'));
        final alphaIds = notifications.doseIdsFor('alpha').toList();
        final betaIds = notifications.doseIdsFor('beta');
        final alphaLegacyIds = {
          for (final id in alphaIds) LocalNotificationService.legacyAlarmId(id),
        };
        final betaLegacyIds = {
          for (final id in betaIds) LocalNotificationService.legacyAlarmId(id),
        };
        for (final id in alphaIds) {
          notifications
                  .legacyScheduledPayloads[LocalNotificationService.legacyAlarmId(
                id,
              )] =
              id;
        }
        for (final id in betaIds) {
          notifications
                  .legacyScheduledPayloads[LocalNotificationService.legacyAlarmId(
                id,
              )] =
              id;
        }

        await coordinator.saveMedication(
          _med(id: 'alpha', times: const [12 * 60 + 45]),
        );

        for (final legacyId in alphaLegacyIds) {
          expect(notifications.cancelledPluginIds, contains(legacyId));
          expect(
            notifications.legacyScheduledPayloads.containsKey(legacyId),
            isFalse,
          );
        }
        for (final legacyId in betaLegacyIds) {
          expect(notifications.cancelledPluginIds, isNot(contains(legacyId)));
          expect(
            notifications.legacyScheduledPayloads.containsKey(legacyId),
            isTrue,
          );
        }
        expect(notifications.doseIdsFor('beta'), betaIds);
        expect(notifications.doseIdsFor('alpha').length, alphaIds.length);
      });
    },
  );

  test('repeated save does not duplicate reminders', () async {
    await atSeven(() async {
      final med = _med(id: 'alpha');
      await coordinator.saveMedication(med);
      final firstCount = notifications.doseIdsFor('alpha').length;
      expect(firstCount, greaterThan(0));
      await coordinator.saveMedication(med);
      await coordinator.saveMedication(med);
      expect(notifications.doseIdsFor('alpha').length, firstCount);
      expect(
        notifications.scheduled.values.where((id) => id == 'alpha').length,
        firstCount,
      );
    });
  });

  test(
    'extendSchedules adds missing future doses and leaves existing state untouched',
    () async {
      await atSeven(() async {
        await coordinator.saveMedication(
          _med(id: 'alpha', times: const [8 * 60, 20 * 60]),
        );
        await coordinator.saveMedication(_med(id: 'beta'));

        List<MedicationDose> dosesFor(String medicationId) =>
            doses.items.where((d) => d.medicationId == medicationId).toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        // Horizon is 2 days from the fixed clock, so alpha starts with 4 doses.
        final full = dosesFor('alpha');
        expect(full, hasLength(4));
        final kept = full.take(2).toList();
        final missing = full.skip(2).toList();

        // Simulate a gap: the later doses (and their reminders) are absent.
        for (final dose in missing) {
          doses.items.removeWhere((d) => d.id == dose.id);
          notifications.scheduled.remove(dose.id);
        }
        expect(dosesFor('alpha'), hasLength(2));

        final keptTimes = {for (final d in kept) d.id: d.scheduledAt};
        final betaTimes = {
          for (final d in dosesFor('beta')) d.id: d.scheduledAt,
        };
        final betaReminders = notifications.doseIdsFor('beta');
        final betaCancels = notifications.cancelledMedicationIds
            .where((id) => id == 'beta')
            .length;
        final callsBefore = notifications.scheduleCalls;

        await coordinator.extendSchedules('user-1');

        final after = dosesFor('alpha');
        final added = after.where((d) => !keptTimes.containsKey(d.id)).toList();

        // 1. Missing future doses were added.
        expect(
          added.map((d) => d.scheduledAt).toList(),
          missing.map((d) => d.scheduledAt).toList(),
        );

        // 2. Existing dose IDs and scheduled timestamps are preserved.
        for (final entry in keptTimes.entries) {
          final match = after.where((d) => d.id == entry.key);
          expect(match, hasLength(1));
          expect(match.single.scheduledAt, entry.value);
        }

        // 3. No duplicate scheduled timestamps for the medication.
        final stamps = after.map((d) => d.scheduledAt).toList();
        expect(stamps, hasLength(4));
        expect(stamps.toSet(), hasLength(stamps.length));

        // 4. Another medication is unchanged.
        expect({
          for (final d in dosesFor('beta')) d.id: d.scheduledAt,
        }, betaTimes);
        expect(notifications.doseIdsFor('beta'), betaReminders);
        expect(
          notifications.cancelledMedicationIds
              .where((id) => id == 'beta')
              .length,
          betaCancels,
        );

        // 5. Only the newly inserted doses were scheduled; all have reminders.
        expect(notifications.scheduleCalls - callsBefore, added.length);
        expect(
          notifications.doseIdsFor('alpha'),
          after.map((d) => d.id).toSet(),
        );
      });
    },
  );

  test(
    'app-start reschedule drops leftover alarms then restores one per pending dose',
    () async {
      await atSeven(() async {
        await coordinator.saveMedication(_med(id: 'alpha'));
        notifications.scheduled['legacy-hash-id'] = 'alpha';
        await coordinator.rescheduleNotifications('user-1');
        expect(notifications.scheduled.containsKey('legacy-hash-id'), isFalse);
        final pending = doses.items
            .where(
              (d) =>
                  d.medicationId == 'alpha' &&
                  (d.status == DoseStatus.pending ||
                      d.status == DoseStatus.snoozed),
            )
            .map((d) => d.id)
            .toSet();
        expect(notifications.doseIdsFor('alpha'), pending);
      });
    },
  );

  test('taken snooze and skip still cancel the acted dose reminder', () async {
    await atSeven(() async {
      await coordinator.saveMedication(_med(id: 'alpha'));
      final dose = doses.items.firstWhere((d) => d.medicationId == 'alpha');
      expect(notifications.scheduled.containsKey(dose.id), isTrue);
      await coordinator.actOnDose(dose, DoseStatus.taken);
      expect(notifications.scheduled.containsKey(dose.id), isFalse);
    });
  });

  test('snooze reschedules the same dose without duplicating it', () async {
    await atSeven(() async {
      await coordinator.saveMedication(_med(id: 'alpha'));
      final dose = doses.items.firstWhere((d) => d.medicationId == 'alpha');
      final before = notifications.doseIdsFor('alpha').length;
      await coordinator.actOnDose(
        dose,
        DoseStatus.snoozed,
        snooze: const Duration(minutes: 10),
      );
      expect(notifications.doseIdsFor('alpha').length, before);
      expect(notifications.scheduled.containsKey(dose.id), isTrue);
    });
  });

  test(
    'registry allocates unique ids and cancelMedication drops only that medication',
    () async {
      final registry = ReminderAlarmRegistry.memory();
      final a1 = await registry.allocate(medicationId: 'alpha', doseId: 'd1');
      final a2 = await registry.allocate(medicationId: 'alpha', doseId: 'd2');
      final b1 = await registry.allocate(medicationId: 'beta', doseId: 'd3');
      expect({a1, a2, b1}, {1, 2, 3});
      expect(await registry.allocate(medicationId: 'alpha', doseId: 'd1'), a1);

      final released = await registry.releaseMedication('alpha');
      expect(released, unorderedEquals([a1, a2]));
      expect(await registry.idsForMedication('alpha'), isEmpty);
      expect(await registry.idsForMedication('beta'), [b1]);
    },
  );

  test('immediate reminder ids stay outside the allocated dose range', () {
    final id = ReminderAlarmRegistry.immediateNotificationId(
      'Supply may run out soon',
    );
    expect(
      id & ReminderAlarmRegistry.immediateIdBase,
      ReminderAlarmRegistry.immediateIdBase,
    );
    expect(id > ReminderAlarmRegistry.maxDoseNotificationId, isTrue);
  });

  test(
    'registry drops invalid persisted ids and keeps the first of a duplicate',
    () async {
      final registry = ReminderAlarmRegistry.memory({
        'nextId': 99,
        'byMedication': {
          'alpha': {
            'keep': 4,
            'fromDouble': 8.0,
            'fraction': 4.5,
            'zero': 0,
            'negative': -3,
            'tooBig': ReminderAlarmRegistry.maxDoseNotificationId + 1,
            'immediate': ReminderAlarmRegistry.immediateIdBase,
            'junk': 'nope',
          },
          'beta': {'dup': 4, 'ok': 7},
          'broken': 'not-a-map',
        },
      });

      expect(await registry.idForDose('keep'), 4);
      expect(await registry.idForDose('fromDouble'), 8);
      expect(await registry.idForDose('fraction'), isNull);
      expect(await registry.idForDose('dup'), isNull);
      expect(await registry.idForDose('ok'), 7);
      expect(await registry.idForDose('zero'), isNull);
      expect(await registry.idForDose('negative'), isNull);
      expect(await registry.idForDose('tooBig'), isNull);
      expect(await registry.idForDose('immediate'), isNull);
      expect(await registry.idForDose('junk'), isNull);
      expect(await registry.idsForMedication('broken'), isEmpty);

      final reused = await registry.allocate(
        medicationId: 'beta',
        doseId: 'dup',
      );
      expect(reused, isNot(4));
      expect(reused, isNot(8));
      expect(reused, isNot(7));
      expect(reused >= 1, isTrue);
      expect(reused <= ReminderAlarmRegistry.maxDoseNotificationId, isTrue);
      expect({4, 8, 7, reused}.length, 4);
    },
  );

  test('registry ignores malformed byMedication payloads', () async {
    final registry = ReminderAlarmRegistry.memory({
      'nextId': 'not-a-number',
      'byMedication': [
        {'dose': 1},
      ],
    });
    expect(await registry.idsForMedication('anything'), isEmpty);
    expect(await registry.allocate(medicationId: 'alpha', doseId: 'd1'), 1);
  });

  test('allocateImmediate issues unique ids that can coexist', () async {
    final registry = ReminderAlarmRegistry.memory();
    final first = await registry.allocateImmediate();
    final second = await registry.allocateImmediate();
    expect(first, isNot(second));
    expect(first > ReminderAlarmRegistry.maxDoseNotificationId, isTrue);
    expect(second > ReminderAlarmRegistry.maxDoseNotificationId, isTrue);
    expect(
      first & ReminderAlarmRegistry.immediateIdBase,
      ReminderAlarmRegistry.immediateIdBase,
    );
    final doseId = await registry.allocate(medicationId: 'alpha', doseId: 'd1');
    expect({first, second, doseId}.length, 3);
  });

  test(
    'scheduleDoseReminder releases registry id when exact and inexact fail',
    () async {
      final registry = ReminderAlarmRegistry.memory();
      final alarms = _RecordingAlarms(throwOnEverySchedule: true);
      final logger = _RecordingLogger();
      final service = LocalNotificationService(
        registry: registry,
        logger: logger,
        alarms: alarms,
      );
      final med = _med(id: 'alpha');
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));
      final dose = MedicationDose(
        id: 'dose-fail',
        medicationId: med.id,
        userId: med.userId,
        scheduledAt: when,
        remindAt: when,
        status: DoseStatus.pending,
        snoozeCount: 0,
        createdAt: when,
        updatedAt: when,
      );

      await expectLater(
        service.scheduleDoseReminder(dose: dose, medication: med),
        throwsA(isA<StateError>()),
      );
      expect(await registry.idForDose(dose.id), isNull);
      expect(alarms.cancelled, isNotEmpty);
      expect(alarms.modes, [
        AndroidScheduleMode.exactAllowWhileIdle,
        AndroidScheduleMode.inexactAllowWhileIdle,
      ]);
      expect(logger.errors, isNotEmpty);

      final retry = await registry.allocate(
        medicationId: med.id,
        doseId: dose.id,
      );
      expect(retry >= 1, isTrue);
      expect(retry <= ReminderAlarmRegistry.maxDoseNotificationId, isTrue);
    },
  );

  test(
    'scheduleDoseReminder keeps registry id when inexact fallback works',
    () async {
      final registry = ReminderAlarmRegistry.memory();
      final alarms = _RecordingAlarms(throwOnExactOnly: true);
      final service = LocalNotificationService(
        registry: registry,
        alarms: alarms,
      );
      final med = _med(id: 'alpha');
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));
      final dose = MedicationDose(
        id: 'dose-ok',
        medicationId: med.id,
        userId: med.userId,
        scheduledAt: when,
        remindAt: when,
        status: DoseStatus.pending,
        snoozeCount: 0,
        createdAt: when,
        updatedAt: when,
      );

      await service.scheduleDoseReminder(dose: dose, medication: med);
      expect(await registry.idForDose(dose.id), isNotNull);
      expect(alarms.modes.last, AndroidScheduleMode.inexactAllowWhileIdle);
    },
  );

  test(
    'scheduleDoseReminder releases registry id even if cleanup cancel throws',
    () async {
      final registry = ReminderAlarmRegistry.memory();
      final alarms = _RecordingAlarms(
        throwOnEverySchedule: true,
        throwOnCleanupCancel: true,
      );
      final logger = _RecordingLogger();
      final service = LocalNotificationService(
        registry: registry,
        logger: logger,
        alarms: alarms,
      );
      final med = _med(id: 'alpha');
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));
      final dose = MedicationDose(
        id: 'dose-cancel-fail',
        medicationId: med.id,
        userId: med.userId,
        scheduledAt: when,
        remindAt: when,
        status: DoseStatus.pending,
        snoozeCount: 0,
        createdAt: when,
        updatedAt: when,
      );

      await expectLater(
        service.scheduleDoseReminder(dose: dose, medication: med),
        throwsA(isA<StateError>()),
      );
      expect(await registry.idForDose(dose.id), isNull);
      expect(logger.errors, contains('Unable to cancel failed reminder'));
    },
  );

  test(
    'cancelDose releases registry id even if registry cancel throws',
    () async {
      final registry = ReminderAlarmRegistry.memory();
      final allocated = await registry.allocate(
        medicationId: 'alpha',
        doseId: 'dose-1',
      );
      expect(await registry.idForDose('dose-1'), allocated);

      final alarms = _RecordingAlarms(throwOnCleanupCancel: true);
      final logger = _RecordingLogger();
      final service = LocalNotificationService(
        registry: registry,
        logger: logger,
        alarms: alarms,
      );

      await expectLater(
        service.cancelDose('dose-1'),
        throwsA(isA<StateError>()),
      );
      expect(await registry.idForDose('dose-1'), isNull);
      expect(logger.errors, contains('Unable to cancel reminder'));
      expect(alarms.cancelled, contains(allocated));
    },
  );

  test(
    'showImmediate uses a unique id for each call with the same title',
    () async {
      final registry = ReminderAlarmRegistry.memory();
      final alarms = _RecordingAlarms();
      final service = LocalNotificationService(
        registry: registry,
        alarms: alarms,
      );

      await service.showImmediate(
        title: 'Supply may run out soon',
        body: 'First',
      );
      await service.showImmediate(
        title: 'Supply may run out soon',
        body: 'Second',
      );

      expect(alarms.shownIds, hasLength(2));
      expect(alarms.shownIds[0], isNot(alarms.shownIds[1]));
      expect(alarms.shownTitles, [
        'Supply may run out soon',
        'Supply may run out soon',
      ]);
      expect(
        alarms.shownIds.every(
          (id) => id > ReminderAlarmRegistry.maxDoseNotificationId,
        ),
        isTrue,
      );
    },
  );
}

class _RecordingLogger extends AppLogger {
  final errors = <String>[];

  @override
  void error(String message, [Object? error]) {
    errors.add(message);
  }
}

class _RecordingAlarms implements NotificationAlarmGateway {
  _RecordingAlarms({
    this.throwOnEverySchedule = false,
    this.throwOnExactOnly = false,
    this.throwOnCleanupCancel = false,
  });

  final bool throwOnEverySchedule;
  final bool throwOnExactOnly;
  final bool throwOnCleanupCancel;
  final cancelled = <int>[];
  final shownIds = <int>[];
  final shownTitles = <String>[];
  final modes = <AndroidScheduleMode>[];
  var _cancelCount = 0;

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    _cancelCount += 1;
    if (throwOnCleanupCancel && _cancelCount > 1) {
      throw StateError('cancel failed');
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shownIds.add(id);
    shownTitles.add(title);
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required AndroidScheduleMode androidScheduleMode,
    required String payload,
  }) async {
    modes.add(androidScheduleMode);
    if (throwOnEverySchedule) {
      throw StateError('schedule failed');
    }
    if (throwOnExactOnly &&
        androidScheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
      throw StateError('exact failed');
    }
  }
}
