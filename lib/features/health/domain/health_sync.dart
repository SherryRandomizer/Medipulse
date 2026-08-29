import 'package:clock/clock.dart';
import 'package:medipulse/core/storage/local_database.dart';
import 'package:uuid/uuid.dart';

class HealthSyncPreference {
  const HealthSyncPreference({
    required this.userId,
    required this.enabled,
    required this.includeMedicineNames,
    required this.updatedAt,
  });

  final String userId;
  final bool enabled;
  final bool includeMedicineNames;
  final DateTime updatedAt;
}

class WearableImportPolicy {
  static const notice =
      'Wearable heart rate, steps, and sleep are not imported. MediPulse will not invent those readings.';
}

class HealthPlatformBridge {
  const HealthPlatformBridge();

  bool get nativeSdkLinked => false;

  Future<bool> isAvailable() async => false;
}

class HealthSyncService {
  HealthSyncService({
    required LocalDatabase database,
    HealthPlatformBridge? platform,
  }) : _db = database,
       _platform = platform ?? const HealthPlatformBridge();

  final LocalDatabase _db;
  final HealthPlatformBridge _platform;
  final _uuid = const Uuid();

  bool get nativeSdkLinked => _platform.nativeSdkLinked;

  Future<HealthSyncPreference> prefs(String userId) async {
    final row = await _db.healthPrefRow(userId);
    if (row == null) return defaultPrefs(userId);
    return HealthSyncPreference(
      userId: userId,
      enabled: row.enabled,
      includeMedicineNames: row.includeNames,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> savePrefs(HealthSyncPreference prefs) {
    return _db.upsertHealthPrefs(
      userId: prefs.userId,
      enabled: prefs.enabled,
      includeNames: prefs.includeMedicineNames,
      updatedAt: prefs.updatedAt,
    );
  }

  Future<void> onDoseTaken({
    required String userId,
    required DateTime takenAt,
  }) async {
    final prefs = await _db.healthPrefRow(userId);
    if (prefs == null || !prefs.enabled) return;
    await _db.insertHealthEvent(
      id: _uuid.v4(),
      userId: userId,
      takenAt: takenAt.toUtc(),
    );
  }

  Future<List<DateTime>> recentTakenTimes(String userId) {
    return _db.healthEventTimes(userId);
  }

  HealthSyncPreference defaultPrefs(String userId) {
    return HealthSyncPreference(
      userId: userId,
      enabled: false,
      includeMedicineNames: false,
      updatedAt: clock.now().toUtc(),
    );
  }
}
