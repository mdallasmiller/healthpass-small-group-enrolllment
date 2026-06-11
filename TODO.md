# HealthPass Enrollment - Progress & TODO

Updated: June 2026 · Live: https://healthpass-enrollment.web.app

The app's functional flow works end to end. This tracks what's left, split by
whether we can do it ourselves or are waiting on the client / Blaze.

---

## Done

**Admin**
- [x] Email/password auth + first-admin bootstrap (dev) + access gate
- [x] Create / edit / delete group; status (draft/active/closed)
- [x] Contribution rates by cooperative level x tier; dental config; ICHRA toggle
- [x] Roster: add manually + CSV import
- [x] Per-employee invite link + access code (auto-generated, copy dialog)
- [x] Enrollment campaign tab: schedule fields + email/SMS template previews + in-person note
- [x] Left sidebar shell; group detail with Plan / Roster / Enrollment tabs

**Employee portal** (opened via invite link + access code)
- [x] Anonymous-auth entry + code validation
- [x] Step 1 personal info (name, DOB, SSN, address, tobacco)
- [x] Step 2 coverage: dependents -> tier, plan (Preventive / + Cooperative), deductible level, live cost
- [x] ICHRA section (when enabled) with "specialist will contact" note
- [x] Dental step (when enabled): enroll + dependents + cost; running total
- [x] Review & sign: acknowledgements + signature pad -> submit -> completion
- [x] Submitted enrollment saved to Firestore; employee status -> completed

**Infra**
- [x] Flutter web + Firebase (Auth, Firestore) wired; Inter/HealthPass theme
- [x] Firestore security rules (dev) deployed
- [x] Deployed to Firebase Hosting (dev project, Spark)

---

## Can do now (no client input, no Blaze)

- [ ] **Per-dependent details** - collect each dependent's name/SSN (outline wants full info, we only capture spouse yes/no + child count)
- [ ] **Admin: view a submitted enrollment** - detail screen showing the employee's selections + signature (admin only sees "Completed" status now)
- [ ] **Google Sheets roster import** - only CSV is done
- [ ] **Signature audit trail** - timestamp + consent-to-esign text + document version captured with the signature (IP capture too, where possible)
- [ ] **PDF confirmation** - generate a signed enrollment PDF from the submission
- [ ] **Write the Mailgun/Twilio sending Cloud Functions** - code can be written now; deploy waits on Blaze
- [ ] **Editable email/SMS templates** - currently static previews
- [ ] **Validation polish** - DOB/age-band checks, SSN, required fields, error states
- [ ] **Design pass** - final polish (deferred until client feedback)

---

## Blocked on Blaze / Cloud Functions

(Spark plan can't deploy Functions. Server-side logic + sending need Blaze.)

- [ ] **Automated email (Mailgun) sending** + `emailSentAt` tracking
- [ ] **Automated SMS (Twilio) sending**
- [ ] **Scheduling** - send on Send Date/Time, Warning Date, End Date (Cloud Scheduler)
- [ ] **Server-side access-code validation** (replace dev client-side check)
- [ ] **Proper first-admin bootstrap function** (replace dev self-grant rule)
- [ ] **Tighten Firestore rules** once flows go through Functions

---

## Security & HIPAA (M9)

- [ ] **Encrypt SSN** (stored as plaintext in dev) + other sensitive fields
- [ ] Lock down rules; remove dev relaxations (admin self-grant, anon read/write)
- [ ] Audit logging
- [ ] HIPAA review + BAA on the production project

---

## Waiting on the client

- [ ] **HAS Group Enrollment Form** fields - to finish the Create Group screen (only name/email/ICHRA placeholders now)
- [ ] **Mailgun** - API key (we lack create permission) + sending domain (region looks US)
- [ ] **Twilio** - sending phone number + (securely) SID/auth token
- [ ] **Signature legal level** - captured + audit trail vs DocuSign-style
- [ ] **Explainer videos** - content for medical/dental/ICHRA sections
- [ ] **Admin access for client testing** - share login or add their UID as admin

---

## Production / launch

- [ ] **Dedicated Firebase project on the client's account** (separate from their existing app), on **Blaze**
- [ ] Point the app to it (`flutterfire configure`) + deploy hosting + functions
- [ ] Custom domain (e.g. enroll.joinhealthpass.com) if desired
- [ ] Move secrets (Mailgun/Twilio) into that project
