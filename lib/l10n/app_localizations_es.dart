// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navHome => 'Inicio';

  @override
  String get navMedications => 'Medicinas';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navReports => 'Informes';

  @override
  String get navProfile => 'Perfil';

  @override
  String get addMedication => 'Añadir';

  @override
  String get addMedicationTooltip => 'Añadir medicamento';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get healthTitle => 'Salud y wearables';

  @override
  String get catalogTitle => 'Catálogo médico con licencia';

  @override
  String get familyTitle => 'Familia y cuidadores';

  @override
  String get joinInvite => 'Unirse con código de invitación';

  @override
  String get sharePercent =>
      'Compartir el porcentaje de adherencia (sin nombres de medicamentos)';

  @override
  String get copyInvite => 'Copiar código de invitación';

  @override
  String get revokeAccess => 'Revocar acceso';

  @override
  String get acceptInvite => 'Aceptar invitación';

  @override
  String get catalogSearchHint => 'Buscar en el catálogo con licencia';

  @override
  String get catalogUnconfigured =>
      'Este compilado no tiene un proveedor de datos médicos con licencia. MediPulse no inventará nombres ni interacciones.';

  @override
  String get catalogEmpty =>
      'El proveedor con licencia no devolvió coincidencias.';

  @override
  String get interactionsUnconfigured =>
      'Las interacciones requieren un proveedor con licencia. Esta pantalla no las adivinará.';

  @override
  String get healthIntro =>
      'Puede registrar en este dispositivo las horas en que tomó una dosis, para Apple Health o Health Connect. Los SDK nativos no están enlazados en este compilado.';

  @override
  String get healthEnabled => 'Registrar horas de dosis tomadas';

  @override
  String get healthIncludeNames =>
      'Incluir nombres de medicamentos cuando haya un SDK nativo (desactivado por defecto)';

  @override
  String get wearableNotice =>
      'No se importan ritmo cardíaco, pasos ni sueño. MediPulse no inventará esas lecturas.';

  @override
  String get nativeHealthUnavailable =>
      'Apple Health / Health Connect no están conectados en este compilado.';

  @override
  String get checkInteractions =>
      'Comprobar interacciones (solo proveedor con licencia)';

  @override
  String get securitySubtitle =>
      'La sesión permanece en este dispositivo. La nube solo sube datos si Firebase está activado.';
}
