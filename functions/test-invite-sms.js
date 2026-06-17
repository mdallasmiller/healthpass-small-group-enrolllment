// Sends a real HealthPass enrollment-invite SMS (link + access code) to a phone,
// using the same message format as the Cloud Function. No Firebase/deploy needed.
//
//   node test-invite-sms.js +1XXXXXXXXXX "<enrollment url>" <ACCESSCODE> [firstName]
//
// Get the URL + code from the app: open the group's Roster, click
// "Send link + code" on an employee, and copy the link and access code shown.
// Reads Twilio creds from .env / .secret.local in this folder.

const fs = require("fs");
const path = require("path");

function loadEnv(file) {
  const out = {};
  try {
    const txt = fs.readFileSync(path.join(__dirname, file), "utf8");
    for (const line of txt.split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m) out[m[1]] = m[2];
    }
  } catch (_) {
    /* file may not exist */
  }
  return out;
}

const env = { ...loadEnv(".env"), ...loadEnv(".secret.local") };
const sid = env.TWILIO_ACCOUNT_SID;
const token = env.TWILIO_AUTH_TOKEN;
const from = env.TWILIO_FROM;

const to = process.argv[2];
const url = process.argv[3];
const code = process.argv[4];
const firstName = process.argv[5] || "there";

if (!sid || !token || !from) {
  console.error("Missing Twilio creds in .env / .secret.local");
  process.exit(1);
}
if (!to || !url || !code) {
  console.error(
    'Usage: node test-invite-sms.js +1XXXXXXXXXX "<enrollment url>" <ACCESSCODE> [firstName]'
  );
  process.exit(1);
}

const body =
  `Hi ${firstName}, enroll in your HealthPass health benefit here: ${url} ` +
  `Access code: ${code}`;

(async () => {
  const params = new URLSearchParams({ To: to, Body: body });
  if (from.startsWith("MG")) params.set("MessagingServiceSid", from);
  else params.set("From", from);

  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization:
          "Basic " + Buffer.from(`${sid}:${token}`).toString("base64"),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params,
    }
  );

  const data = await res.json();
  if (res.ok) {
    console.log("✅ Invite SMS queued. SID:", data.sid, "| Status:", data.status);
    console.log("   Body:", body);
  } else {
    console.error("❌ Failed:", res.status, "-", data.message || JSON.stringify(data));
    if (data.code) console.error("   Twilio error code:", data.code);
  }
})();
