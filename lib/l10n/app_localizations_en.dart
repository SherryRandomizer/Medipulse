// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navMedications => 'Medications';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navReports => 'Reports';

  @override
  String get navProfile => 'Profile';

  @override
  String get addMedication => 'Add';

  @override
  String get addMedicationTooltip => 'Add medication';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageTitle => 'Language';

  @override
  String get healthTitle => 'Health & wearables';

  @override
  String get catalogTitle => 'Licensed medicine catalog';

  @override
  String get familyTitle => 'Family & caregivers';

  @override
  String get joinInvite => 'Join with invite code';

  @override
  String get sharePercent => 'Share adherence percent (no medicine names)';

  @override
  String get copyInvite => 'Copy invite code';

  @override
  String get revokeAccess => 'Revoke access';

  @override
  String get acceptInvite => 'Accept invite';

  @override
  String get catalogSearchHint => 'Search the licensed catalog';

  @override
  String get catalogUnconfigured =>
      'No licensed medical data provider is configured for this build. MediPulse will not invent medicine names or interactions.';

  @override
  String get catalogEmpty => 'The licensed provider returned no matches.';

  @override
  String get interactionsUnconfigured =>
      'Drug interaction checks need a licensed data provider. This screen will not guess interactions.';

  @override
  String get healthIntro =>
      'You can opt in to record dose-taken times on this device for Apple Health or Health Connect. Native HealthKit and Health Connect SDKs are not linked in this build.';

  @override
  String get healthEnabled => 'Record dose-taken times';

  @override
  String get healthIncludeNames =>
      'Include medicine names when a native health SDK is linked (off by default)';

  @override
  String get wearableNotice =>
      'Wearable heart rate, steps, and sleep are not imported. MediPulse will not invent those readings.';

  @override
  String get nativeHealthUnavailable =>
      'Apple Health / Health Connect are not connected in this build.';

  @override
  String get checkInteractions => 'Check interactions (licensed provider only)';

  @override
  String get securitySubtitle =>
      'Session stays on this device. Cloud sync uploads only when Firebase is enabled.';
}
