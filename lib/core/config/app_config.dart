enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.firebaseEnabled,
    required this.aiProvider,
    required this.ocrProvider,
    required this.adsEnabled,
    required this.revenueCatApiKey,
    required this.googleWebClientId,
    required this.apiBaseUrl,
    required this.medicalDataApiKey,
  });

  factory AppConfig.fromEnvironment() {
    final envName = const String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return AppConfig(
      environment: AppEnvironment.values.firstWhere(
        (value) => value.name == envName,
        orElse: () => AppEnvironment.development,
      ),
      firebaseEnabled: const bool.fromEnvironment('FIREBASE_ENABLED'),
      aiProvider: const String.fromEnvironment('AI_PROVIDER', defaultValue: 'none'),
      ocrProvider: const String.fromEnvironment('OCR_PROVIDER', defaultValue: 'none'),
      adsEnabled: const bool.fromEnvironment('ADS_ENABLED'),
      revenueCatApiKey: const String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: ''),
      googleWebClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: ''),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
      medicalDataApiKey: const String.fromEnvironment('MEDICAL_DATA_API_KEY', defaultValue: ''),
    );
  }

  final AppEnvironment environment;
  final bool firebaseEnabled;
  final String aiProvider;
  final String ocrProvider;
  final bool adsEnabled;
  final String revenueCatApiKey;
  final String googleWebClientId;
  final String apiBaseUrl;
  final String medicalDataApiKey;

  bool get cloudAuthAvailable => firebaseEnabled;
  bool get googleSignInConfigured => googleWebClientId.isNotEmpty && firebaseEnabled;
  bool get billingConfigured => revenueCatApiKey.isNotEmpty;
  bool get aiConfigured => aiProvider != 'none';
  bool get ocrConfigured => ocrProvider != 'none';
  bool get medicalCatalogConfigured => apiBaseUrl.isNotEmpty && medicalDataApiKey.isNotEmpty;
}
