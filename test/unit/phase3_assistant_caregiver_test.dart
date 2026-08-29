import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/core/config/app_config.dart';
import 'package:medipulse/features/ai/domain/schedule_assistant.dart';
import 'package:medipulse/features/caregivers/domain/caregiver_access_policy.dart';
import 'package:medipulse/features/subscriptions/domain/premium_features.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/phase3_adapters.dart';

Medication _med(String name, {String food = ''}) {
  final now = DateTime.utc(2026, 6, 1);
  return Medication(
    id: name,
    userId: 'u1',
    name: name,
    form: MedicationForm.tablet,
    doseAmount: 1,
    doseUnit: 'tablet',
    foodInstruction: food,
    startDate: now,
    timeZone: 'UTC',
    status: MedicationStatus.active,
    createdAt: now,
    updatedAt: now,
    schedule: MedicationSchedule(
      id: 's$name',
      medicationId: name,
      frequency: FrequencyType.onceDaily,
      timesMinutes: const [480],
      createdAt: now,
      updatedAt: now,
    ),
  );
}

MedicationDose _dose(String id, DateTime at, DoseStatus status) {
  return MedicationDose(
    id: id,
    medicationId: 'A',
    userId: 'u1',
    scheduledAt: at,
    remindAt: at,
    status: status,
    snoozeCount: 0,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  test('assistant refuses prescribe and diagnose questions', () {
    final reply = ScheduleAssistant().answer(
      question: 'Can you prescribe a stronger dose?',
      today: const [],
      yesterday: const [],
      tomorrow: const [],
      now: DateTime.utc(2026, 6, 1, 12),
    );
    expect(reply.refusedMedicalAdvice, isTrue);
    expect(reply.fromStoredSchedule, isFalse);
  });

  test('assistant answers next dose from stored schedule', () {
    final at = DateTime.utc(2026, 6, 1, 20);
    final item = TimelineItem(dose: _dose('d1', at, DoseStatus.pending), medication: _med('Example'));
    final reply = ScheduleAssistant().answer(
      question: 'When is my next dose?',
      today: [item],
      yesterday: const [],
      tomorrow: const [],
      now: DateTime.utc(2026, 6, 1, 12),
    );
    expect(reply.fromStoredSchedule, isTrue);
    expect(reply.text.contains('Example'), isTrue);
  });

  test('revoked caregiver cannot receive alerts', () {
    final now = DateTime.utc(2026, 6, 1);
    final caregiver = Caregiver(
      id: 'c1',
      ownerUserId: 'u1',
      displayName: 'Alex',
      relation: CaregiverRelation.spouse,
      status: CaregiverPermissionStatus.revoked,
      shareAdherence: true,
      inviteCode: 'ABC',
      createdAt: now,
      updatedAt: now,
    );
    expect(CaregiverAccessPolicy.canReceiveAdherenceAlert(caregiver), isFalse);
  });

  test('missed alert omits medicine names', () {
    final body = CaregiverAccessPolicy.missedAlertBody(
      firstName: 'John',
      scheduledAt: DateTime(2026, 6, 1, 20),
    );
    expect(body.contains('John'), isTrue);
    expect(body.toLowerCase().contains('metformin'), isFalse);
  });

  test('premium gates and ads respect stored entitlement', () {
    final free = Subscription(userId: 'u', tier: SubscriptionTier.free, updatedAt: DateTime.utc(2026));
    final premium = Subscription(userId: 'u', tier: SubscriptionTier.premium, updatedAt: DateTime.utc(2026));
    expect(PremiumFeatures.canUseAssistant(free), isFalse);
    expect(PremiumFeatures.canUseAssistant(premium), isTrue);
    const config = AppConfig(
      environment: AppEnvironment.development,
      firebaseEnabled: false,
      aiProvider: 'none',
      ocrProvider: 'none',
      adsEnabled: true,
      revenueCatApiKey: '',
      googleWebClientId: '',
      apiBaseUrl: '',
      medicalDataApiKey: '',
    );
    expect(ConfigAdService(config).adsEnabledFor(free), isTrue);
    expect(ConfigAdService(config).adsEnabledFor(premium), isFalse);
  });
}
