# Store listing placeholders

Replace every field with counsel-reviewed copy before submission. Do not claim MediPulse is a medical device or a substitute for a clinician.

## Google Play

- **App name:** MediPulse
- **Short description:** Never miss your medicine. Local reminders for the doses you save.
- **Full description:** MediPulse helps you organize medication times and mark doses taken, missed, skipped, or snoozed. Scanning and AI only prefill fields you must confirm. The app is not a doctor, pharmacist, or emergency service.
- **Category:** Medical (confirm with Play policy for reminder apps)
- **Content rating:** complete the IARC questionnaire
- **Privacy policy URL:** required before release
- **Data safety:** medication data stays on device unless the user enables cloud services you later configure

## App Store

- **Name:** MediPulse
- **Subtitle:** Never miss your medicine
- **Promotional text:** Reminders for the schedule you enter. You confirm every scanned field.
- **Description:** same medical-safety framing as Play
- **Keywords:** medication,reminder,dose,adherence
- **Support URL / marketing URL:** wellardislab.com (confirm)
- **Privacy policy URL:** required
- **App Privacy:** camera and photos only for optional prescription/package scan; health data is not used for tracking

## Screenshots

Capture Home (today), Add medication, Calendar, and Reports with the medical disclaimer visible.

## Android release signing

1. Copy `android/key.properties.example` to `android/key.properties` (gitignored).
2. Point `storeFile` at your upload keystore. Never commit `.jks` or `key.properties`.
3. Without that file, `flutter build apk --release` still uses the debug keystore so local testing works — do not upload that artifact to Play.
4. Prefer `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`.
