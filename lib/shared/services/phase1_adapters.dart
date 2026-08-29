import 'package:clock/clock.dart';
import 'package:medipulse/shared/models/entities.dart';
import 'package:medipulse/shared/services/service_interfaces.dart';

class PrivacyAnalyticsService implements AnalyticsService {
  const PrivacyAnalyticsService();

  static const allowed = {
    'app_open',
    'onboarding_complete',
    'medication_created',
    'medication_taken',
    'medication_missed',
    'medication_skipped',
    'prescription_scan_started',
    'prescription_scan_completed',
    'subscription_screen_viewed',
    'subscription_started',
    'subscription_cancelled',
    'caregiver_invited',
    'ai_question_asked',
  };

  @override
  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    if (!allowed.contains(name)) return;
    if (params != null) {
      for (final key in params.keys) {
        final lower = key.toLowerCase();
        if (lower.contains('med') ||
            lower.contains('dose') ||
            lower.contains('prescription') ||
            lower.contains('name')) {
          return;
        }
      }
    }
  }
}

class LocalSubscriptionService implements SubscriptionService {
  @override
  Stream<Subscription> watch(String userId) async* {
    yield await current(userId);
  }

  @override
  Future<Subscription> current(String userId) async {
    return Subscription(
      userId: userId,
      tier: SubscriptionTier.free,
      updatedAt: clock.now().toUtc(),
    );
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> applyEntitlement(Subscription subscription) async {}
}

class NoOpAdService implements AdService {
  @override
  bool adsEnabledFor(Subscription subscription) => false;
}

class UnconfiguredAIService implements AIService {
  @override
  bool get isConfigured => false;

  @override
  Future<Map<String, dynamic>> extractPrescription(String imagePath) {
    throw UnimplementedError('Configure an AI provider before using prescription scanning.');
  }

  @override
  Future<Map<String, dynamic>> extractPackage(String imagePath) {
    throw UnimplementedError('Configure an AI provider before using package scanning.');
  }

  @override
  Future<String> answerScheduleQuestion({
    required String question,
    required String scheduleContext,
  }) {
    throw UnimplementedError('Configure an AI provider before using MediPulse AI.');
  }
}

class UnconfiguredOCRService implements OCRService {
  @override
  bool get isConfigured => false;

  @override
  Future<String> recognizeText(String imagePath) {
    throw UnimplementedError('Configure an OCR provider before scanning.');
  }
}
