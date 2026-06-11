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
import { computeQuote, QuoteInput } from "./pricing";

initializeApp();

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
 * Stateless for now; M4–M5 will resolve rates from the group server-side.
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
