// Quick standalone SendGrid email test — no Firebase needed.
//
//   node test-email.js you@example.com [firstName]
//
// Reads SENDGRID_FROM + SENDGRID_FROM_NAME from .env and SENDGRID_API_KEY from
// .secret.local. Put your real SendGrid API key in .secret.local first.

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
const apiKey = env.SENDGRID_API_KEY;
const from = env.SENDGRID_FROM;
const fromName = env.SENDGRID_FROM_NAME || "HealthPass Enrollment";

const to = process.argv[2];
const firstName = process.argv[3] || "there";

if (!apiKey || !from) {
  console.error("Missing SENDGRID_API_KEY (.secret.local) or SENDGRID_FROM (.env)");
  process.exit(1);
}
if (!to) {
  console.error("Usage: node test-email.js you@example.com [firstName]");
  process.exit(1);
}

(async () => {
  const res = await fetch("https://api.sendgrid.com/v3/mail/send", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: to, name: firstName }] }],
      from: { email: from, name: fromName },
      subject: "HealthPass enrollment — test email",
      content: [
        {
          type: "text/plain",
          value:
            `Hi ${firstName}, this is a test from HealthPass enrollment. ` +
            `If you got this, SendGrid email is working.`,
        },
      ],
    }),
  });

  if (res.ok) {
    console.log("✅ Email accepted by SendGrid (HTTP", res.status + "). Check the inbox.");
  } else {
    const body = await res.text();
    console.error("❌ Failed:", res.status, "-", body);
  }
})();
