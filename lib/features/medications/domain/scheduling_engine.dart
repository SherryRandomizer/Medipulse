import 'package:clock/clock.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:medipulse/shared/models/entities.dart';

class SchedulingEngine {
  SchedulingEngine({
    this.uuid = const Uuid(),
    this.horizonDays = 31,
  });

  final Uuid uuid;
  final int horizonDays;

  List<MedicationDose> generateDoses({
    required Medication medication,
    required DateTime from,
    DateTime? until,
    tz.Location? location,
  }) {
    if (medication.status != MedicationStatus.active) return const [];
    if (medication.schedule.frequency == FrequencyType.asNeeded) return const [];

    final loc = location ?? tz.UTC;
    final start = _max(from, medication.startDate);
    final hardEnd = until ?? start.add(Duration(days: horizonDays));
    final rangeEnd = medication.endDate == null
        ? hardEnd
        : _min(hardEnd, _endOfDay(medication.endDate!, loc));
    if (!rangeEnd.isAfter(start) && rangeEnd.isBefore(start)) {
      return const [];
    }

    final occurrences = _occurrences(medication, start, rangeEnd, loc);
    final unique = <String, DateTime>{};
    for (final occurrence in occurrences) {
      unique[_key(medication.id, occurrence)] = occurrence;
    }

    final now = clock.now().toUtc();
    return unique.values.map((scheduledAt) {
      return MedicationDose(
        id: uuid.v4(),
        medicationId: medication.id,
        userId: medication.userId,
        scheduledAt: scheduledAt.toUtc(),
        remindAt: scheduledAt.toUtc(),
        status: DoseStatus.pending,
        snoozeCount: 0,
        createdAt: now,
        updatedAt: now,
      );
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  String occurrenceKey(String medicationId, DateTime scheduledAt) =>
      _key(medicationId, scheduledAt);

  Iterable<DateTime> _occurrences(
    Medication medication,
    DateTime from,
    DateTime until,
    tz.Location loc,
  ) {
    final schedule = medication.schedule;
    switch (schedule.frequency) {
      case FrequencyType.everyXHours:
        return _everyXHours(medication, from, until, loc);
      case FrequencyType.asNeeded:
        return const [];
      default:
        return _calendarOccurrences(medication, from, until, loc);
    }
  }

  Iterable<DateTime> _everyXHours(
    Medication medication,
    DateTime from,
    DateTime until,
    tz.Location loc,
  ) {
    final hours = medication.schedule.intervalHours ?? 0;
    if (hours <= 0) return const [];
    final times = _effectiveTimes(medication.schedule);
    final firstMinutes = times.isEmpty ? 8 * 60 : times.first;
    var cursor = _atMinutes(loc, medication.startDate, firstMinutes);
    final results = <DateTime>[];
    var guard = 0;
    while (cursor.isBefore(until) || cursor.isAtSameMomentAs(until)) {
      if (!cursor.isBefore(from) && _withinMedicationWindow(medication, cursor, loc)) {
        results.add(cursor);
      }
      cursor = cursor.add(Duration(hours: hours));
      guard++;
      if (guard > 4000) break;
    }
    return results;
  }

  Iterable<DateTime> _calendarOccurrences(
    Medication medication,
    DateTime from,
    DateTime until,
    tz.Location loc,
  ) {
    final results = <DateTime>[];
    var day = tz.TZDateTime(loc, from.year, from.month, from.day);
    final last = tz.TZDateTime(loc, until.year, until.month, until.day);
    while (!day.isAfter(last)) {
      if (_dayMatches(medication.schedule, day)) {
        for (final minutes in _effectiveTimes(medication.schedule)) {
          final occurrence = _atMinutes(loc, day, minutes);
          if (!occurrence.isBefore(from) &&
              !occurrence.isAfter(until) &&
              _withinMedicationWindow(medication, occurrence, loc)) {
            results.add(occurrence);
          }
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return results;
  }

  List<int> _effectiveTimes(MedicationSchedule schedule) {
    if (schedule.timesMinutes.isNotEmpty) {
      return List<int>.from(schedule.timesMinutes)..sort();
    }
    return switch (schedule.frequency) {
      FrequencyType.onceDaily => [8 * 60],
      FrequencyType.twiceDaily => [8 * 60, 20 * 60],
      FrequencyType.threeTimesDaily => [8 * 60, 14 * 60, 20 * 60],
      FrequencyType.fourTimesDaily => [8 * 60, 12 * 60, 16 * 60, 20 * 60],
      FrequencyType.weekly ||
      FrequencyType.monthly ||
      FrequencyType.specificDays ||
      FrequencyType.customTimes => [8 * 60],
      FrequencyType.everyXHours => [8 * 60],
      FrequencyType.asNeeded => const [],
    };
  }

  bool _dayMatches(MedicationSchedule schedule, tz.TZDateTime day) {
    final weekday = day.weekday; // 1=Mon
    switch (schedule.frequency) {
      case FrequencyType.specificDays:
        return schedule.weekdays?.contains(weekday) ?? false;
      case FrequencyType.weekly:
        final days = schedule.weekdays;
        if (days == null || days.isEmpty) return weekday == DateTime.monday;
        return days.contains(weekday);
      case FrequencyType.monthly:
        final target = schedule.monthlyDay ?? 1;
        final lastDay = DateTime(day.year, day.month + 1, 0).day;
        return day.day == (target > lastDay ? lastDay : target);
      default:
        return true;
    }
  }

  bool _withinMedicationWindow(
    Medication medication,
    DateTime occurrence,
    tz.Location loc,
  ) {
    final start = _atMinutes(loc, medication.startDate, 0);
    if (occurrence.isBefore(start)) return false;
    if (medication.endDate == null) return true;
    return !occurrence.isAfter(_endOfDay(medication.endDate!, loc));
  }

  tz.TZDateTime _atMinutes(tz.Location loc, DateTime date, int minutes) {
    final local = tz.TZDateTime.from(date, loc);
    return tz.TZDateTime(
      loc,
      local.year,
      local.month,
      local.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  tz.TZDateTime _endOfDay(DateTime date, tz.Location loc) {
    final local = tz.TZDateTime.from(date, loc);
    return tz.TZDateTime(loc, local.year, local.month, local.day, 23, 59, 59);
  }

  String _key(String medicationId, DateTime scheduledAt) =>
      '$medicationId|${scheduledAt.toUtc().toIso8601String()}';

  DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
