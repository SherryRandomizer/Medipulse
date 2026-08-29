import 'package:flutter_test/flutter_test.dart';
import 'package:medipulse/core/config/app_config.dart';
import 'package:medipulse/features/catalog/domain/licensed_catalog.dart';
import 'package:medipulse/features/caregivers/domain/caregiver_access_policy.dart';
import 'package:medipulse/features/health/domain/health_sync.dart';
import 'package:medipulse/l10n/app_locales.dart';
import 'package:medipulse/shared/models/entities.dart';

AppConfig _config({String api = '', String key = ''}) {
  return AppConfig(
    environment: AppEnvironment.development,
    firebaseEnabled: false,
    aiProvider: 'none',
    ocrProvider: 'none',
    adsEnabled: false,
    revenueCatApiKey: '',
    googleWebClientId: '',
    apiBaseUrl: api,
    medicalDataApiKey: key,
  );
}

void main() {
  test('unconfigured catalog never invents medicines or interactions', () async {
    const catalog = UnconfiguredLicensedCatalog();
    expect(catalog.isConfigured, isFalse);
    expect(await catalog.search('aspirin'), isEmpty);
    final lookup = await catalog.lookupInteractions(['any-id']);
    expect(lookup.status, InteractionLookupStatus.notConfigured);
    expect(lookup.providerNotes, isEmpty);
  });

  test('http catalog stays silent without provider credentials', () async {
    final catalog = HttpLicensedMedicationCatalog(config: _config());
    expect(catalog.isConfigured, isFalse);
    expect(await catalog.search('ibuprofen'), isEmpty);
    final lookup = await catalog.lookupInteractions(['id']);
    expect(lookup.status, InteractionLookupStatus.notConfigured);
  });

  test('percent share is denied unless accepted and enabled', () {
    final now = DateTime.utc(2026, 6, 1);
    final denied = Caregiver(
      id: 'c1',
      ownerUserId: 'u1',
      displayName: 'Alex',
      relation: CaregiverRelation.spouse,
      status: CaregiverPermissionStatus.accepted,
      shareAdherence: true,
      shareAdherencePercent: false,
      inviteCode: 'ABC',
      createdAt: now,
      updatedAt: now,
    );
    expect(CaregiverAccessPolicy.canViewAdherencePercent(denied), isFalse);
    expect(
      CaregiverAccessPolicy.canViewAdherencePercent(denied.copyWith(shareAdherencePercent: true)),
      isTrue,
    );
  });

  test('native health sdk is not claimed as linked', () {
    const bridge = HealthPlatformBridge();
    expect(bridge.nativeSdkLinked, isFalse);
    expect(
      WearableImportPolicy.notice.toLowerCase().contains('will not invent'),
      isTrue,
    );
  });

  test('locales resolve known codes and fall back to english', () {
    expect(AppLocales.resolve('ur').languageCode, 'ur');
    expect(AppLocales.resolve('xx').languageCode, 'en');
  });
}
