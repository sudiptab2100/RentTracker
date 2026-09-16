# RentTracker

A lightweight **Android Flutter** app for flat owners to track rent, backed by
**Firebase** (Authentication + Cloud Firestore). No custom backend.

> First time here? See **[SETUP.md](SETUP.md)** to connect your Firebase project.

## Features
- **Auth**: email/password, Google, and phone (OTP) sign-in.
- **Property hierarchy**: Owner → Buildings → Floors → Apartments.
- **Apartment details**: tenant name, address, contact, WhatsApp & emergency
  numbers (pick from device contacts), security deposit (tracked separately),
  and an effective-dated rent schedule.
- **Monthly rent ledger** (auto-generated lazily on open):
  - electricity bill + arbitrary extra charges,
  - record payments; live balance shown **red** when due and **green** when settled,
  - update rent effective this month or next month,
  - per-apartment rent history and outstanding totals.
- **Dashboard**: portfolio summary and per-building rent status.
- **Reports**: monthly PDF statement, per-apartment & portfolio CSV export.
- **WhatsApp**: share the PDF and send pending-rent reminders via `wa.me`/share sheet.
- **Master export/import (JSON)**: full, lossless backup for migrating to another
  app or a different Firebase project.

## Money & correctness
All amounts are stored as **integer minor units (paise)** to avoid floating-point
errors and formatted as **INR (₹)** for display.

## Architecture
- **State**: Riverpod. **Routing**: go_router (auth-guarded).
- **Data**: owner-scoped Firestore subcollections
  `users/{uid}/buildings/{b}/floors/{f}/apartments/{a}/rentRecords/{yyyy-MM}`.
- **Layers**: `models/` · `repositories/` (Firestore CRUD) · `features/*`
  (UI + controllers) · `services/` (auth, Firebase) · `core/` (money, months).

```
lib/
  core/            money, month keys, validators, config
  models/          Building, Floor, Apartment, RentRecord, ...
  repositories/    Firestore repositories + providers
  services/        auth service, Firebase providers
  features/        auth, dashboard, buildings, floors, apartments,
                   rent, reports, whatsapp, settings
  widgets/         shared UI
  app/             theme, router, root widget
```

## Run
```bash
flutter pub get
flutter run                  # after completing SETUP.md
flutter test                 # unit tests for the rent engine
flutter analyze
flutter build apk --release
```

## Security
Firestore rules (`firestore.rules`) restrict all data to its owner. Deploy with
`firebase deploy --only firestore:rules`.

## Download the app (GitHub Releases)

Release APKs are built and published automatically by GitHub Actions
(`.github/workflows/build-apk.yml`). Once set up, anyone can download the APK
from the repository's **Releases** page.

**One-time setup (secrets):**
```bash
gh auth login                       # authenticate the GitHub CLI
./scripts/setup_ci_secrets.sh       # uploads GOOGLE_SERVICES_JSON + DEBUG_KEYSTORE_BASE64
```
(Or add those two secrets manually in GitHub → Settings → Secrets and variables → Actions.)

**Publish a release:**
```bash
git tag v1.0.0
git push origin v1.0.0              # triggers the build; APK is attached to the Release
```
You can also run the workflow manually (Actions → Build & Release APK → Run
workflow); manual runs upload the APK as a workflow artifact.

The release APK is signed with the debug keystore whose SHA is registered in
Firebase, so Google Sign-In works on the download. For a store release, swap in a
dedicated release keystore and register its SHA.
