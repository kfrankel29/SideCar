import {createRequire} from "node:module";
import {chmod, unlink, writeFile} from "node:fs/promises";
import {randomBytes} from "node:crypto";
import {execFileSync} from "node:child_process";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const credentialPath = "/tmp/sidecar-m7-firebase-adc.json";
const reviewCredentialPath = "/tmp/sidecar-app-review.json";
const reviewEmail = "app-review-sidecar@example.com";
const keychainService = "SideCar App Review";

if (!firebaseToolsRoot) {
  throw new Error("SIDECAR_FIREBASE_TOOLS_ROOT is required.");
}

const cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
const cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
const account = cliAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Run firebase login before provisioning the review account.");
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
const auth = getAuth(app);
const db = getFirestore(app);

try {
  const password = `${randomBytes(20).toString("base64url")}Aa1!`;
  let user;
  try {
    user = await auth.getUserByEmail(reviewEmail);
    user = await auth.updateUser(user.uid, {
      password,
      emailVerified: true,
      disabled: false,
      displayName: "SideCar App Review",
    });
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    user = await auth.createUser({
      email: reviewEmail,
      password,
      emailVerified: true,
      displayName: "SideCar App Review",
    });
  }

  await Promise.all([
    db.collection("users").doc(user.uid).set({
      email: reviewEmail,
      firstName: "SideCar",
      lastName: "Review",
      displayName: "SideCar Review",
      school: "University of California, Santa Barbara",
      age: 21,
      gender: "Female",
      language: "English",
      primaryRole: "rider",
      profileComplete: true,
      accountStatus: "active",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
    db.collection("users").doc(user.uid)
      .collection("verifications").doc("current").set({
        identityStatus: "verified",
        insuranceStatus: "verified",
        insuranceVerificationProvider: "app-review",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
    db.collection("users").doc(user.uid)
      .collection("vehicles").doc("primary").set({
        complete: true,
        make: "Honda",
        model: "Civic",
        year: 2024,
        color: "Blue",
        seats: 4,
        licensePlate: "REVIEW1",
        photoUrl: "",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
  ]);

  await writeFile(reviewCredentialPath, `${JSON.stringify({
    email: reviewEmail,
    password,
    uid: user.uid,
  })}\n`, {mode: 0o600});
  await chmod(reviewCredentialPath, 0o600);
  execFileSync("/usr/bin/security", [
    "add-generic-password",
    "-U",
    "-a",
    reviewEmail,
    "-s",
    keychainService,
    "-w",
    password,
  ], {stdio: "ignore"});
  process.stdout.write(`Provisioned persistent App Review account for ${reviewEmail}.\n`);
} finally {
  await deleteApp(app);
  await unlink(credentialPath).catch(() => undefined);
}
