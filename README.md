# MediPulse

Never Miss Your Medicine.

Production Flutter app for medication reminders on Android and iOS.

Package ID: `com.wellardislab.medipulse`

## Phase 1 status

Implemented and covered by unit/widget tests:

- Feature-first clean architecture and service abstractions
- Material 3 healthcare theme and reusable components
- Onboarding, local email/password auth, guest mode
- Medication CRUD wizard, scheduling engine, local SQLite
- Local notifications, taken / snooze / skip, missed detection
- Today dashboard, calendar, basic adherence, search, settings
- Privacy-conscious analytics stubs, subscription/ad/AI/OCR interfaces
- Firestore security rules (not deployed until Firebase is configured)

Not implemented yet (later phases, not claimed complete):

- Firebase Auth / Firestore sync / FCM / Crashlytics
- Google and Apple sign-in (UI present; requires credentials)
- Prescription/package OCR + AI extraction
- MediPulse AI assistant
- Family/caregiver sharing
- PDF reports, RevenueCat billing, ads
- Custom branded store icons

## Run

```bash
flutter pub get
flutter test
flutter run
```

Do not pass real secrets into source control. Use `--dart-define` as documented in `.env.example`.

## Legal

Counsel-reviewed Terms and Privacy Policy are required before store submission. In-app copy is a placeholder plus a medical-safety disclaimer.
