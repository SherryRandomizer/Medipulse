import 'package:medipulse/shared/models/entities.dart';

abstract class AuthService {
  Stream<UserProfile?> authState();
  Future<UserProfile?> currentUser();
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserProfile> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? timeZone,
  });
  Future<UserProfile> continueAsGuest({required String timeZone});
  Future<void> signOut();
  Future<void> requestPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<UserProfile> signInWithGoogle();
  Future<UserProfile> signInWithApple();
  Future<void> deleteAccount();
  Future<UserProfile> updateProfile(UserProfile profile);
}

abstract class StorageService {
  Future<void> writeSecure(String key, String value);
  Future<String?> readSecure(String key);
  Future<void> deleteSecure(String key);
}

abstract class NotificationService {
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<bool> hasPermission();
  Future<bool> canScheduleExactAlarms();
  Future<bool> requestExactAlarms();
  Future<void> openSystemNotificationSettings();
  Future<void> scheduleDoseReminder({
    required MedicationDose dose,
    required Medication medication,
  });
  Future<void> cancelDose(String doseId);
  Future<void> cancelMedication(
    String medicationId, {
    Set<String> priorDoseIds = const {},
  });
  Future<List<String>> trackedMedicationIds();
  Future<void> cancelAllReminders();
  Future<void> showImmediate({required String title, required String body});
}

abstract class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object>? params});
}

abstract class SubscriptionService {
  Stream<Subscription> watch(String userId);
  Future<Subscription> current(String userId);
  Future<void> restorePurchases();
  Future<void> applyEntitlement(Subscription subscription);
}

abstract class AdService {
  bool adsEnabledFor(Subscription subscription);
}

abstract class AIService {
  bool get isConfigured;
  Future<Map<String, dynamic>> extractPrescription(String imagePath);
  Future<Map<String, dynamic>> extractPackage(String imagePath);
  Future<String> answerScheduleQuestion({
    required String question,
    required String scheduleContext,
  });
}

abstract class OCRService {
  bool get isConfigured;
  Future<String> recognizeText(String imagePath);
}

abstract class MedicationRepository {
  Future<List<Medication>> list(String userId, {bool includeArchived = false});
  Future<Medication?> getById(String id);
  Future<void> save(Medication medication);
  Future<int> activeCount(String userId);
}

abstract class DoseRepository {
  Future<void> replacePending(String medicationId, List<MedicationDose> doses);
  Future<void> save(MedicationDose dose);
  Future<MedicationDose?> getById(String id);
  Future<List<MedicationDose>> forUser(
    String userId, {
    DateTime? from,
    DateTime? to,
  });
  Future<List<MedicationDose>> pending(String userId);
}
