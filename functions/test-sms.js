// Quick standalone Twilio SMS test — no Firebase needed.
//
//   node test-sms.js +1XXXXXXXXXX
//
// Reads TWILIO_ACCOUNT_SID + TWILIO_FROM from .env and TWILIO_AUTH_TOKEN from
// .secret.local (the same files the Cloud Function uses). Put your REAL Twilio
// values in those files first, then run this with your phone number.

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

if (!sid || !token || !from) {
  console.error(
    "Missing TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM in .env / .secret.local"
  );
  process.exit(1);
}
if (!to) {
  console.error("Usage: node test-sms.js +1XXXXXXXXXX");
  process.exit(1);
}

(async () => {
  const params = new URLSearchParams({
    To: to,
    Body: "HealthPass test SMS — it works! ✅",
  });
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
    console.log("✅ Sent. Message SID:", data.sid, "| Status:", data.status);
  } else {
    console.error("❌ Failed:", res.status, "-", data.message || JSON.stringify(data));
    if (data.code) console.error("   Twilio error code:", data.code);
  }
})();
