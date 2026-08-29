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
import 'package:medipulse/shared/services/phase1_adapters.dart';
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

final subscriptionServiceProvider = Provider<SubscriptionService>((_) => LocalSubscriptionService());

final adServiceProvider = Provider<AdService>((_) => NoOpAdService());

final aiServiceProvider = Provider<AIService>((_) => UnconfiguredAIService());

final ocrServiceProvider = Provider<OCRService>((_) => UnconfiguredOCRService());

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
