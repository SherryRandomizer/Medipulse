// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navMedications => 'الأدوية';

  @override
  String get navCalendar => 'التقويم';

  @override
  String get navReports => 'التقارير';

  @override
  String get navProfile => 'الملف';

  @override
  String get addMedication => 'إضافة';

  @override
  String get addMedicationTooltip => 'إضافة دواء';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get languageTitle => 'اللغة';

  @override
  String get healthTitle => 'الصحة والأجهزة القابلة للارتداء';

  @override
  String get catalogTitle => 'كتالوج أدوية مرخّص';

  @override
  String get familyTitle => 'العائلة ومقدمو الرعاية';

  @override
  String get joinInvite => 'الانضمام برمز الدعوة';

  @override
  String get sharePercent => 'مشاركة نسبة الالتزام (بدون أسماء الأدوية)';

  @override
  String get copyInvite => 'نسخ رمز الدعوة';

  @override
  String get revokeAccess => 'إلغاء الوصول';

  @override
  String get acceptInvite => 'قبول الدعوة';

  @override
  String get catalogSearchHint => 'البحث في الكتالوج المرخّص';

  @override
  String get catalogUnconfigured =>
      'لا يوجد مزوّد بيانات طبية مرخّص لهذا الإصدار. لن يخترع MediPulse أسماء أدوية أو تداخلات.';

  @override
  String get catalogEmpty => 'لم يُرجع المزوّد المرخّص أي نتائج.';

  @override
  String get interactionsUnconfigured =>
      'فحص التداخلات يحتاج مزوّدًا مرخّصًا. لن تخمّن هذه الشاشة التداخلات.';

  @override
  String get healthIntro =>
      'يمكنك تسجيل أوقات الجرعات على هذا الجهاز لـ Apple Health أو Health Connect. حزم HealthKit وHealth Connect الأصلية غير مربوطة في هذا الإصدار.';

  @override
  String get healthEnabled => 'تسجيل أوقات الجرعات المتناولة';

  @override
  String get healthIncludeNames =>
      'تضمين أسماء الأدوية عند ربط حزمة صحية أصلية (إيقاف افتراضيًا)';

  @override
  String get wearableNotice =>
      'لا يُستورد معدل القلب أو الخطوات أو النوم. لن يخترع MediPulse تلك القراءات.';

  @override
  String get nativeHealthUnavailable =>
      'Apple Health / Health Connect غير متصلين في هذا الإصدار.';

  @override
  String get checkInteractions => 'فحص التداخلات (مزوّد مرخّص فقط)';

  @override
  String get securitySubtitle =>
      'تبقى الجلسة على هذا الجهاز. تُرفع المزامنة السحابية فقط عند تفعيل Firebase.';
}
