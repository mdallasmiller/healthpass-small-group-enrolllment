# Firestore Data Model

> PHI/PII note: `ssn` and other sensitive fields are stored **encrypted** (app-layer envelope
> encryption). Only Cloud Functions decrypt when strictly needed. Employees never access
> Firestore directly — the enrollment portal calls Functions authorized by a unique token + access code.

## `admins/{uid}`
Staff who can use the admin portal.
```
{ email, displayName, role: "admin", createdAt }
```

## `groups/{groupId}`
A small group (employer) being enrolled.
```
{
  name,                       // employer / group name
  contactEmail,               // admin "from" email (from HAS Group Enrollment Form)
  hasFormData: { ... },       // remaining fields from the HAS Group Enrollment Form
  contributionStrategy: { ... },
  ichraEnabled: bool,         // controls whether ICHRA appears in the portal

  // Employee-facing rates entered by the admin, by cooperative level + tier
  medicalRates: {
    "1000": { employeeOnly, spouseChild, family },
    "2500": { employeeOnly, spouseChild, family },
    "4000": { employeeOnly, spouseChild, family }
  },
  dental: {
    option: "cooperative" | "selfFundedBento",
    level: 2500,              // cooperative auto-fills 2500
    rates: { employeeOnly, spouseChild, family }
  },

  status: "draft" | "active" | "closed",
  enrollment: { sendDate, sendTime, warningDate, endDate },
  createdAt, createdBy
}
```

## `groups/{groupId}/employees/{employeeId}`
Roster entry + invitation state.
```
{
  firstName, lastName, email, phone,
  token,                      // opaque unique id used in the enrollment URL
  accessCodeHash,             // hashed access code (never store plaintext)
  invite: { emailSentAt, smsSentAt },
  status: "pending" | "opened" | "in_progress" | "completed",
  createdAt
}
```

## `groups/{groupId}/employees/{employeeId}/enrollment` (single doc)
The submitted enrollment. Written only by Functions.
```
{
  personal: { firstName, middleName, lastName, dob, ssnEnc, address, tobaccoUser },
  dependents: {
    spouse: { firstName, middleName, lastName, ssnEnc, phone, email } | null,
    children: [ { firstName, middleName, lastName, ssnEnc } ]
  },
  medical: { plan: "preventiveOnly" | "preventiveCooperative", tier, level, monthlyRate },
  ichra: { chosen: bool },
  dental: { enrolled: bool, dependents: [...], tier, monthlyRate },
  acknowledgements: { tobacco, preEx, deduction },     // booleans + timestamps
  signaturePath,             // Cloud Storage path to signature image
  confirmationPdfPath,       // Cloud Storage path to generated PDF
  totals: { employeeMonthlyCost },
  submittedAt
}
```

## Cloud Functions (server-side surface)
- `createEnrollmentLinks(groupId)` → generates token + access code per employee
- `validateAccess(token, accessCode)` → returns a short-lived session for the portal
- `getPortalContext(session)` → group rates, ichraEnabled, employee info (no other PHI)
- `saveEnrollmentStep(session, payload)` → validated partial save
- `submitEnrollment(session, payload)` → finalize, generate PDF, mark completed
- `sendInvites(groupId)` → Mailgun + Twilio (scheduled by send/warning/end dates)
- `computeQuote(groupId, selections)` → pricing engine (also used live in the portal)
