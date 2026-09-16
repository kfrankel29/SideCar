import {execFileSync} from "node:child_process";
import {randomBytes} from "node:crypto";
import {chmod, mkdtemp, readFile, rm, writeFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {createRequire} from "node:module";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const adminEmail = "admin@ride-sidecar.com";
const keychainService = "SideCar Admin Temporary Password";
const command = process.argv[2];

if (!["inspect", "reset", "smoke"].includes(command)) {
  throw new Error("Use inspect, reset, or smoke.");
}

let credentialDirectory;
if (process.env.SIDECAR_FIREBASE_TOOLS_ROOT) {
  const root = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
  const cliAuth = require(`${root}/lib/auth.js`);
  const cliApi = require(`${root}/lib/api.js`);
  const account = cliAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Sign in to Firebase CLI before restoring admin access.");
  }
  credentialDirectory = await mkdtemp(join(tmpdir(), "sidecar-admin-adc-"));
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

async function findAdmin() {
  try {
    return await auth.getUserByEmail(adminEmail);
  } catch (error) {
    if (error?.code === "auth/user-not-found") return null;
    throw error;
  }
}

try {
  const existing = await findAdmin();
  if (command === "inspect") {
    process.stdout.write(JSON.stringify({
      projectId,
      adminEmail,
      exists: Boolean(existing),
      adminClaim: existing?.customClaims?.admin === true,
      passwordChangeRequired: existing?.customClaims?.mustChangePassword === true,
      disabled: existing?.disabled ?? null,
    }) + "\n");
  } else if (command === "smoke") {
    if (!existing?.customClaims?.admin ||
        !existing.customClaims.mustChangePassword) {
      throw new Error("Admin account is missing or first-login gate is not active.");
    }
    const password = execFileSync("/usr/bin/security", [
      "find-generic-password", "-a", adminEmail,
      "-s", keychainService, "-w",
    ], {encoding: "utf8"}).trim();
    const config = JSON.parse(await readFile(new URL(
      "../../../apps/mobile/.local/firebase-android.json", import.meta.url,
    ), "utf8"));
    const signIn = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(config.FIREBASE_API_KEY)}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({email: adminEmail, password, returnSecureToken: true}),
      },
    );
    if (!signIn.ok) throw new Error(`Temporary sign-in failed: HTTP ${signIn.status}`);
    const {idToken} = await signIn.json();
    const decoded = await auth.verifyIdToken(idToken);
    if (decoded.uid !== existing.uid || decoded.admin !== true ||
        decoded.mustChangePassword !== true) {
      throw new Error("Signed-in token has incorrect administrator claims.");
    }
    const overview = await fetch(
      `https://us-central1-${projectId}.cloudfunctions.net/adminGetOverview`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${idToken}`,
        },
        body: JSON.stringify({data: {}}),
      },
    );
    if (!overview.ok) throw new Error(`Admin overview failed: HTTP ${overview.status}`);
    const result = await overview.json();
    if (!result?.result?.counts) {
      throw new Error("Admin overview returned no counts.");
    }
    process.stdout.write(JSON.stringify({
      temporarySignIn: "passed",
      adminClaim: true,
      passwordChangeRequired: true,
      protectedOverview: "passed",
    }) + "\n");
  } else {
    const password = `${randomBytes(24).toString("base64url")}Aa1!`;
    // Persist the secret before making a remote change, so the temporary
    // credential is never lost after a successful Firebase update.
    execFileSync("/usr/bin/security", [
      "add-generic-password", "-U", "-a", adminEmail,
      "-s", keychainService, "-w", password,
    ], {stdio: "ignore"});

    const user = existing ?? await auth.createUser({
      email: adminEmail,
      password,
      emailVerified: false,
      disabled: false,
    });
    if (existing) {
      await auth.updateUser(user.uid, {password, disabled: false});
    }
    await auth.setCustomUserClaims(user.uid, {
      ...(user.customClaims ?? {}),
      admin: true,
      mustChangePassword: true,
    });
    await auth.revokeRefreshTokens(user.uid);
    const verified = await auth.getUser(user.uid);
    if (verified.customClaims?.admin !== true ||
        verified.customClaims?.mustChangePassword !== true || verified.disabled) {
      throw new Error("Admin claims did not verify after reset.");
    }
    process.stdout.write(JSON.stringify({
      projectId,
      adminEmail,
      created: !existing,
      passwordChangeRequired: true,
      keychainService,
    }) + "\n");
  }
} finally {
  await deleteApp(app);
  if (credentialDirectory) {
    await rm(credentialDirectory, {recursive: true, force: true});
  }
}
