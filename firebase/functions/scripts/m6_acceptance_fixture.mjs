import {createRequire} from "node:module";
import {chmod, readFile, unlink, writeFile} from "node:fs/promises";
import {randomBytes} from "node:crypto";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const storageBucket = "sidecar-fb0e7.firebasestorage.app";
const fixturePath = process.env.SIDECAR_M6_FIXTURE_PATH ??
  "/tmp/sidecar-m6-acceptance.json";
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const credentialPath = "/tmp/sidecar-m6-firebase-adc.json";

if (!firebaseToolsRoot) {
  throw new Error("SIDECAR_FIREBASE_TOOLS_ROOT is required.");
}

const cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
const cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
const account = cliAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Run firebase login before creating M6 acceptance fixtures.");
}

await writeFile(credentialPath, JSON.stringify({
  client_id: cliApi.clientId(),
  client_secret: cliApi.clientSecret(),
  refresh_token: account.tokens.refresh_token,
  type: "authorized_user",
}), {mode: 0o600});
await chmod(credentialPath, 0o600);
process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;

const app = initializeApp({
  projectId,
  storageBucket,
  credential: applicationDefault(),
});
const auth = getAuth(app);
const db = getFirestore(app);
const bucket = getStorage(app).bucket();

const command = process.argv[2];

async function createAccount(
  role,
  suffix,
  {admin = false, emailVerified = true} = {},
) {
  const email = `m6-${role}-${suffix}@example.com`;
  const password = `${randomBytes(18).toString("base64url")}Aa1!`;
  const user = await auth.createUser({
    email,
    password,
    emailVerified,
    displayName: `M6 ${role.replaceAll("-", " ")}`,
  });
  if (admin) await auth.setCustomUserClaims(user.uid, {admin: true});
  return {email, password, uid: user.uid};
}

async function createUserProfile(user, {insuranceStatus = "verified"} = {}) {
  const reference = db.collection("users").doc(user.uid);
  await Promise.all([
    reference.set({
      firstName: "M6",
      lastName: "Acceptance QA",
      profileComplete: true,
      accountStatus: "active",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }),
    reference.collection("verifications").doc("current").set({
      identityStatus: "verified",
      insuranceStatus,
      insuranceVerificationProvider: insuranceStatus === "verified" ? "test" : "manual",
      manualInsuranceSubmitted: false,
      updatedAt: FieldValue.serverTimestamp(),
    }),
    reference.collection("vehicles").doc("primary").set({
      complete: true,
      make: "QA",
      model: "Acceptance",
      updatedAt: FieldValue.serverTimestamp(),
    }),
  ]);
}

async function createInsuranceFixture(user, label) {
  const objectPath = `users/${user.uid}/verification/insurance/m6-${label}.pdf`;
  const bytes = Buffer.from(
    "%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n",
    "utf8",
  );
  await bucket.file(objectPath).save(bytes, {
    resumable: false,
    contentType: "application/pdf",
    metadata: {cacheControl: "private,no-store"},
  });
  await db.collection("users").doc(user.uid)
    .collection("verifications").doc("current").set({
      insuranceStatus: "pending",
      manualInsuranceSubmitted: true,
      insuranceDocumentPath: objectPath,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  return objectPath;
}

async function setup() {
  const suffix = `${Date.now()}-${randomBytes(3).toString("hex")}`;
  const admin = await createAccount("admin", suffix, {admin: true});
  const moderatedUser = await createAccount("moderated-user", suffix, {
    emailVerified: false,
  });
  const approvalUser = await createAccount("insurance-approve", suffix);
  const rejectionUser = await createAccount("insurance-reject", suffix);
  await Promise.all([
    createUserProfile(admin),
    createUserProfile(moderatedUser),
    createUserProfile(approvalUser, {insuranceStatus: "pending"}),
    createUserProfile(rejectionUser, {insuranceStatus: "pending"}),
  ]);
  const [approvalObjectPath, rejectionObjectPath] = await Promise.all([
    createInsuranceFixture(approvalUser, "approve"),
    createInsuranceFixture(rejectionUser, "reject"),
  ]);
  const fixture = {
    M6_ADMIN_EMAIL: admin.email,
    M6_ADMIN_PASSWORD: admin.password,
    M6_ADMIN_UID: admin.uid,
    M6_USER_EMAIL: moderatedUser.email,
    M6_USER_PASSWORD: moderatedUser.password,
    M6_USER_UID: moderatedUser.uid,
    M6_APPROVAL_UID: approvalUser.uid,
    M6_REJECTION_UID: rejectionUser.uid,
    M6_APPROVAL_OBJECT_PATH: approvalObjectPath,
    M6_REJECTION_OBJECT_PATH: rejectionObjectPath,
  };
  await writeFile(fixturePath, `${JSON.stringify(fixture)}\n`, {mode: 0o600});
  await chmod(fixturePath, 0o600);
  process.stdout.write(`Created four isolated M6 QA accounts in ${projectId}.\n`);
}

async function reset() {
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  await Promise.all([
    createInsuranceFixture({uid: fixture.M6_APPROVAL_UID}, "approve"),
    createInsuranceFixture({uid: fixture.M6_REJECTION_UID}, "reject"),
    db.collection("users").doc(fixture.M6_USER_UID).set({
      accountStatus: "active",
      suspensionReason: FieldValue.delete(),
      banReason: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
    auth.updateUser(fixture.M6_USER_UID, {
      disabled: false,
      emailVerified: false,
    }),
    auth.setCustomUserClaims(fixture.M6_USER_UID, {}),
  ]);
  process.stdout.write(`Reset reusable M6 QA state in ${projectId}.\n`);
}

async function cleanup() {
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  const uids = [
    fixture.M6_ADMIN_UID,
    fixture.M6_USER_UID,
    fixture.M6_APPROVAL_UID,
    fixture.M6_REJECTION_UID,
  ];
  await Promise.all([
    bucket.file(fixture.M6_APPROVAL_OBJECT_PATH).delete({ignoreNotFound: true}),
    bucket.file(fixture.M6_REJECTION_OBJECT_PATH).delete({ignoreNotFound: true}),
  ]);
  for (const uid of uids) {
    await db.recursiveDelete(db.collection("users").doc(uid));
    await auth.deleteUser(uid).catch((error) => {
      if (error?.code !== "auth/user-not-found") throw error;
    });
  }
  const audit = await db.collection("admin_audit_logs")
    .where("adminUid", "==", fixture.M6_ADMIN_UID).get();
  const writer = db.bulkWriter();
  for (const document of audit.docs) writer.delete(document.ref);
  await writer.close();
  process.stdout.write(`Removed isolated M6 QA accounts and audit fixtures from ${projectId}.\n`);
}

try {
  if (command === "setup") await setup();
  else if (command === "reset") await reset();
  else if (command === "cleanup") await cleanup();
  else throw new Error("Use setup, reset, or cleanup.");
} finally {
  await deleteApp(app);
  await unlink(credentialPath).catch(() => undefined);
}
