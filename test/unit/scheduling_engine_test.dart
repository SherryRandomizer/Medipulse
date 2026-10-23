import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/features/medications/domain/scheduling_engine.dart';
import 'package:medipulse/shared/models/entities.dart';

Medication _med({
  required FrequencyType frequency,
  required DateTime start,
  DateTime? end,
  List<int> times = const [8 * 60],
  int? intervalHours,
  List<int>? weekdays,
  int? monthlyDay,
  String tzName = 'UTC',
}) {
  const id = 'med-1';
  return Medication(
    id: id,
    userId: 'user-1',
    name: 'Example',
    form: MedicationForm.tablet,
    doseAmount: 1,
    doseUnit: 'tablet',
    startDate: start,
    endDate: end,
    timeZone: tzName,
    status: MedicationStatus.active,
    createdAt: start,
    updatedAt: start,
    schedule: MedicationSchedule(
      id: 'sched-1',
      medicationId: id,
      frequency: frequency,
      timesMinutes: times,
      intervalHours: intervalHours,
      weekdays: weekdays,
      monthlyDay: monthlyDay,
      createdAt: start,
      updatedAt: start,
    ),
  );
}

void main() {
  tzdata.initializeTimeZones();
  final utc = tz.UTC;
  final nyc = tz.getLocation('America/New_York');

  test('once daily does not duplicate the same timestamp', () {
    final start = DateTime.utc(2026, 3, 1, 0);
    final med = _med(frequency: FrequencyType.onceDaily, start: start);
    final engine = SchedulingEngine(horizonDays: 3);
    final doses = withClock(Clock.fixed(start), () {
      return engine.generateDoses(
        medication: med,
        from: start,
        until: DateTime.utc(2026, 3, 4),
        location: utc,
      );
    });
    final keys = doses
        .map((d) => '${d.medicationId}|${d.scheduledAt.toIso8601String()}')
        .toSet();
    expect(keys.length, doses.length);
    expect(doses.length, 3);
  });

  test('twice daily creates morning and evening doses', () {
    final start = DateTime.utc(2026, 6, 1);
    final med = _med(
      frequency: FrequencyType.twiceDaily,
      start: start,
      times: const [8 * 60, 20 * 60],
    );
    final doses = SchedulingEngine().generateDoses(
      medication: med,
      from: start,
      until: DateTime.utc(2026, 6, 2),
      location: utc,
    );
    expect(doses.length, 2);
    expect(doses.first.scheduledAt.toUtc().hour, 8);
    expect(doses.last.scheduledAt.toUtc().hour, 20);
  });

  test('every 8 hours crosses midnight', () {
    final start = DateTime.utc(2026, 6, 1, 22);
    final med = _med(
      frequency: FrequencyType.everyXHours,
      start: start,
      times: const [22 * 60],
      intervalHours: 8,
    );
    final doses = SchedulingEngine().generateDoses(
      medication: med,
      from: start,
      until: DateTime.utc(2026, 6, 3, 6),
      location: utc,
    );
    expect(doses.length, greaterThanOrEqualTo(3));
    expect(
      doses[1].scheduledAt.difference(doses[0].scheduledAt),
      const Duration(hours: 8),
    );
  });

  test('old hourly medication generates doses in the requested window', () {
    final start = DateTime.utc(2025, 1, 1);
    final from = DateTime.utc(2026, 10, 20);
    final until = DateTime.utc(2026, 10, 22);

    final med = _med(
      frequency: FrequencyType.everyXHours,
      start: start,
      times: const [8 * 60],
      intervalHours: 1,
    );

    final doses = SchedulingEngine(
      horizonDays: 31,
    ).generateDoses(medication: med, from: from, until: until, location: utc);

    expect(doses, isNotEmpty);
    expect(
      doses.every(
        (dose) =>
            !dose.scheduledAt.isBefore(from) &&
            !dose.scheduledAt.isAfter(until),
      ),
      isTrue,
    );

    for (var i = 1; i < doses.length; i++) {
      expect(
        doses[i].scheduledAt.difference(doses[i - 1].scheduledAt),
        const Duration(hours: 1),
      );
    }
  });

  test('specific days only fires on selected weekdays', () {
    final start = DateTime.utc(2026, 6, 1); // Monday
    final med = _med(
      frequency: FrequencyType.specificDays,
      start: start,
      weekdays: [DateTime.wednesday],
    );
    final doses = SchedulingEngine().generateDoses(
      medication: med,
      from: start,
      until: DateTime.utc(2026, 6, 8),
      location: utc,
    );
    expect(
      doses.every((d) => d.scheduledAt.weekday == DateTime.wednesday),
      isTrue,
    );
  });

  test('monthly clamps to last day of shorter months', () {
    final med = _med(
      frequency: FrequencyType.monthly,
      start: DateTime.utc(2026, 1, 1),
      monthlyDay: 31,
      times: const [9 * 60],
    );
    final feb = SchedulingEngine().generateDoses(
      medication: med,
      from: DateTime.utc(2026, 2, 1),
      until: DateTime.utc(2026, 3, 1),
      location: utc,
    );
    expect(
      feb.where((d) => d.scheduledAt.month == 2).first.scheduledAt.day,
      28,
    );
  });

  test('end date stops generation', () {
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 6, 1),
      end: DateTime.utc(2026, 6, 2),
    );
    final doses = SchedulingEngine(horizonDays: 30).generateDoses(
      medication: med,
      from: DateTime.utc(2026, 6, 1),
      location: utc,
    );
    expect(doses.last.scheduledAt.isBefore(DateTime.utc(2026, 6, 3)), isTrue);
  });

  test('PRN produces no automatic doses', () {
    final med = _med(
      frequency: FrequencyType.asNeeded,
      start: DateTime.utc(2026, 6, 1),
    );
    final doses = SchedulingEngine().generateDoses(
      medication: med,
      from: DateTime.utc(2026, 6, 1),
      location: utc,
    );
    expect(doses, isEmpty);
  });

  test('DST spring-forward still yields a valid local civil time', () {
    // America/New_York 2026-03-08 02:00 does not exist.
    final start = tz.TZDateTime(nyc, 2026, 3, 7, 8);
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: start,
      times: const [2 * 60],
      tzName: 'America/New_York',
    );
    final doses = SchedulingEngine().generateDoses(
      medication: med,
      from: tz.TZDateTime(nyc, 2026, 3, 8),
      until: tz.TZDateTime(nyc, 2026, 3, 9),
      location: nyc,
    );
    expect(doses, isNotEmpty);
    final local = tz.TZDateTime.from(doses.first.scheduledAt, nyc);
    expect(local.isBefore(tz.TZDateTime(nyc, 2026, 3, 9)), isTrue);
  });
}
