# School Inventory

Janitorial stock inventory for **Fatima Fertilizer School** (HomiLabs), usable by any school.
Staff demand on paper → **incharge approves** in the app → **supervisor issues** → stock and an audit
ledger update automatically. Low-stock alerts, receipts with approval, physical-count corrections,
monthly reports with CSV export. English, Android.

- **Package:** `com.homilabs.school_inventory` · min Android 6.0 (API 23)
- **Firebase project:** `school-inventory-homilabs` (owner account homilabs.smc@gmail.com), Firestore in `asia-south1`
- **Design, roles, data model, V2 hooks:** [docs/DESIGN.md](docs/DESIGN.md)

## First use (Fatima Fertilizer School)
1. The incharge (admin) installs the app → **Create account** → **Set up a new school** →
   "Fatima Fertilizer School" (keep "standard janitorial item list" ticked). She is now incharge + admin.
2. **More → Users & roles** shows the 6-letter **school code**. Give it to the supervisor.
3. Supervisor installs → creates account → **Join your school** with the code, as *Janitorial Supervisor*.
   Admin approves under *Users & roles*.
4. Supervisor adds janitorial staff (**More → Janitorial staff**) and records the opening stock
   (**Receive stock → "Opening stock"**); the incharge approves it.
5. Daily: supervisor enters each paper slip → incharge approves → supervisor issues.
6. When the incharge rotates: the admin opens *Users & roles*, sets the new teacher to **Incharge** and
   herself to whatever role suits — admin rights stay with her.

## Repository map
```
lib/
  core/        Result/AppFailure, Clock
  domain/      models, roles + permission table, pure stock logic, default item list
  data/        AccountRepository (auth, schools, members) · InventoryRepository (stock single write path)
  app/         providers (session gate, DI), app shell + theme
  features/    auth · onboarding · dashboard · demands · items · receipts · staff · members · reports · settings
firestore/     firestore.rules · firestore.indexes.json
tests/rules/   adversarial rules tests (emulator)
test/          unit tests (permissions, stock logic)
scripts/       backup_school_inventory.sh (local archive + Google Drive + git push)
```

## Commands
```bash
flutter pub get
flutter analyze && flutter test
# Firestore rules tests (needs JDK 21):
JAVA_HOME=$HOME/tools/jdk-21 PATH=$HOME/tools/jdk-21/bin:$PATH firebase emulators:exec --only firestore --project demo-school-inventory "npm --prefix tests/rules test"
# Deploy rules + indexes:
firebase deploy --only firestore --project school-inventory-homilabs --account homilabs.smc@gmail.com
# Build:
flutter build apk --release        # sideload
flutter build appbundle --release  # Play Store (needs a release signing key first)
# Backup (local + Drive + git):
scripts/backup_school_inventory.sh
```

`android/app/google-services.json` is **not in git** (public repo). It is in the local/Drive backups, or
re-download it with `firebase apps:sdkconfig ANDROID --project school-inventory-homilabs --account homilabs.smc@gmail.com`.
