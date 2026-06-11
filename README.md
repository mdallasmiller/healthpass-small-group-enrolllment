# HealthPass + Health Access — Small Group Enrollment Platform

Web application for enrolling small groups into HealthPass + Health Access benefits.
Admins configure groups and rates, invite employees via secure unique links, and each
employee completes enrollment through a guided portal with live cost calculation.

## Stack

- **Frontend:** Flutter (Web) — `app/` — admin portal + employee enrollment portal
- **Backend:** Firebase Cloud Functions (TypeScript) — `functions/` — pricing engine, unique URL + access code, email/SMS, scheduling
- **Data:** Cloud Firestore — see `docs/DATA-MODEL.md`
- **Storage:** Cloud Storage — signatures, generated confirmation PDFs
- **Hosting:** Firebase Hosting
- **Email/SMS:** Mailgun / Twilio (called from Functions)

## Security model (important)

The employee enrollment portal **never writes to Firestore directly**. All employee/PHI
writes go through validated Cloud Functions (Admin SDK), authorized by the per-employee
unique token + access code. Firestore security rules lock all collections to authenticated
admins only. SSN and other sensitive fields are encrypted at the application layer.
This keeps PHI handling centralized and auditable (HIPAA-oriented design).

## Local setup

```bash
# Tooling: Flutter (web), Firebase CLI, FlutterFire CLI, Node 18+

# 1) Auth
firebase login

# 2) Wire the app to the Firebase project (generates app/lib/firebase_options.dart)
cd app
flutterfire configure --project=<FIREBASE_PROJECT_ID>

# 3) Run the web app
flutter run -d chrome

# 4) Functions
cd ../functions
npm install
npm run build
firebase emulators:start   # local Firestore + Functions
```

## Structure

```
app/                  Flutter Web (admin + employee portals)
functions/            Cloud Functions (TypeScript)
firestore.rules       Firestore security rules (admin-only; employee flows via Functions)
firestore.indexes.json
storage.rules         Storage rules (signatures/PDFs)
firebase.json         Firebase project config
docs/DATA-MODEL.md    Firestore schema
```

## Build milestones

M0 setup · M1 data model + pricing engine · M2 admin group setup · M3 roster ·
M4 unique link + access code · M5 employee portal core · M6 dental + ICHRA ·
M7 confirmation + signature · M8 email/SMS + scheduling · M9 security + QA + deploy
