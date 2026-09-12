import {readFile} from "node:fs/promises";

const projectId = "sidecar-fb0e7";
const region = "us-central1";
const iosAppId = "1:766275767825:ios:383d5eea95be5dc93cabb0";
const mobileConfigPath = process.env.SIDECAR_IOS_CONFIG_PATH ??
  new URL("../../../apps/mobile/.local/firebase-ios.json", import.meta.url);
const feedbackFixturePath = process.env.SIDECAR_FEEDBACK_FIXTURE_PATH ??
  "/tmp/sidecar-feedback-acceptance.json";
const adminFixturePath = process.env.SIDECAR_M6_FIXTURE_PATH ??
  "/tmp/sidecar-m6-acceptance.json";
let apiKey = "";

async function jsonRequest(url, init) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${response.status} ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function signIn(email, password) {
  return jsonRequest(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    },
  );
}

async function appCheckToken(debugToken) {
  return jsonRequest(
    `https://firebaseappcheck.googleapis.com/v1/projects/${projectId}/apps/${iosAppId}:exchangeDebugToken?key=${apiKey}`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({debugToken}),
    },
  );
}

async function callable(name, idToken, data, appCheck) {
  const headers = {
    authorization: `Bearer ${idToken}`,
    "content-type": "application/json",
  };
  if (appCheck) headers["x-firebase-appcheck"] = appCheck;
  return jsonRequest(
    `https://${region}-${projectId}.cloudfunctions.net/${name}`,
    {method: "POST", headers, body: JSON.stringify({data})},
  );
}

async function main() {
  const mobileConfig = JSON.parse(await readFile(mobileConfigPath, "utf8"));
  apiKey = String(mobileConfig.FIREBASE_API_KEY ?? "");
  if (!apiKey) throw new Error("The iOS Firebase API key is required.");
  const feedback = JSON.parse(await readFile(feedbackFixturePath, "utf8"));
  const admin = JSON.parse(await readFile(adminFixturePath, "utf8"));
  const command = process.argv[2];

  if (command === "mobile") {
    const signedIn = await signIn(
      feedback.M5_E2E_FIRST_EMAIL,
      feedback.M5_E2E_FIRST_PASSWORD,
    );
    const appCheck = await appCheckToken(feedback.SIDECAR_APP_CHECK_DEBUG_TOKEN);
    await callable(
      "requestAccountDeletion",
      signedIn.idToken,
      {confirmation: "DELETE"},
      appCheck.token,
    );
    process.stdout.write("Mobile account deletion callable completed.\n");
    return;
  }

  if (command === "admin" || command === "admin-stale") {
    const signedIn = await signIn(admin.M6_ADMIN_EMAIL, admin.M6_ADMIN_PASSWORD);
    await callable(
      "adminDeleteUserAccount",
      signedIn.idToken,
      {
        uid: command === "admin-stale"
          ? admin.M6_USER_UID
          : feedback.QA_RIDER_UID,
        reason: "Isolated account deletion acceptance test",
        confirmation: "DELETE",
      },
    );
    process.stdout.write("Admin account deletion callable completed.\n");
    return;
  }

  throw new Error("Use mobile, admin, or admin-stale.");
}

await main();
