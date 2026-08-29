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
- On-device OCR + heuristic extraction with mandatory review before save
- Package scan (never treated as medically certain)
- PDF adherence reports with share/export
- Refill quantity tracking that decreases when a dose is taken
- Family profiles and caregiver invite/share switches (Premium)
- MediPulse AI answers from the saved schedule only
- Cloud sync queue (uploads when Firebase is enabled)
- Subscription entitlements stored per account; ads never on dose confirmation

Not implemented yet (later phases, not claimed complete):

- Firebase Auth / Firestore sync / FCM / Crashlytics
- Google and Apple sign-in (UI present; requires credentials)
- Cloud AI providers (local heuristic extraction is the default)
- MediPulse AI assistant
- Family/caregiver sharing
- RevenueCat billing, ads
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
