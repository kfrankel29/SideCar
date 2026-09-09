import {createRequire} from "node:module";
import {chmod, readFile, unlink, writeFile} from "node:fs/promises";
import {createHash} from "node:crypto";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const androidAppId = "1:766275767825:android:b2109df465aa77ea3cabb0";
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const recipient = process.env.SIDECAR_EMAIL_SMOKE_RECIPIENT?.trim().toLowerCase();
const fixturePath = process.env.SIDECAR_FEEDBACK_FIXTURE_PATH ??
  "/tmp/sidecar-feedback-acceptance.json";
const firebaseConfigPath = process.env.SIDECAR_FIREBASE_CONFIG;
const credentialPath = "/tmp/sidecar-email-smoke-firebase-adc.json";

if (!firebaseToolsRoot || !recipient || !firebaseConfigPath) {
  throw new Error(
    "SIDECAR_FIREBASE_TOOLS_ROOT, SIDECAR_EMAIL_SMOKE_RECIPIENT, and " +
      "SIDECAR_FIREBASE_CONFIG are required.",
  );
}

const [fixture, firebaseConfig] = await Promise.all([
  readFile(fixturePath, "utf8").then(JSON.parse),
  readFile(firebaseConfigPath, "utf8").then(JSON.parse),
]);
const debugToken = fixture.SIDECAR_APP_CHECK_DEBUG_TOKEN;
const apiKey = firebaseConfig.FIREBASE_API_KEY;
if (!debugToken || !apiKey) {
  throw new Error("The App Check debug token or Firebase API key is missing.");
}

const cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
const cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
const account = cliAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Run firebase login before the email smoke test.");
}

await writeFile(credentialPath, JSON.stringify({
  client_id: cliApi.clientId(),
  client_secret: cliApi.clientSecret(),
  refresh_token: account.tokens.refresh_token,
  type: "authorized_user",
}), {mode: 0o600});
await chmod(credentialPath, 0o600);
process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;

const app = initializeApp({projectId, credential: applicationDefault()});
const db = getFirestore(app);
const startedAt = Date.now();

try {
  const exchangeResponse = await fetch(
    `https://firebaseappcheck.googleapis.com/v1/projects/${projectId}/apps/${androidAppId}:exchangeDebugToken?key=${apiKey}`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({debug_token: debugToken}),
    },
  );
  const exchangePayload = await exchangeResponse.json();
  if (!exchangeResponse.ok || !exchangePayload.token) {
    throw new Error(`App Check exchange failed (${exchangeResponse.status}).`);
  }

  const callableResponse = await fetch(
    `https://us-central1-${projectId}.cloudfunctions.net/requestPasswordResetCode`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "X-Firebase-AppCheck": exchangePayload.token,
      },
      body: JSON.stringify({data: {email: recipient}}),
    },
  );
  const callablePayload = await callableResponse.json();
  if (!callableResponse.ok || callablePayload.error) {
    throw new Error(
      `Password-reset request failed (${callableResponse.status}): ` +
        `${callablePayload.error?.message ?? "unknown error"}`,
    );
  }

  let mailDocument;
  let state = "PENDING";
  for (let attempt = 0; attempt < 24; attempt += 1) {
    const snapshot = await db.collection("mail").where("to", "==", recipient).get();
    mailDocument = snapshot.docs
      .filter((document) =>
        (document.data().createdAt?.toMillis?.() ?? 0) >= startedAt - 5000,
      )
      .sort((left, right) =>
        (right.data().createdAt?.toMillis?.() ?? 0) -
        (left.data().createdAt?.toMillis?.() ?? 0),
      )[0];
    state = String(mailDocument?.data().delivery?.state ?? "PENDING");
    if (["SUCCESS", "ERROR"].includes(state)) break;
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  if (!mailDocument) throw new Error("No authentication email document was queued.");
  if (state !== "SUCCESS") {
    throw new Error(`Authentication email delivery finished in state ${state}.`);
  }

  process.stdout.write("Authentication email accepted and delivered by SMTP.\n");

  const otpId = createHash("sha256")
    .update(`password_reset:${recipient}`)
    .digest("hex");
  await Promise.all([
    mailDocument.ref.delete(),
    db.collection("auth_otps").doc(otpId).delete(),
  ]);
} finally {
  await deleteApp(app);
  await unlink(credentialPath).catch(() => undefined);
}
