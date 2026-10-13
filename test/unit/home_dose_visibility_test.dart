import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:medipulse/features/dashboard/domain/home_dose_visibility.dart';
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
  MedicationStatus status = MedicationStatus.active,
  String id = 'med-1',
}) {
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
    status: status,
    createdAt: start,
    updatedAt: start,
    schedule: MedicationSchedule(
      id: 'sched-$id',
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

MedicationDose _dose({
  required DateTime scheduledAt,
  required DoseStatus status,
  String medicationId = 'med-1',
  DateTime? remindAt,
}) {
  return MedicationDose(
    id: 'dose-${scheduledAt.toUtc().toIso8601String()}',
    medicationId: medicationId,
    userId: 'user-1',
    scheduledAt: scheduledAt.toUtc(),
    remindAt: (remindAt ?? scheduledAt).toUtc(),
    status: status,
    snoozeCount: 0,
    createdAt: scheduledAt.toUtc(),
    updatedAt: scheduledAt.toUtc(),
  );
}

void main() {
  tzdata.initializeTimeZones();
  final engine = SchedulingEngine();
  final visibility = HomeDoseVisibility(engine);
  final nyc = tz.getLocation('America/New_York');
  final karachi = tz.getLocation('Asia/Karachi');

  bool shown(Medication med, MedicationDose dose) {
    return visibility.isVisible(medication: med, dose: dose);
  }

  test('excludes missed time that is no longer on a daily schedule', () {
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 10, 12),
      times: const [15 * 60 + 5],
    );
    final missedOld = _dose(
      scheduledAt: DateTime.utc(2026, 10, 12, 7, 45),
      status: DoseStatus.missed,
    );
    final pendingNew = _dose(
      scheduledAt: DateTime.utc(2026, 10, 12, 10, 5),
      status: DoseStatus.pending,
    );
    expect(shown(med, missedOld), isFalse);
    expect(shown(med, pendingNew), isTrue);
  });

  test('keeps taken or missed when that time is still on the schedule', () {
    final med = _med(
      frequency: FrequencyType.twiceDaily,
      start: DateTime.utc(2026, 6, 1),
      times: const [8 * 60, 20 * 60],
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 8), status: DoseStatus.taken)),
      isTrue,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 8), status: DoseStatus.missed)),
      isTrue,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 20), status: DoseStatus.skipped)),
      isTrue,
    );
  });

  test('pending and snoozed stay visible even if the clock time looks old', () {
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 6, 1),
      times: const [15 * 60],
    );
    final leftover = _dose(
      scheduledAt: DateTime.utc(2026, 6, 1, 8),
      status: DoseStatus.pending,
    );
    final snoozed = _dose(
      scheduledAt: DateTime.utc(2026, 6, 1, 8),
      remindAt: DateTime.utc(2026, 6, 1, 8, 10),
      status: DoseStatus.snoozed,
    );
    expect(shown(med, leftover), isTrue);
    expect(shown(med, snoozed), isTrue);
  });

  test('weekdays keep Monday 8:00 and drop a Tuesday dose if Tuesday is not selected', () {
    final med = _med(
      frequency: FrequencyType.specificDays,
      start: DateTime.utc(2026, 6, 1),
      weekdays: const [DateTime.monday],
    );
    final monday = DateTime.utc(2026, 6, 1, 8);
    expect(monday.weekday, DateTime.monday);
    final tuesday = DateTime.utc(2026, 6, 2, 8);
    expect(tuesday.weekday, DateTime.tuesday);
    expect(shown(med, _dose(scheduledAt: monday, status: DoseStatus.missed)), isTrue);
    expect(shown(med, _dose(scheduledAt: tuesday, status: DoseStatus.missed)), isFalse);
  });

  test('monthly keeps the clamped calendar day and drops other days', () {
    final med = _med(
      frequency: FrequencyType.monthly,
      start: DateTime.utc(2026, 2, 1),
      monthlyDay: 31,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 2, 28, 8), status: DoseStatus.taken)),
      isTrue,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 2, 27, 8), status: DoseStatus.taken)),
      isFalse,
    );
  });

  test('every X hours keeps grid times from startDate and drops off-grid times', () {
    final med = _med(
      frequency: FrequencyType.everyXHours,
      start: DateTime.utc(2026, 6, 1, 8),
      times: const [8 * 60],
      intervalHours: 8,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 16), status: DoseStatus.missed)),
      isTrue,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 12), status: DoseStatus.missed)),
      isFalse,
    );
  });

  test('PRN has no clock schedule so historical timed misses are hidden on Home', () {
    final med = _med(
      frequency: FrequencyType.asNeeded,
      start: DateTime.utc(2026, 6, 1),
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 8), status: DoseStatus.missed)),
      isFalse,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 8), status: DoseStatus.pending)),
      isTrue,
    );
  });

  test('start and end dates exclude doses outside the medication window', () {
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 6, 2),
      end: DateTime.utc(2026, 6, 3),
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 8), status: DoseStatus.missed)),
      isFalse,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 2, 8), status: DoseStatus.missed)),
      isTrue,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 4, 8), status: DoseStatus.missed)),
      isFalse,
    );
  });

  test('Karachi local 12:45 matches timesMinutes 765', () {
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 10, 12),
      times: const [12 * 60 + 45],
      tzName: 'Asia/Karachi',
    );
    final local = tz.TZDateTime(karachi, 2026, 10, 12, 12, 45);
    expect(shown(med, _dose(scheduledAt: local, status: DoseStatus.missed)), isTrue);
    final other = tz.TZDateTime(karachi, 2026, 10, 12, 15, 5);
    expect(shown(med, _dose(scheduledAt: other, status: DoseStatus.missed)), isFalse);
  });

  test('paused medication still shows history at the current clock time', () {
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 6, 1),
      status: MedicationStatus.paused,
    );
    expect(
      shown(med, _dose(scheduledAt: DateTime.utc(2026, 6, 1, 8), status: DoseStatus.taken)),
      isTrue,
    );
  });

  test('DST spring-forward occurrence from the engine still matches', () {
    final start = tz.TZDateTime(nyc, 2026, 3, 7, 8);
    final med = _med(
      frequency: FrequencyType.onceDaily,
      start: start,
      times: const [2 * 60],
      tzName: 'America/New_York',
    );
    final generated = engine.generateDoses(
      medication: med,
      from: tz.TZDateTime(nyc, 2026, 3, 8),
      until: tz.TZDateTime(nyc, 2026, 3, 9),
      location: nyc,
    );
    expect(generated, isNotEmpty);
    expect(
      engine.matchesCurrentSchedule(
        medication: med,
        scheduledAt: generated.first.scheduledAt,
        location: nyc,
      ),
      isTrue,
    );
    expect(
      shown(med, generated.first.copyWith(status: DoseStatus.missed)),
      isTrue,
    );
  });

  test('visibleDoses filters Home summary input without dropping other medications', () {
    final alpha = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 10, 12),
      times: const [15 * 60 + 5],
      id: 'alpha',
    );
    final beta = _med(
      frequency: FrequencyType.onceDaily,
      start: DateTime.utc(2026, 10, 12),
      times: const [8 * 60],
      id: 'beta',
    );
    final doses = [
      _dose(
        scheduledAt: DateTime.utc(2026, 10, 12, 7, 45),
        status: DoseStatus.missed,
        medicationId: 'alpha',
      ),
      _dose(
        scheduledAt: DateTime.utc(2026, 10, 12, 10, 5),
        status: DoseStatus.pending,
        medicationId: 'alpha',
      ),
      _dose(
        scheduledAt: DateTime.utc(2026, 10, 12, 8),
        status: DoseStatus.missed,
        medicationId: 'beta',
      ),
    ];
    final visible = visibility.visibleDoses(
      doses: doses,
      medications: {alpha.id: alpha, beta.id: beta},
    );
    expect(visible.map((d) => d.id), isNot(contains(doses.first.id)));
    expect(visible.map((d) => d.medicationId), containsAll(['alpha', 'beta']));
    expect(visible.where((d) => d.medicationId == 'beta').length, 1);
  });
}
