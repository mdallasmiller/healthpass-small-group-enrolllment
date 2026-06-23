/**
 * Cloud Functions entry point.
 *
 * Surface (built out across milestones):
 *   - bootstrapFirstAdmin   (M2)  claim the first admin slot on a fresh project
 *   - computeQuoteFn        (M1)  pricing engine (also used live in the portal)
 *   - createEnrollmentLinks (M4)  generate token + access code per employee
 *   - validateAccess        (M4)  token + access code -> short-lived portal session
 *   - getPortalContext      (M5)  group rates, ichraEnabled, employee info
 *   - saveEnrollmentStep    (M5)  validated partial save
 *   - submitEnrollment      (M7)  finalize, generate PDF, mark completed
 *   - sendInvites           (M8)  SendGrid email + Twilio SMS, per roster
 */

import { initializeApp, getApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { computeQuote, QuoteInput } from "./pricing";

initializeApp();

/// Our data lives in a dedicated named Firestore database ("enrollment"),
/// isolated from the project's default DB used by the other apps.
const enrollmentDb = () => getFirestore(getApp(), "enrollment");

// Email (Twilio SendGrid). The API key is a secret (set with
// `firebase functions:secrets:set SENDGRID_API_KEY`). The From address/name are
// non-secret deploy params (functions/.env). SENDGRID_FROM must be on a domain
// authenticated in SendGrid (e.g. enrollment@joinhealthpass.com).
const SENDGRID_API_KEY = defineSecret("ENROLLMENT_SENDGRID_API_KEY");
const SENDGRID_FROM = defineString("SENDGRID_FROM", { default: "" });
const SENDGRID_FROM_NAME = defineString("SENDGRID_FROM_NAME", {
  default: "HealthPass Enrollment",
});
const APP_BASE_URL = defineString("APP_BASE_URL", {
  default: "https://healthpass-enrollment.web.app",
});

// Twilio config (SMS). The Auth Token is a secret (set with
// `firebase functions:secrets:set TWILIO_AUTH_TOKEN`). The Account SID and the
// sender are non-secret deploy params (functions/.env). TWILIO_FROM is either a
// Twilio phone number in E.164 (e.g. +19714063352) or a Messaging Service SID
// (starts with "MG").
const TWILIO_ACCOUNT_SID = defineString("TWILIO_ACCOUNT_SID", { default: "" });
const TWILIO_FROM = defineString("TWILIO_FROM", { default: "" });
const TWILIO_AUTH_TOKEN = defineSecret("ENROLLMENT_TWILIO_AUTH_TOKEN");

const _codeChars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
function generateAccessCode(len = 6): string {
  let s = "";
  for (let i = 0; i < len; i++) {
    s += _codeChars[Math.floor(Math.random() * _codeChars.length)];
  }
  return s;
}

const DEFAULT_EMAIL_SUBJECT =
  "ENROLL NOW: Your Health Benefit through HealthPass + Health Access";
const DEFAULT_EMAIL_BODY =
  "Hello [first name],\n\n" +
  "You can now enroll in your new health benefit through HealthPass and Health Access " +
  "Solutions. Our secure enrollment portal will gather your information and plan " +
  "selection, and show the total cost to you.\n\n" +
  "Enroll here: [unique group url]\n" +
  "Access code: [access code]\n\n" +
  "Enrollment closes [end date]. If you have any issues, email the HealthPass team at " +
  "enrollment@joinhealthpass.com.";

const DEFAULT_SMS_BODY =
  "Hi [first name], enroll in your HealthPass health benefit here: [unique group url] " +
  "Access code: [access code]";

/**
 * Best-effort normalization of a US phone number to E.164 (+1XXXXXXXXXX).
 * Returns null when the input can't be turned into a plausible number.
 */
function toE164(raw: string): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.startsWith("+")) {
    const digits = trimmed.slice(1).replace(/\D/g, "");
    return digits.length >= 8 ? `+${digits}` : null;
  }
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith("1")) return `+${digits}`;
  return null;
}

/** Replaces [merge tokens] in a template with the employee's values. */
function fillTokens(
  text: string,
  v: { firstName: string; sendDate: string; endDate: string; url: string; code: string }
): string {
  return text
    .replace(/\[first name\]/gi, v.firstName || "there")
    .replace(/\[send date\]/gi, v.sendDate || "today")
    .replace(/\[end date\]/gi, v.endDate || "the close date")
    .replace(/\[begin enrollment button\]/gi, v.url)
    .replace(/\[unique group url\]/gi, v.url)
    .replace(/\[access code\]/gi, v.code);
}

/**
 * Grant the caller the first admin slot. Only succeeds when no admin exists
 * yet; afterwards it just reports whether the caller is already an admin.
 */
export const bootstrapFirstAdmin = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before requesting access.");
  }
  const db = enrollmentDb();
  const admins = db.collection("admins");

  const anyAdmin = await admins.limit(1).get();
  if (!anyAdmin.empty) {
    const me = await admins.doc(uid).get();
    return { granted: me.exists };
  }

  await admins.doc(uid).set({
    email: request.auth?.token.email ?? null,
    displayName: request.auth?.token.name ?? null,
    role: "admin",
    createdAt: FieldValue.serverTimestamp(),
  });
  return { granted: true };
});

/**
 * Live quote endpoint used by the employee portal as selections change.
 * Stateless for now; M4-M5 will resolve rates from the group server-side.
 */
export const computeQuoteFn = onCall((request) => {
  const data = request.data as QuoteInput | undefined;
  if (!data || !data.medicalRates || !data.medicalLevel) {
    throw new HttpsError("invalid-argument", "Missing rate configuration or selections.");
  }
  try {
    return computeQuote(data);
  } catch (e) {
    throw new HttpsError("failed-precondition", (e as Error).message);
  }
});

/**
 * Lets an HR manager (reached via the `?hr=<groupId>` link, signed in
 * anonymously) save company/eligibility/contact details without granting the
 * client direct write access to `groups`. Runs with Admin privileges so the
 * Firestore security rules stay locked down. Only a fixed whitelist of HR
 * fields under `details.*` can be written — contribution strategy, rates and
 * status are never touched.
 */
const HR_STRING_FIELDS = [
  "dba",
  "taxId",
  "fullTimeEmployees",
  "website",
  "businessPhone",
  "addressLine1",
  "addressLine2",
  "city",
  "state",
  "zip",
  "adminFirstName",
  "adminLastName",
  "adminPhone",
  "billingFirstName",
  "billingLastName",
  "billingPhone",
  "billingEmail",
  "eligibilityDefinition",
  "waitingPeriod",
  "waitingPeriodOther",
];

export const updateHrDetails = onCall(async (request) => {
  // Anonymous sign-in is fine here — the unguessable group link is the
  // capability. We only require *some* authenticated session.
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const groupId = (request.data?.groupId ?? "") as string;
  if (!groupId) throw new HttpsError("invalid-argument", "Missing groupId.");

  const details = (request.data?.details ?? {}) as Record<string, unknown>;
  const update: Record<string, unknown> = {};
  for (const f of HR_STRING_FIELDS) {
    if (typeof details[f] === "string") update[`details.${f}`] = details[f];
  }
  if (typeof details.domesticPartners === "boolean") {
    update["details.domesticPartners"] = details.domesticPartners;
  }
  if (Object.keys(update).length === 0) {
    throw new HttpsError("invalid-argument", "No valid fields to update.");
  }

  const db = enrollmentDb();
  const ref = db.collection("groups").doc(groupId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Group not found.");
  await ref.update(update);
  return { ok: true, updated: Object.keys(update).length };
});

/**
 * Sends each rostered employee their enrollment invite (link + access code) via
 * SendGrid email and/or Twilio SMS. Admins only. Generates an access code if one
 * is missing and records invite.emailSentAt / invite.smsSentAt per employee.
 *
 * Requires the Blaze plan to deploy. Email needs SENDGRID_API_KEY (secret) and
 * SENDGRID_FROM (on a SendGrid-authenticated domain). SMS needs TWILIO_AUTH_TOKEN
 * (secret), TWILIO_ACCOUNT_SID and TWILIO_FROM. Each channel is optional; at
 * least one must be configured.
 */
export const sendInvites = onCall(
  { secrets: [SENDGRID_API_KEY, TWILIO_AUTH_TOKEN] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const db = enrollmentDb();
    const adminDoc = await db.collection("admins").doc(uid).get();
    if (!adminDoc.exists) throw new HttpsError("permission-denied", "Admins only.");

    const groupId = (request.data?.groupId ?? "") as string;
    if (!groupId) throw new HttpsError("invalid-argument", "Missing groupId.");
    // Optional: send to just one employee (per-row "Send invitation").
    const onlyEmployeeId = (request.data?.employeeId ?? "") as string;

    // Which delivery channels are configured. Each is optional; at least one
    // must be set up.
    const emailFrom = SENDGRID_FROM.value();
    const emailEnabled = !!emailFrom;
    const twilioSid = TWILIO_ACCOUNT_SID.value();
    const twilioFrom = TWILIO_FROM.value();
    const smsEnabled = !!(twilioSid && twilioFrom);
    if (!emailEnabled && !smsEnabled) {
      throw new HttpsError(
        "failed-precondition",
        "No delivery channel configured. Set SENDGRID_FROM for email and/or " +
          "TWILIO_ACCOUNT_SID + TWILIO_FROM for SMS."
      );
    }

    const groupRef = db.collection("groups").doc(groupId);
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) throw new HttpsError("not-found", "Group not found.");
    const group = groupSnap.data() ?? {};
    const schedule = (group.enrollment ?? {}) as Record<string, string>;
    const templates = (group.templates ?? {}) as Record<string, string>;
    const subjectTpl = templates.emailSubject || DEFAULT_EMAIL_SUBJECT;
    const bodyTpl = templates.emailBody || DEFAULT_EMAIL_BODY;
    const smsTpl = templates.smsBody || DEFAULT_SMS_BODY;

    const empsSnap = await groupRef.collection("employees").get();

    // SMS (Twilio) setup.
    const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`;
    const twilioAuth = smsEnabled
      ? "Basic " +
        Buffer.from(`${twilioSid}:${TWILIO_AUTH_TOKEN.value()}`).toString("base64")
      : "";

    let emailSent = 0;
    let smsSent = 0;
    const errors: string[] = [];

    const targetDocs = onlyEmployeeId
      ? empsSnap.docs.filter((d) => d.id === onlyEmployeeId)
      : empsSnap.docs;

    for (const doc of targetDocs) {
      const e = doc.data();
      if (e.eligible === false) continue; // benefit class ineligible -> no invite

      let code = e.accessCode as string | undefined;
      if (!code) {
        code = generateAccessCode();
        await doc.ref.update({ accessCode: code });
      }

      const url = `${APP_BASE_URL.value()}/?g=${groupId}&e=${doc.id}`;
      const tokens = {
        firstName: (e.firstName ?? "") as string,
        sendDate: schedule.sendDate ?? "",
        endDate: schedule.endDate ?? "",
        url,
        code,
      };

      // Email (SendGrid)
      if (emailEnabled && e.email) {
        const res = await fetch("https://api.sendgrid.com/v3/mail/send", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${SENDGRID_API_KEY.value()}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            personalizations: [
              {
                to: [
                  {
                    email: e.email,
                    name: `${e.firstName ?? ""} ${e.lastName ?? ""}`.trim(),
                  },
                ],
              },
            ],
            from: { email: emailFrom, name: SENDGRID_FROM_NAME.value() },
            subject: fillTokens(subjectTpl, tokens),
            content: [{ type: "text/plain", value: fillTokens(bodyTpl, tokens) }],
          }),
        });
        if (res.ok) {
          emailSent++;
          await doc.ref.update({ "invite.emailSentAt": FieldValue.serverTimestamp() });
        } else {
          errors.push(`email ${e.email}: HTTP ${res.status}`);
        }
      }

      // SMS
      if (smsEnabled) {
        const phone = toE164(
          (e.mobilePhone || e.phone || e.homePhone || "") as string
        );
        if (phone) {
          const params: Record<string, string> = {
            To: phone,
            Body: fillTokens(smsTpl, tokens),
          };
          // A Messaging Service SID (MG...) uses MessagingServiceSid; a plain
          // phone number uses From.
          if (twilioFrom.startsWith("MG")) {
            params.MessagingServiceSid = twilioFrom;
          } else {
            params.From = twilioFrom;
          }
          const res = await fetch(twilioUrl, {
            method: "POST",
            headers: {
              Authorization: twilioAuth,
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: new URLSearchParams(params),
          });
          if (res.ok) {
            smsSent++;
            await doc.ref.update({ "invite.smsSentAt": FieldValue.serverTimestamp() });
          } else {
            errors.push(`sms ${phone}: HTTP ${res.status}`);
          }
        }
      }
    }

    return {
      sent: emailSent + smsSent,
      emailSent,
      smsSent,
      total: targetDocs.length,
      errors,
    };
  }
);
