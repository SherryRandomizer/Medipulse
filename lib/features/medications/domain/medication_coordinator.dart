import 'package:clock/clock.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/features/adherence/domain/refill_calculator.dart';
import 'package:medipulse/features/caregivers/domain/caregiver_service.dart';
import 'package:medipulse/features/health/domain/health_sync.dart';
import 'package:medipulse/features/medications/domain/scheduling_engine.dart';
import 'package:medipulse/features/reminders/domain/dose_lifecycle.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class MedicationCoordinator {
  MedicationCoordinator({
    required MedicationRepository medications,
    required DoseRepository doses,
    required NotificationService notifications,
    required SubscriptionService subscriptions,
    required AnalyticsService analytics,
    CaregiverAlertSink? caregiverAlerts,
    HealthSyncService? healthSync,
    RefillCalculator? refillCalculator,
    SchedulingEngine? engine,
    DoseLifecycle? lifecycle,
  }) : _medications = medications,
       _doses = doses,
       _notifications = notifications,
       _subscriptions = subscriptions,
       _analytics = analytics,
       _caregiverAlerts = caregiverAlerts,
       _healthSync = healthSync,
       _refill = refillCalculator ?? RefillCalculator(),
       _engine = engine ?? SchedulingEngine(),
       _lifecycle = lifecycle ?? DoseLifecycle();

  final MedicationRepository _medications;
  final DoseRepository _doses;
  final NotificationService _notifications;
  final SubscriptionService _subscriptions;
  final AnalyticsService _analytics;
  final CaregiverAlertSink? _caregiverAlerts;
  final HealthSyncService? _healthSync;
  final RefillCalculator _refill;
  final SchedulingEngine _engine;
  final DoseLifecycle _lifecycle;

  Future<Medication> saveMedication(Medication medication) async {
    return _saveMedication(medication, logCreatedEvent: true);
  }

  Future<Medication> _saveMedication(
    Medication medication, {
    required bool logCreatedEvent,
  }) async {
    final name = medication.name.trim();
    if (name.isEmpty) {
      throw const ValidationFailure('Enter the medicine name.');
    }
    if (medication.doseAmount <= 0) {
      throw const ValidationFailure('Enter a dose greater than zero.');
    }
    final existing = await _medications.getById(medication.id);
    if (existing == null) {
      final sub = await _subscriptions.current(medication.userId);
      if (!sub.isPremium) {
        final count = await _medications.activeCount(medication.userId);
        if (count >= AppConstants.freeMedicationLimit) {
          throw const SubscriptionFailure(
            'The free plan includes up to ${AppConstants.freeMedicationLimit} medications. Archive one or upgrade to add more.',
          );
        }
      }
    }
    final saved = medication.copyWith(
      name: name,
      updatedAt: clock.now().toUtc(),
    );
    await _medications.save(saved);
    await regenerateSchedule(saved);
    if (logCreatedEvent) {
      await _analytics.logEvent('medication_created');
    }
    return saved;
  }

  Future<void> deleteMedication(Medication medication) async {
    await _saveMedication(
      medication.copyWith(
        status: MedicationStatus.archived,
        deletedAt: clock.now().toUtc(),
      ),
      logCreatedEvent: false,
    );
  }

  Future<void> regenerateSchedule(Medication medication) async {
    // Capture the pending dose IDs before replacePending removes them. Older
    // app versions scheduled alarms directly from dose IDs, so the current
    // notification registry cannot identify those OS alarms by medication.
    final previousDoseIds = (await _doses.pending(medication.userId))
        .where((dose) => dose.medicationId == medication.id)
        .map((dose) => dose.id)
        .toSet();
    await _notifications.cancelMedication(
      medication.id,
      priorDoseIds: previousDoseIds,
    );
    final loc = _location(medication.timeZone);
    final generated = _engine.generateDoses(
      medication: medication,
      from: clock.now().toUtc().subtract(const Duration(minutes: 1)),
      location: loc,
    );
    await _doses.replacePending(medication.id, generated);
    if (medication.isPaused ||
        medication.isArchived ||
        medication.deletedAt != null) {
      return;
    }
    for (final dose in generated) {
      await _notifications.scheduleDoseReminder(
        dose: dose,
        medication: medication,
      );
    }
  }

  /// Additively extends eligible medication schedules through the scheduling
  /// horizon. Existing doses are never deleted or modified.
  Future<void> extendSchedules(
    String userId, {
    bool scheduleReminders = true,
  }) async {
    final now = clock.now().toUtc();
    final until = now.add(Duration(days: _engine.horizonDays));
    final meds = await _medications.list(userId, includeArchived: true);

    for (final medication in meds) {
      if (medication.isPaused ||
          medication.isArchived ||
          medication.deletedAt != null ||
          medication.schedule.frequency == FrequencyType.asNeeded) {
        continue;
      }

      final candidates = _engine.generateDoses(
        medication: medication,
        from: now.subtract(const Duration(minutes: 1)),
        until: until,
        location: _location(medication.timeZone),
      );

      if (candidates.isEmpty) continue;

      final inserted = await _doses.insertMissing(candidates);

      if (scheduleReminders) {
        for (final dose in inserted) {
          await _notifications.scheduleDoseReminder(
            dose: dose,
            medication: medication,
          );
        }
      }
    }
  }

  Future<void> rescheduleNotifications(String userId) async {
    await _notifications.cancelAllReminders();
    final pending = await _doses.pending(userId);
    final meds = {
      for (final m in await _medications.list(userId, includeArchived: true))
        m.id: m,
    };
    for (final dose in pending) {
      final med = meds[dose.medicationId];
      if (med == null ||
          med.isPaused ||
          med.isArchived ||
          med.deletedAt != null) {
        continue;
      }
      await _notifications.scheduleDoseReminder(dose: dose, medication: med);
    }
  }

  Future<void> markOverdueMissed(
    String userId, {
    String firstName = 'Someone',
  }) async {
    final pending = await _doses.pending(userId);
    for (final dose in pending) {
      final updated = _lifecycle.markMissedIfOverdue(dose);
      if (updated.status == DoseStatus.missed) {
        await _doses.save(updated);
        await _notifications.cancelDose(dose.id);
        await _analytics.logEvent('medication_missed');
        await _caregiverAlerts?.onMissedDose(
          ownerUserId: userId,
          ownerFirstName: firstName,
          scheduledAt: updated.scheduledAt,
        );
      }
    }
  }

  Future<MedicationDose> actOnDose(
    MedicationDose dose,
    DoseStatus action, {
    Duration? snooze,
  }) async {
    late final MedicationDose updated;
    switch (action) {
      case DoseStatus.taken:
        updated = _lifecycle.markTaken(dose);
        await _analytics.logEvent('medication_taken');
      case DoseStatus.skipped:
        updated = _lifecycle.markSkipped(dose);
        await _analytics.logEvent('medication_skipped');
      case DoseStatus.snoozed:
        updated = _lifecycle.snooze(
          dose,
          snooze ?? const Duration(minutes: 10),
        );
      default:
        throw const ValidationFailure('That action is not available.');
    }
    await _doses.save(updated);
    await _notifications.cancelDose(dose.id);
    if (updated.status == DoseStatus.taken) {
      await _consumeSupply(dose.medicationId);
      await _healthSync?.onDoseTaken(
        userId: dose.userId,
        takenAt: updated.actedAt ?? clock.now().toUtc(),
      );
    }
    if (updated.status == DoseStatus.snoozed) {
      final med = await _medications.getById(dose.medicationId);
      if (med != null) {
        await _notifications.scheduleDoseReminder(
          dose: updated,
          medication: med,
        );
      }
    }
    return updated;
  }

  Future<void> _consumeSupply(String medicationId) async {
    final med = await _medications.getById(medicationId);
    if (med == null || med.quantity == null) return;
    final next = (med.quantity! - med.doseAmount).clamp(0, 1000000).toDouble();
    final updated = med.copyWith(quantity: next);
    await _medications.save(updated);
    if (_refill.estimate(updated).warning) {
      await _notifications.showImmediate(
        title: 'Supply may run out soon',
        body:
            'Your medication may run out soon. This estimate is not medical advice.',
      );
    }
  }

  Future<void> updateSupply(Medication medication, double quantity) {
    return saveMedication(medication.copyWith(quantity: quantity));
  }

  tz.Location _location(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.local;
    }
  }
}
