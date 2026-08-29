import 'package:medipulse/shared/models/entities.dart';

class PremiumFeatures {
  static bool canScan(Subscription subscription) => subscription.isPremium;
  static bool canExportPdf(Subscription subscription) => subscription.isPremium;
  static bool canUseFamily(Subscription subscription) => subscription.isPremium;
  static bool canUseAssistant(Subscription subscription) => subscription.isPremium;
  static bool canSyncCloud(Subscription subscription) => subscription.isPremium;
}
