import {randomBytes} from "node:crypto";
import {chmod, mkdtemp, readFile, rm, writeFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {createRequire} from "node:module";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const qaEmail = `sidecar-admin-flow-${randomBytes(9).toString("hex")}@example.com`;
const firstPassword = `${randomBytes(24).toString("base64url")}Aa1!`;
const replacementPassword = `${randomBytes(24).toString("base64url")}Bb2!`;

let credentialDirectory;
if (process.env.SIDECAR_FIREBASE_TOOLS_ROOT) {
  const root = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
  const cliAuth = require(`${root}/lib/auth.js`);
  const cliApi = require(`${root}/lib/api.js`);
  const account = cliAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error("Sign in to Firebase CLI first.");
  credentialDirectory = await mkdtemp(join(tmpdir(), "sidecar-admin-flow-adc-"));
  const credentialPath = join(credentialDirectory, "adc.json");
  await writeFile(credentialPath, JSON.stringify({
    client_id: cliApi.clientId(),
    client_secret: cliApi.clientSecret(),
    refresh_token: account.tokens.refresh_token,
    type: "authorized_user",
  }), {mode: 0o600});
  await chmod(credentialPath, 0o600);
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
} else if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error("Set SIDECAR_FIREBASE_TOOLS_ROOT or GOOGLE_APPLICATION_CREDENTIALS.");
}

const app = initializeApp({projectId, credential: applicationDefault()});
const auth = getAuth(app);
let createdUid;

async function identityRequest(apiKey, method, body) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${encodeURIComponent(apiKey)}`,
    {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(body)},
  );
  const result = await response.json();
  return {ok: response.ok, status: response.status, result};
}

async function callable(name, idToken) {
  const response = await fetch(
    `https://us-central1-${projectId}.cloudfunctions.net/${name}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json", Authorization: `Bearer ${idToken}`},
      body: JSON.stringify({data: {}}),
    },
  );
  return {ok: response.ok, status: response.status, result: await response.json()};
}

function check(condition, message) {
  if (!condition) throw new Error(message);
}

try {
  const clientAdminBefore = await auth.getUserByEmail("admin@ride-sidecar.com");
  const clientAdminSnapshot = {
    uid: clientAdminBefore.uid,
    claims: JSON.stringify(clientAdminBefore.customClaims ?? {}),
    disabled: clientAdminBefore.disabled,
  };
  const config = JSON.parse(await readFile(new URL(
    "../../../apps/mobile/.local/firebase-android.json", import.meta.url,
  ), "utf8"));
  const apiKey = config.FIREBASE_API_KEY;
  check(typeof apiKey === "string" && apiKey.length > 0, "Firebase API key is missing.");

  const qaUser = await auth.createUser({
    email: qaEmail,
    password: firstPassword,
    emailVerified: false,
    disabled: false,
  });
  createdUid = qaUser.uid;
  process.stdout.write(JSON.stringify({qaAccount: qaEmail, created: true}) + "\n");
  await auth.setCustomUserClaims(createdUid, {admin: true, mustChangePassword: true});

  const firstSignIn = await identityRequest(apiKey, "signInWithPassword", {
    email: qaEmail, password: firstPassword, returnSecureToken: true,
  });
  check(firstSignIn.ok, `Temporary-password sign-in failed: HTTP ${firstSignIn.status}`);
  const firstToken = await auth.verifyIdToken(firstSignIn.result.idToken);
  check(firstToken.uid === createdUid && firstToken.admin === true &&
    firstToken.mustChangePassword === true, "First-login claims are incorrect.");

  const changed = await identityRequest(apiKey, "update", {
    idToken: firstSignIn.result.idToken,
    password: replacementPassword,
    returnSecureToken: true,
  });
  check(changed.ok, `Password replacement failed: HTTP ${changed.status}`);
  const oldSignIn = await identityRequest(apiKey, "signInWithPassword", {
    email: qaEmail, password: firstPassword, returnSecureToken: true,
  });
  check(!oldSignIn.ok, "The temporary password still signs in after replacement.");
  const newSignIn = await identityRequest(apiKey, "signInWithPassword", {
    email: qaEmail, password: replacementPassword, returnSecureToken: true,
  });
  check(newSignIn.ok, `New-password sign-in failed: HTTP ${newSignIn.status}`);
  const beforeCompletion = await auth.verifyIdToken(newSignIn.result.idToken);
  check(beforeCompletion.mustChangePassword === true,
    "The first-login gate cleared before completion was recorded.");

  const completed = await callable("adminCompleteFirstLogin", newSignIn.result.idToken);
  check(completed.ok && completed.result?.result?.completed === true,
    `First-login completion failed: HTTP ${completed.status}`);
  const finalSignIn = await identityRequest(apiKey, "signInWithPassword", {
    email: qaEmail, password: replacementPassword, returnSecureToken: true,
  });
  check(finalSignIn.ok, `Final sign-in failed: HTTP ${finalSignIn.status}`);
  const finalToken = await auth.verifyIdToken(finalSignIn.result.idToken);
  check(finalToken.admin === true && finalToken.mustChangePassword !== true,
    "The first-login gate did not clear after completion.");
  const overview = await callable("adminGetOverview", finalSignIn.result.idToken);
  check(overview.ok && Boolean(overview.result?.result?.counts),
    `Admin overview failed: HTTP ${overview.status}`);

  const clientAdminAfter = await auth.getUserByEmail("admin@ride-sidecar.com");
  check(clientAdminAfter.uid === clientAdminSnapshot.uid &&
    JSON.stringify(clientAdminAfter.customClaims ?? {}) === clientAdminSnapshot.claims &&
    clientAdminAfter.disabled === clientAdminSnapshot.disabled,
  "Client administrator account changed during the QA flow.");

  process.stdout.write(JSON.stringify({
    temporarySignIn: "passed",
    firstLoginGate: "passed",
    passwordReplacement: "passed",
    oldPasswordRejected: "passed",
    newPasswordSignIn: "passed",
    firstLoginCompletion: "passed",
    adminOverview: "passed",
    clientAdminUnchanged: "passed",
  }) + "\n");
} finally {
  try {
    if (createdUid) {
      const qaUser = await auth.getUser(createdUid);
      check(qaUser.email === qaEmail && qaEmail.startsWith("sidecar-admin-flow-"),
        "Refusing to delete an unexpected account.");
      await auth.deleteUser(createdUid);
      try {
        await auth.getUser(createdUid);
        throw new Error("QA account still exists after deletion.");
      } catch (error) {
        if (error?.code !== "auth/user-not-found") throw error;
      }
      process.stdout.write(JSON.stringify({qaAccount: qaEmail, deleted: true}) + "\n");
    }
  } finally {
    await deleteApp(app);
    if (credentialDirectory) await rm(credentialDirectory, {recursive: true, force: true});
  }
}
