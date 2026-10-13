import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medipulse/core/di/providers.dart';
import 'package:medipulse/features/dashboard/domain/home_dose_visibility.dart';
import 'package:medipulse/features/medications/domain/medication_search.dart';
import 'package:medipulse/shared/models/entities.dart';

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final value = await ref.watch(localDatabaseProvider).getState('onboarding_complete');
  return value == 'true';
});

final notificationPromptedProvider = FutureProvider<bool>((ref) async {
  final value = await ref.watch(localDatabaseProvider).getState('notification_prompted');
  return value == 'true';
});

class HomeSnapshot {
  const HomeSnapshot({
    required this.user,
    required this.items,
    required this.summary,
    required this.refillWarnings,
    required this.nextItem,
    required this.medications,
  });

  final UserProfile user;
  final List<TimelineItem> items;
  final AdherenceSummary summary;
  final List<Medication> refillWarnings;
  final TimelineItem? nextItem;
  final List<Medication> medications;
}

final homeSnapshotProvider = FutureProvider<HomeSnapshot?>((ref) async {
  final user = await ref.watch(sessionControllerProvider.future);
  if (user == null) return null;
  await ref.read(medicationCoordinatorProvider).markOverdueMissed(
    user.id,
    firstName: user.greetingName,
  );
  final medications = await ref.read(medicationRepositoryProvider).list(user.id);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).toUtc();
  final end = start.add(const Duration(days: 1));
  final doses = await ref.read(doseRepositoryProvider).forUser(user.id, from: start, to: end);
  final byId = {for (final m in medications) m.id: m};
  final visible = HomeDoseVisibility(ref.read(schedulingEngineProvider)).visibleDoses(
    doses: doses,
    medications: byId,
  );
  final items = [
    for (final dose in visible) TimelineItem(dose: dose, medication: byId[dose.medicationId]!),
  ];
  final summary = ref.read(adherenceCalculatorProvider).summarize(visible);
  final refill = ref.read(refillCalculatorProvider);
  final warnings = [
    for (final med in medications)
      if (refill.estimate(med).warning) med,
  ];
  TimelineItem? next;
  for (final item in items) {
    if (item.dose.status == DoseStatus.pending || item.dose.status == DoseStatus.snoozed) {
      next = item;
      break;
    }
  }
  return HomeSnapshot(
    user: user,
    items: items,
    summary: summary,
    refillWarnings: warnings,
    nextItem: next,
    medications: medications,
  );
});

final medicationsListProvider =
    FutureProvider.family<List<Medication>, ({String query, bool includeArchived})>((ref, filter) async {
  final user = await ref.watch(sessionControllerProvider.future);
  if (user == null) return [];
  final all = await ref.read(medicationRepositoryProvider).list(user.id, includeArchived: true);
  return MedicationSearch.apply(
    all,
    query: filter.query,
    includeArchivedWhenEmpty: filter.includeArchived,
  );
});

final calendarDosesProvider = FutureProvider.family<List<TimelineItem>, DateTime>((ref, day) async {
  final user = await ref.watch(sessionControllerProvider.future);
  if (user == null) return [];
  final start = DateTime(day.year, day.month, day.day).toUtc();
  final end = start.add(const Duration(days: 1));
  final meds = {for (final m in await ref.read(medicationRepositoryProvider).list(user.id, includeArchived: true)) m.id: m};
  final doses = await ref.read(doseRepositoryProvider).forUser(user.id, from: start, to: end);
  return [
    for (final dose in doses)
      if (meds.containsKey(dose.medicationId)) TimelineItem(dose: dose, medication: meds[dose.medicationId]!),
  ];
});

final rangeAdherenceProvider = FutureProvider.family<AdherenceSummary, ({DateTime from, DateTime to})>((ref, range) async {
  final user = await ref.watch(sessionControllerProvider.future);
  if (user == null) {
    return const AdherenceSummary(scheduled: 0, taken: 0, missed: 0, skipped: 0, pending: 0, snoozed: 0);
  }
  final doses = await ref.read(doseRepositoryProvider).forUser(
    user.id,
    from: range.from.toUtc(),
    to: range.to.toUtc(),
  );
  return ref.read(adherenceCalculatorProvider).summarize(doses);
});

final prefsProvider = FutureProvider<NotificationPreference?>((ref) async {
  final user = await ref.watch(sessionControllerProvider.future);
  if (user == null) return null;
  return ref.read(localDatabaseProvider).notificationPreference(user.id);
});
