import 'package:clock/clock.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/core/constants/app_constants.dart';
import 'package:medipulse/core/errors/app_failure.dart';
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
    SchedulingEngine? engine,
    DoseLifecycle? lifecycle,
  }) : _medications = medications,
       _doses = doses,
       _notifications = notifications,
       _subscriptions = subscriptions,
       _analytics = analytics,
       _engine = engine ?? SchedulingEngine(),
       _lifecycle = lifecycle ?? DoseLifecycle();

  final MedicationRepository _medications;
  final DoseRepository _doses;
  final NotificationService _notifications;
  final SubscriptionService _subscriptions;
  final AnalyticsService _analytics;
  final SchedulingEngine _engine;
  final DoseLifecycle _lifecycle;

  Future<Medication> saveMedication(Medication medication) async {
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
    final saved = medication.copyWith(name: name, updatedAt: clock.now().toUtc());
    await _medications.save(saved);
    await regenerateSchedule(saved);
    await _analytics.logEvent('medication_created');
    return saved;
  }

  Future<void> regenerateSchedule(Medication medication) async {
    final loc = _location(medication.timeZone);
    final generated = _engine.generateDoses(
      medication: medication,
      from: clock.now().toUtc().subtract(const Duration(minutes: 1)),
      location: loc,
    );
    await _doses.replacePending(medication.id, generated);
    await rescheduleNotifications(medication.userId);
  }

  Future<void> rescheduleNotifications(String userId) async {
    final pending = await _doses.pending(userId);
    final meds = {for (final m in await _medications.list(userId)) m.id: m};
    for (final dose in pending) {
      await _notifications.cancelDose(dose.id);
      final med = meds[dose.medicationId];
      if (med == null || med.isPaused || med.isArchived) continue;
      await _notifications.scheduleDoseReminder(dose: dose, medication: med);
    }
  }

  Future<void> markOverdueMissed(String userId) async {
    final pending = await _doses.pending(userId);
    for (final dose in pending) {
      final updated = _lifecycle.markMissedIfOverdue(dose);
      if (updated.status == DoseStatus.missed) {
        await _doses.save(updated);
        await _notifications.cancelDose(dose.id);
        await _analytics.logEvent('medication_missed');
      }
    }
  }

  Future<MedicationDose> actOnDose(MedicationDose dose, DoseStatus action, {Duration? snooze}) async {
    late final MedicationDose updated;
    switch (action) {
      case DoseStatus.taken:
        updated = _lifecycle.markTaken(dose);
        await _analytics.logEvent('medication_taken');
      case DoseStatus.skipped:
        updated = _lifecycle.markSkipped(dose);
        await _analytics.logEvent('medication_skipped');
      case DoseStatus.snoozed:
        updated = _lifecycle.snooze(dose, snooze ?? const Duration(minutes: 10));
      default:
        throw const ValidationFailure('That action is not available.');
    }
    await _doses.save(updated);
    await _notifications.cancelDose(dose.id);
    if (updated.status == DoseStatus.snoozed) {
      final med = await _medications.getById(dose.medicationId);
      if (med != null) {
        await _notifications.scheduleDoseReminder(dose: updated, medication: med);
      }
    }
    return updated;
  }

  tz.Location _location(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.local;
    }
  }
}
