import 'package:clock/clock.dart';
import 'package:medipulse/core/config/app_config.dart';
import 'package:medipulse/core/errors/app_failure.dart';
import 'package:medipulse/core/storage/local_database.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';
import 'package:uuid/uuid.dart';

class SqliteSubscriptionService implements SubscriptionService {
  SqliteSubscriptionService({required LocalDatabase database, required AppConfig config})
    : _db = database,
      _config = config;

  final LocalDatabase _db;
  final AppConfig _config;

  @override
  Stream<Subscription> watch(String userId) async* {
    yield await current(userId);
  }

  @override
  Future<Subscription> current(String userId) async {
    return await _db.subscriptionFor(userId) ??
        Subscription(userId: userId, tier: SubscriptionTier.free, updatedAt: clock.now().toUtc());
  }

  @override
  Future<void> restorePurchases() async {
    if (!_config.billingConfigured) {
      throw const ConfigurationFailure(
        'Restore purchases needs App Store / Google Play billing (RevenueCat or native) to be configured.',
      );
    }
  }

  @override
  Future<void> applyEntitlement(Subscription subscription) {
    return _db.upsertSubscription(subscription);
  }
}

class LocalCloudSyncService {
  LocalCloudSyncService({required LocalDatabase database, required AppConfig config})
    : _db = database,
      _config = config;

  final LocalDatabase _db;
  final AppConfig _config;
  final _uuid = const Uuid();

  Future<void> enqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return _db.enqueueSync(
      id: _uuid.v4(),
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
    );
  }

  Future<int> pendingCount(String userId) async {
    return (await _db.pendingSync(userId)).length;
  }

  Future<void> flush(String userId) async {
    if (!_config.firebaseEnabled) {
      throw const ConfigurationFailure(
        'Cloud sync is queued on this device. It uploads when Firebase is enabled for this build.',
      );
    }
  }
}

class ConfigAdService implements AdService {
  ConfigAdService(this._config);
  final AppConfig _config;

  @override
  bool adsEnabledFor(Subscription subscription) {
    if (subscription.isPremium) return false;
    return _config.adsEnabled;
  }
}
