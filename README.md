# MediPulse

Never Miss Your Medicine.

Production Flutter app for medication reminders on Android and iOS.

Package ID: `com.wellardislab.medipulse`

## Status

Implemented and covered by unit/widget tests:

- Feature-first architecture, Material 3 theme, onboarding, local auth, guest mode
- Medication CRUD, scheduling engine, SQLite, local notifications, taken / snooze / skip
- Dashboard, calendar, adherence, scanning with mandatory review, PDF reports, refills
- Family profiles, caregiver invites, missed-dose alerts without medicine names
- MediPulse AI answers from the saved schedule only
- Cloud sync queue (uploads when Firebase is enabled)
- Subscription entitlements stored per account; ads never on dose confirmation
- English, Spanish, Urdu, and Arabic UI for navigation, settings, catalog, health, and family
- Licensed medicine catalog **interface** (empty unless `API_BASE_URL` and `MEDICAL_DATA_API_KEY` are set)
- Health / wearable **opt-in journal** of dose-taken times (no invented vitals; native Health Connect / HealthKit SDKs are not linked)
- Branded launcher and splash mark, iOS privacy manifest, and Play/App Store listing placeholders
- Profile name, optional photo and date of birth, and time zone; medication search includes archived records
- Exact-alarm request, iOS reminder actions, and applying Taken/Snooze/Skip if a notification was tapped while the app was closed
- Optional redacted crash reports via `SENTRY_DSN` (error type and MediPulse frames only; medicine names stripped)

Not implemented yet (not claimed complete):

- Firebase Auth / Firestore sync / FCM / Crashlytics
- Google and Apple sign-in (UI present; requires credentials)
- Cloud AI providers (local heuristic extraction is the default)
- RevenueCat / store billing and a production ads SDK
- A licensed drug database or interaction feed (requires a contracted provider)
- Native Apple Health / Health Connect / wearable SDKs
- Counsel-reviewed Terms, Privacy Policy, and store privacy URLs

## Run

```bash
flutter pub get
flutter test
flutter run
```

Do not pass real secrets into source control. Use `--dart-define` as documented in `.env.example`.

## Legal

Counsel-reviewed Terms and Privacy Policy are required before store submission. In-app copy is a placeholder plus a medical-safety disclaimer.
