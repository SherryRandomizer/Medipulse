// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get navHome => 'ہوم';

  @override
  String get navMedications => 'ادویات';

  @override
  String get navCalendar => 'کیلنڈر';

  @override
  String get navReports => 'رپورٹس';

  @override
  String get navProfile => 'پروفائل';

  @override
  String get addMedication => 'شامل کریں';

  @override
  String get addMedicationTooltip => 'دوا شامل کریں';

  @override
  String get settingsTitle => 'ترتیبات';

  @override
  String get languageTitle => 'زبان';

  @override
  String get healthTitle => 'صحت اور پہننے والے آلات';

  @override
  String get catalogTitle => 'لائسنس یافتہ دوا کی فہرست';

  @override
  String get familyTitle => 'خاندان اور نگہداشت کرنے والے';

  @override
  String get joinInvite => 'دعوتی کوڈ سے شامل ہوں';

  @override
  String get sharePercent => 'پابندی کی شرح شیئر کریں (دوا کے نام نہیں)';

  @override
  String get copyInvite => 'دعوتی کوڈ کاپی کریں';

  @override
  String get revokeAccess => 'رسائی واپس لیں';

  @override
  String get acceptInvite => 'دعوت قبول کریں';

  @override
  String get catalogSearchHint => 'لائسنس یافتہ فہرست میں تلاش';

  @override
  String get catalogUnconfigured =>
      'اس بلڈ میں لائسنس یافتہ طبی ڈیٹا فراہم کنندہ نہیں ہے۔ میڈی پلس دوا کے نام یا تعامل خود سے نہیں بنائے گا۔';

  @override
  String get catalogEmpty => 'لائسنس یافتہ فراہم کنندہ نے کوئی نتیجہ نہیں دیا۔';

  @override
  String get interactionsUnconfigured =>
      'دوا کے تعامل کے لیے لائسنس یافتہ فراہم کنندہ درکار ہے۔ یہ اسکرین اندازہ نہیں لگائے گی۔';

  @override
  String get healthIntro =>
      'آپ اس ڈیوائس پر لی گئی خوراک کے اوقات ریکارڈ کر سکتے ہیں تاکہ Apple Health یا Health Connect کے لیے تیار رہیں۔ اس بلڈ میں نیٹو SDK منسلک نہیں ہیں۔';

  @override
  String get healthEnabled => 'لی گئی خوراک کے اوقات ریکارڈ کریں';

  @override
  String get healthIncludeNames =>
      'نیٹو ہیلتھ SDK منسلک ہو تو دوا کے نام شامل کریں (پہلے سے بند)';

  @override
  String get wearableNotice =>
      'دل کی دھڑکن، قدم اور نیند درآمد نہیں ہوتے۔ میڈی پلس یہ ریڈنگز خود سے نہیں بنائے گا۔';

  @override
  String get nativeHealthUnavailable =>
      'اس بلڈ میں Apple Health / Health Connect منسلک نہیں ہیں۔';

  @override
  String get checkInteractions =>
      'تعامل چیک کریں (صرف لائسنس یافتہ فراہم کنندہ)';

  @override
  String get securitySubtitle =>
      'سیشن اسی ڈیوائس پر رہتا ہے۔ کلاؤڈ صرف تب اپلوڈ ہوتا ہے جب Firebase آن ہو۔';
}
