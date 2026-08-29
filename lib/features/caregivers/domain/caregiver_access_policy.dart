import 'package:medipulse/shared/models/entities.dart';

class CaregiverAccessPolicy {
  static const description =
      'Caregivers receive only the adherence alerts you choose to share. Access is revoked when you remove permission.';

  static bool canReceiveAdherenceAlert(Caregiver caregiver) {
    return caregiver.status == CaregiverPermissionStatus.accepted && caregiver.shareAdherence;
  }

  static String missedAlertBody({
    required String firstName,
    required DateTime scheduledAt,
  }) {
    final hour = scheduledAt.toLocal().hour;
    final minute = scheduledAt.toLocal().minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    var displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    return '$firstName has not confirmed the $displayHour:$minute $suffix medication.';
  }
}
