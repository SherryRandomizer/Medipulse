class LegalCopy {
  static const medicalDisclaimer = '''
MediPulse is a medication organization and reminder tool. It is not a doctor, pharmacist, diagnostic system, prescription service, or emergency service.

MediPulse does not prescribe, diagnose, or change a clinician's instructions. Always follow the directions on your prescription label and from your healthcare professional.

If you think you are having a medical emergency, call your local emergency number immediately.
''';

  static const aiSafety = '''
Any scanned or AI-extracted information must be verified by you against the original prescription or packaging before it is saved. MediPulse never independently alters a prescribed regimen.
''';

  static const reportDisclaimer = '''
This report is informational and does not replace medical advice, diagnosis, or treatment.
''';

  static const refillDisclaimer = '''
Remaining-dose estimates are based on the quantity you entered. They are not medical advice and may not match your actual supply.
''';

  static const termsPlaceholder = '''
Terms of Use (placeholder for legal review)

By using MediPulse you agree that the app is provided as a reminder and organization aid only. You are responsible for taking medication as prescribed.

Replace this placeholder with counsel-reviewed Terms of Use before store submission.
''';

  static const privacyPlaceholder = '''
Privacy Policy (placeholder for legal review)

MediPulse treats medication information as sensitive health-related data. We collect only what is needed to provide reminders and optional cloud sync.

Do not log medication names, prescription images, or other health content in ordinary application logs.

Replace this placeholder with a counsel-reviewed Privacy Policy before store submission. Document data processors (Firebase, analytics, AI vendors) once they are enabled.
''';
}
