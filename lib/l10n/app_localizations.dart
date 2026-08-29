import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('ur'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get navMedications;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @addMedication.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addMedication;

  /// No description provided for @addMedicationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add medication'**
  String get addMedicationTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health & wearables'**
  String get healthTitle;

  /// No description provided for @catalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Licensed medicine catalog'**
  String get catalogTitle;

  /// No description provided for @familyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family & caregivers'**
  String get familyTitle;

  /// No description provided for @joinInvite.
  ///
  /// In en, this message translates to:
  /// **'Join with invite code'**
  String get joinInvite;

  /// No description provided for @sharePercent.
  ///
  /// In en, this message translates to:
  /// **'Share adherence percent (no medicine names)'**
  String get sharePercent;

  /// No description provided for @copyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy invite code'**
  String get copyInvite;

  /// No description provided for @revokeAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get revokeAccess;

  /// No description provided for @acceptInvite.
  ///
  /// In en, this message translates to:
  /// **'Accept invite'**
  String get acceptInvite;

  /// No description provided for @catalogSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the licensed catalog'**
  String get catalogSearchHint;

  /// No description provided for @catalogUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'No licensed medical data provider is configured for this build. MediPulse will not invent medicine names or interactions.'**
  String get catalogUnconfigured;

  /// No description provided for @catalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'The licensed provider returned no matches.'**
  String get catalogEmpty;

  /// No description provided for @interactionsUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'Drug interaction checks need a licensed data provider. This screen will not guess interactions.'**
  String get interactionsUnconfigured;

  /// No description provided for @healthIntro.
  ///
  /// In en, this message translates to:
  /// **'You can opt in to record dose-taken times on this device for Apple Health or Health Connect. Native HealthKit and Health Connect SDKs are not linked in this build.'**
  String get healthIntro;

  /// No description provided for @healthEnabled.
  ///
  /// In en, this message translates to:
  /// **'Record dose-taken times'**
  String get healthEnabled;

  /// No description provided for @healthIncludeNames.
  ///
  /// In en, this message translates to:
  /// **'Include medicine names when a native health SDK is linked (off by default)'**
  String get healthIncludeNames;

  /// No description provided for @wearableNotice.
  ///
  /// In en, this message translates to:
  /// **'Wearable heart rate, steps, and sleep are not imported. MediPulse will not invent those readings.'**
  String get wearableNotice;

  /// No description provided for @nativeHealthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Apple Health / Health Connect are not connected in this build.'**
  String get nativeHealthUnavailable;

  /// No description provided for @checkInteractions.
  ///
  /// In en, this message translates to:
  /// **'Check interactions (licensed provider only)'**
  String get checkInteractions;

  /// No description provided for @securitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Session stays on this device. Cloud sync uploads only when Firebase is enabled.'**
  String get securitySubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
