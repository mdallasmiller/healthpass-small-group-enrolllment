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
 *   - sendInvites           (M8)  Mailgun + Twilio, scheduled by send/warning/end
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { computeQuote, QuoteInput } from "./pricing";

initializeApp();

// Mailgun config. The API key is a secret (set with `firebase functions:secrets:set
// MAILGUN_API_KEY`). Domain/from/region/app URL are non-secret deploy params.
const MAILGUN_API_KEY = defineSecret("MAILGUN_API_KEY");
const MAILGUN_DOMAIN = defineString("MAILGUN_DOMAIN", { default: "" });
const MAILGUN_FROM = defineString("MAILGUN_FROM", { default: "" });
const MAILGUN_REGION = defineString("MAILGUN_REGION", { default: "us" });
const APP_BASE_URL = defineString("APP_BASE_URL", {
  default: "https://healthpass-enrollment.web.app",
});

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
  "Hello [first name] You can now enroll in your new health benefit through HealthPass " +
  "and Health Access Solutions. Our secure enrollment portal will gather your " +
  "information and your plan selection. Enrollment begins today, [Send Date], and will " +
  "end on [End Date]. Detailed information about the plan and the total cost to the " +
  "employee will be presented in this enrollment portal. If you experience any issues, " +
  "please email the HealthPass team at enrollment@joinhealthpass.com. " +
  "[Begin Enrollment button] [unique group URL]. When prompted, use the following " +
  "access code: [access code]";

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
  const db = getFirestore();
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
 * Sends each rostered employee their enrollment invite (link + access code) via
 * Mailgun. Admins only. Generates an access code if one is missing and records
 * invite.emailSentAt per employee.
 *
 * Requires the Blaze plan to deploy, MAILGUN_API_KEY secret set, and
 * MAILGUN_DOMAIN configured. A Mailgun sandbox domain only delivers to
 * authorized recipients.
 */
export const sendInvites = onCall({ secrets: [MAILGUN_API_KEY] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const db = getFirestore();
  const adminDoc = await db.collection("admins").doc(uid).get();
  if (!adminDoc.exists) throw new HttpsError("permission-denied", "Admins only.");

  const groupId = (request.data?.groupId ?? "") as string;
  if (!groupId) throw new HttpsError("invalid-argument", "Missing groupId.");

  const domain = MAILGUN_DOMAIN.value();
  if (!domain) {
    throw new HttpsError("failed-precondition", "MAILGUN_DOMAIN is not configured.");
  }

  const groupRef = db.collection("groups").doc(groupId);
  const groupSnap = await groupRef.get();
  if (!groupSnap.exists) throw new HttpsError("not-found", "Group not found.");
  const group = groupSnap.data() ?? {};
  const schedule = (group.enrollment ?? {}) as Record<string, string>;
  const templates = (group.templates ?? {}) as Record<string, string>;
  const subjectTpl = templates.emailSubject || DEFAULT_EMAIL_SUBJECT;
  const bodyTpl = templates.emailBody || DEFAULT_EMAIL_BODY;

  const empsSnap = await groupRef.collection("employees").get();

  const apiBase =
    MAILGUN_REGION.value().toLowerCase() === "eu"
      ? "https://api.eu.mailgun.net"
      : "https://api.mailgun.net";
  const from = MAILGUN_FROM.value() || `HealthPass Enrollment <postmaster@${domain}>`;
  const auth = "Basic " + Buffer.from(`api:${MAILGUN_API_KEY.value()}`).toString("base64");

  let sent = 0;
  const errors: string[] = [];

  for (const doc of empsSnap.docs) {
    const e = doc.data();
    if (!e.email) continue;
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
    const params = new URLSearchParams({
      from,
      to: `${e.firstName ?? ""} ${e.lastName ?? ""} <${e.email}>`.trim(),
      subject: fillTokens(subjectTpl, tokens),
      text: fillTokens(bodyTpl, tokens),
    });

    const res = await fetch(`${apiBase}/v3/${domain}/messages`, {
      method: "POST",
      headers: { Authorization: auth, "Content-Type": "application/x-www-form-urlencoded" },
      body: params,
    });

    if (res.ok) {
      sent++;
      await doc.ref.update({ "invite.emailSentAt": FieldValue.serverTimestamp() });
    } else {
      errors.push(`${e.email}: HTTP ${res.status}`);
    }
  }

  return { sent, total: empsSnap.size, errors };
});
