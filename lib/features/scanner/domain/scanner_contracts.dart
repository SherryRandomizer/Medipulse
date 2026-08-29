/// Phase 2: prescription and package scanning pipeline.
/// AI must never silently create a schedule. User confirmation is required.
class ScannerContracts {
  static const verificationCopy =
      'Please verify the extracted information against your prescription before saving.';

  static const packageUncertainty =
      'Image-based identification is never medically certain. Check the package yourself before saving.';

  static const noSilentSave =
      'MediPulse will not create reminders until you review and confirm these details.';
}
