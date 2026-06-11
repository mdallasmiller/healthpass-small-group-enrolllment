/**
 * Cloud Functions entry point.
 *
 * Surface (to be implemented across milestones):
 *   - createEnrollmentLinks  (M4)  generate token + access code per employee
 *   - validateAccess         (M4)  token + access code -> short-lived portal session
 *   - getPortalContext       (M5)  group rates, ichraEnabled, employee info
 *   - saveEnrollmentStep     (M5)  validated partial save
 *   - submitEnrollment       (M7)  finalize, generate PDF, mark completed
 *   - sendInvites            (M8)  Mailgun + Twilio, scheduled by send/warning/end dates
 *   - computeQuote           (M1)  pricing engine (also used live in the portal)
 */

import { initializeApp } from "firebase-admin/app";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { computeQuote, QuoteInput } from "./pricing";

initializeApp();

/**
 * Live quote endpoint used by the employee portal as selections change.
 * Stateless: the caller passes the group's rate config + current selections.
 * (Once auth/sessions land in M4–M5 this will resolve rates from the group
 * server-side instead of trusting the client.)
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
