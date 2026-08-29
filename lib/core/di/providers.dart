import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medipulse/core/config/app_config.dart';
import 'package:medipulse/core/notifications/local_notification_service.dart';
import 'package:medipulse/core/storage/local_database.dart';
import 'package:medipulse/core/storage/secure_storage_service.dart';
import 'package:medipulse/features/adherence/domain/adherence_calculator.dart';
import 'package:medipulse/features/adherence/domain/refill_calculator.dart';
import 'package:medipulse/features/authentication/data/local_auth_service.dart';
import 'package:medipulse/features/medications/data/sqlite_repositories.dart';
import 'package:medipulse/features/medications/domain/medication_coordinator.dart';
import 'package:medipulse/features/medications/domain/scheduling_engine.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/features/scanner/data/heuristic_ai_service.dart';
import 'package:medipulse/features/scanner/data/mlkit_ocr_service.dart';
import 'package:medipulse/features/scanner/domain/scanner_pipeline.dart';
import 'package:medipulse/features/catalog/domain/licensed_catalog.dart';
import 'package:medipulse/features/caregivers/domain/caregiver_service.dart';
import 'package:medipulse/features/health/domain/health_sync.dart';
import 'package:medipulse/shared/services/phase1_adapters.dart';
import 'package:medipulse/shared/services/phase3_adapters.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

final appConfigProvider = Provider<AppConfig>((_) => AppConfig.fromEnvironment());

final localDatabaseProvider = Provider<LocalDatabase>((_) => LocalDatabase());

final storageServiceProvider = Provider<StorageService>((_) => SecureStorageService());

final authServiceProvider = Provider<AuthService>((ref) {
  return LocalAuthService(
    database: ref.watch(localDatabaseProvider),
    storage: ref.watch(storageServiceProvider),
    config: ref.watch(appConfigProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>(
  (_) => LocalNotificationService(),
);

final analyticsServiceProvider = Provider<AnalyticsService>((_) => const PrivacyAnalyticsService());

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SqliteSubscriptionService(
    database: ref.watch(localDatabaseProvider),
    config: ref.watch(appConfigProvider),
  );
});

final adServiceProvider = Provider<AdService>(
  (ref) => ConfigAdService(ref.watch(appConfigProvider)),
);

final caregiverServiceProvider = Provider<CaregiverAlertSink>((ref) {
  return CaregiverAlertSink(
    database: ref.watch(localDatabaseProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});

final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  return HealthSyncService(database: ref.watch(localDatabaseProvider));
});

final licensedCatalogProvider = Provider<LicensedMedicationCatalog>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.medicalCatalogConfigured) {
    return HttpLicensedMedicationCatalog(config: config);
  }
  return const UnconfiguredLicensedCatalog();
});

final cloudSyncServiceProvider = Provider<LocalCloudSyncService>((ref) {
  return LocalCloudSyncService(
    database: ref.watch(localDatabaseProvider),
    config: ref.watch(appConfigProvider),
  );
});

final aiServiceProvider = Provider<AIService>((_) => HeuristicAiService());

final ocrServiceProvider = Provider<OCRService>((_) => MlKitOcrService());

final scannerPipelineProvider = Provider<ScannerPipeline>((ref) {
  return ScannerPipeline(
    ocr: ref.watch(ocrServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
});

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => SqliteMedicationRepository(ref.watch(localDatabaseProvider)),
);

final doseRepositoryProvider = Provider<DoseRepository>(
  (ref) => SqliteDoseRepository(ref.watch(localDatabaseProvider)),
);

final schedulingEngineProvider = Provider<SchedulingEngine>((_) => SchedulingEngine());

final adherenceCalculatorProvider = Provider<AdherenceCalculator>((_) => AdherenceCalculator());

final refillCalculatorProvider = Provider<RefillCalculator>((_) => RefillCalculator());

final medicationCoordinatorProvider = Provider<MedicationCoordinator>((ref) {
  return MedicationCoordinator(
    medications: ref.watch(medicationRepositoryProvider),
    doses: ref.watch(doseRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
    subscriptions: ref.watch(subscriptionServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
    caregiverAlerts: ref.watch(caregiverServiceProvider),
    healthSync: ref.watch(healthSyncServiceProvider),
    refillCalculator: ref.watch(refillCalculatorProvider),
    engine: ref.watch(schedulingEngineProvider),
  );
});

final sessionProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(authServiceProvider).currentUser();
});

class SessionController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() => ref.read(authServiceProvider).currentUser();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authServiceProvider).currentUser());
  }

  Future<void> setUser(UserProfile? user) async {
    state = AsyncData(user);
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, UserProfile?>(
  SessionController.new,
);
