enum MedicationForm {
  tablet,
  capsule,
  syrup,
  liquid,
  injection,
  drops,
  cream,
  ointment,
  inhaler,
  powder,
  patch,
  other;

  String get label => switch (this) {
    tablet => 'Tablet',
    capsule => 'Capsule',
    syrup => 'Syrup',
    liquid => 'Liquid',
    injection => 'Injection',
    drops => 'Drops',
    cream => 'Cream',
    ointment => 'Ointment',
    inhaler => 'Inhaler',
    powder => 'Powder',
    patch => 'Patch',
    other => 'Other',
  };
}

enum FrequencyType {
  onceDaily,
  twiceDaily,
  threeTimesDaily,
  fourTimesDaily,
  customTimes,
  everyXHours,
  specificDays,
  weekly,
  monthly,
  asNeeded;

  String get label => switch (this) {
    onceDaily => 'Once daily',
    twiceDaily => 'Twice daily',
    threeTimesDaily => 'Three times daily',
    fourTimesDaily => 'Four times daily',
    customTimes => 'Custom times',
    everyXHours => 'Every few hours',
    specificDays => 'Specific days',
    weekly => 'Weekly',
    monthly => 'Monthly',
    asNeeded => 'As needed (PRN)',
  };
}

enum MedicationStatus { active, paused, archived }

enum DoseStatus { pending, taken, missed, skipped, snoozed }

enum CaregiverRelation { parent, child, spouse, familyMember }

enum CaregiverPermissionStatus { pending, accepted, revoked }

enum SubscriptionTier { free, premium }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.timeZone,
    required this.preferredLanguage,
    required this.emailVerified,
    required this.isGuest,
    required this.createdAt,
    required this.updatedAt,
    this.dateOfBirth,
    this.photoPath,
    this.deletedAt,
    this.largeText = false,
    this.highContrast = false,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime? dateOfBirth;
  final String? photoPath;
  final String timeZone;
  final String preferredLanguage;
  final bool emailVerified;
  final bool isGuest;
  final bool largeText;
  final bool highContrast;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get greetingName {
    final name = displayName.trim();
    if (name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  UserProfile copyWith({
    String? displayName,
    DateTime? dateOfBirth,
    String? photoPath,
    String? timeZone,
    String? preferredLanguage,
    bool? emailVerified,
    bool? largeText,
    bool? highContrast,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photoPath: photoPath ?? this.photoPath,
      timeZone: timeZone ?? this.timeZone,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      emailVerified: emailVerified ?? this.emailVerified,
      isGuest: isGuest,
      largeText: largeText ?? this.largeText,
      highContrast: highContrast ?? this.highContrast,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

class NotificationPreference {
  const NotificationPreference({
    required this.userId,
    required this.enabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.snoozeMinutes,
    required this.updatedAt,
  });

  final String userId;
  final bool enabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final List<int> snoozeMinutes;
  final DateTime updatedAt;

  NotificationPreference copyWith({
    bool? enabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    List<int>? snoozeMinutes,
    DateTime? updatedAt,
  }) {
    return NotificationPreference(
      userId: userId,
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MedicationSchedule {
  const MedicationSchedule({
    required this.id,
    required this.medicationId,
    required this.frequency,
    required this.timesMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.intervalHours,
    this.weekdays,
    this.monthlyDay,
  });

  final String id;
  final String medicationId;
  final FrequencyType frequency;
  final List<int> timesMinutes;
  final int? intervalHours;
  final List<int>? weekdays;
  final int? monthlyDay;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicationSchedule copyWith({
    FrequencyType? frequency,
    List<int>? timesMinutes,
    int? intervalHours,
    List<int>? weekdays,
    int? monthlyDay,
    DateTime? updatedAt,
  }) {
    return MedicationSchedule(
      id: id,
      medicationId: medicationId,
      frequency: frequency ?? this.frequency,
      timesMinutes: timesMinutes ?? this.timesMinutes,
      intervalHours: intervalHours ?? this.intervalHours,
      weekdays: weekdays ?? this.weekdays,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Medication {
  const Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.form,
    required this.doseAmount,
    required this.doseUnit,
    required this.schedule,
    required this.startDate,
    required this.timeZone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.genericName,
    this.strength,
    this.foodInstruction,
    this.additionalInstructions,
    this.quantity,
    this.refillThreshold,
    this.doctorName,
    this.notes,
    this.endDate,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? genericName;
  final String? strength;
  final MedicationForm form;
  final double doseAmount;
  final String doseUnit;
  final MedicationSchedule schedule;
  final String? foodInstruction;
  final String? additionalInstructions;
  final double? quantity;
  final double? refillThreshold;
  final String? doctorName;
  final String? notes;
  final DateTime startDate;
  final DateTime? endDate;
  final String timeZone;
  final MedicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isArchived => status == MedicationStatus.archived;
  bool get isPaused => status == MedicationStatus.paused;

  String get doseLabel {
    final amount = doseAmount == doseAmount.roundToDouble()
        ? doseAmount.toInt().toString()
        : doseAmount.toString()
    ;
    return '$amount $doseUnit';
  }

  Medication copyWith({
    String? name,
    String? genericName,
    String? strength,
    MedicationForm? form,
    double? doseAmount,
    String? doseUnit,
    MedicationSchedule? schedule,
    String? foodInstruction,
    String? additionalInstructions,
    double? quantity,
    double? refillThreshold,
    String? doctorName,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    String? timeZone,
    MedicationStatus? status,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Medication(
      id: id,
      userId: userId,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      doseAmount: doseAmount ?? this.doseAmount,
      doseUnit: doseUnit ?? this.doseUnit,
      schedule: schedule ?? this.schedule,
      foodInstruction: foodInstruction ?? this.foodInstruction,
      additionalInstructions: additionalInstructions ?? this.additionalInstructions,
      quantity: quantity ?? this.quantity,
      refillThreshold: refillThreshold ?? this.refillThreshold,
      doctorName: doctorName ?? this.doctorName,
      notes: notes ?? this.notes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timeZone: timeZone ?? this.timeZone,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

class MedicationDose {
  const MedicationDose({
    required this.id,
    required this.medicationId,
    required this.userId,
    required this.scheduledAt,
    required this.remindAt,
    required this.status,
    required this.snoozeCount,
    required this.createdAt,
    required this.updatedAt,
    this.actedAt,
    this.notes,
  });

  final String id;
  final String medicationId;
  final String userId;
  final DateTime scheduledAt;
  final DateTime remindAt;
  final DoseStatus status;
  final int snoozeCount;
  final DateTime? actedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicationDose copyWith({
    DateTime? remindAt,
    DoseStatus? status,
    int? snoozeCount,
    DateTime? actedAt,
    String? notes,
    DateTime? updatedAt,
  }) {
    return MedicationDose(
      id: id,
      medicationId: medicationId,
      userId: userId,
      scheduledAt: scheduledAt,
      remindAt: remindAt ?? this.remindAt,
      status: status ?? this.status,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      actedAt: actedAt ?? this.actedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AdherenceSummary {
  const AdherenceSummary({
    required this.scheduled,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.pending,
    required this.snoozed,
  });

  final int scheduled;
  final int taken;
  final int missed;
  final int skipped;
  final int pending;
  final int snoozed;

  int get completed => taken + missed + skipped;

  double get percentage {
    if (completed == 0) return 0;
    return (taken / completed) * 100;
  }
}

class RefillEstimate {
  const RefillEstimate({
    required this.remainingDoses,
    required this.warning,
  });

  final int? remainingDoses;
  final bool warning;
}

class PrescriptionScan {
  const PrescriptionScan({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.imagePath,
    this.extractedJson,
    this.confidence,
    this.confirmed = false,
  });

  final String id;
  final String userId;
  final String? imagePath;
  final String? extractedJson;
  final double? confidence;
  final bool confirmed;
  final DateTime createdAt;
}

class MedicineScan {
  const MedicineScan({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.imagePath,
    this.extractedJson,
    this.confidence,
    this.confirmed = false,
  });

  final String id;
  final String userId;
  final String? imagePath;
  final String? extractedJson;
  final double? confidence;
  final bool confirmed;
  final DateTime createdAt;
}

class Caregiver {
  const Caregiver({
    required this.id,
    required this.ownerUserId,
    required this.caregiverUserId,
    required this.relation,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String caregiverUserId;
  final CaregiverRelation relation;
  final CaregiverPermissionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Subscription {
  const Subscription({
    required this.userId,
    required this.tier,
    required this.updatedAt,
    this.expiresAt,
    this.productId,
  });

  final String userId;
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final String? productId;
  final DateTime updatedAt;

  bool get isPremium => tier == SubscriptionTier.premium;
}

class AiConversation {
  const AiConversation({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TimelineItem {
  const TimelineItem({
    required this.dose,
    required this.medication,
  });

  final MedicationDose dose;
  final Medication medication;
}
