import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

const projectId = "sidecar-fb0e7";
const storageBucket = "sidecar-fb0e7.firebasestorage.app";
const command = process.argv[2];
const confirmation = process.argv[3] ?? "";
const preservedEmails = new Set([
  "app-review-sidecar@example.com",
  "app-review-driver-sidecar@example.com",
  "admin@ride-sidecar.com",
]);

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error("GOOGLE_APPLICATION_CREDENTIALS is required.");
}

const app = initializeApp({
  projectId,
  storageBucket,
  credential: applicationDefault(),
});
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);

function chunks(values, size = 30) {
  const result = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

async function allUsers() {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1_000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

function splitUsers(users) {
  const keep = users.filter((user) =>
    preservedEmails.has((user.email ?? "").trim().toLowerCase()));
  const remove = users.filter((user) => !keep.includes(user));
  if (keep.length !== preservedEmails.size ||
      keep.some((user) => user.email === "admin@ride-sidecar.com" ?
        user.customClaims?.admin !== true :
        user.customClaims?.appReviewDemo !== true)) {
    throw new Error("Both App Review accounts and the administrator must exist before cleanup.");
  }
  return {keep, remove};
}

function maskedRecord(user) {
  return {
    idSuffix: user.uid.slice(-6),
    domain: (user.email ?? "").split("@").at(-1) ?? "none",
    providers: user.providerData.map((provider) => provider.providerId),
    admin: user.customClaims?.admin === true,
    created: user.metadata.creationTime,
  };
}

async function queryDocuments(collection, field, values, operator = "in") {
  const documents = new Map();
  for (const group of chunks(values)) {
    const snapshot = await db.collection(collection).where(field, operator, group).get();
    for (const document of snapshot.docs) documents.set(document.ref.path, document.ref);
  }
  return documents;
}

async function linkedDocuments(uids) {
  const queries = [
    ["rides", "driverId", "in"],
    ["ride_schedules", "driverId", "in"],
    ["bookings", "riderId", "in"],
    ["bookings", "driverId", "in"],
    ["conversations", "participantIds", "array-contains-any"],
    ["notifications", "userId", "in"],
    ["admin_notifications", "userId", "in"],
    ["ride_search_alerts", "userId", "in"],
    ["safetyReports", "reporterUid", "in"],
    ["safetyReports", "reportedUid", "in"],
    ["trip_ratings", "riderId", "in"],
    ["trip_ratings", "driverId", "in"],
    ["rider_ratings", "riderId", "in"],
    ["rider_ratings", "driverId", "in"],
    ["referral_codes", "ownerUid", "in"],
    ["payout_obligations", "driverId", "in"],
  ];
  const groups = await Promise.all(queries.map(([collection, field, operator]) =>
    queryDocuments(collection, field, uids, operator)));
  return new Map(groups.flatMap((group) => [...group]));
}

async function cleanup(remove) {
  const uids = remove.map((user) => user.uid);
  const linked = await linkedDocuments(uids);
  const linkedGroups = chunks([...linked.values()], 20);
  for (let index = 0; index < linkedGroups.length; index += 1) {
    await Promise.all(linkedGroups[index].map((reference) => db.recursiveDelete(reference)));
    process.stdout.write(`Removed linked data batch ${index + 1}/${linkedGroups.length}.\n`);
  }

  const userGroups = chunks(uids, 5);
  for (let index = 0; index < userGroups.length; index += 1) {
    await Promise.all(userGroups[index].flatMap((uid) => [
      db.recursiveDelete(db.collection("users").doc(uid)),
      db.recursiveDelete(db.collection("payment_accounts").doc(uid)),
      db.recursiveDelete(db.collection("payment_customers").doc(uid)),
      db.recursiveDelete(db.collection("referral_redemptions").doc(uid)),
      storage.bucket().deleteFiles({prefix: `users/${uid}/`}),
    ]));
    process.stdout.write(`Removed account data batch ${index + 1}/${userGroups.length}.\n`);
  }
  const result = await auth.deleteUsers(uids);
  if (result.failureCount > 0) {
    throw new Error(`Firebase Auth failed to delete ${result.failureCount} accounts.`);
  }
  return {linkedDocuments: linked.size, authAccounts: result.successCount};
}

try {
  const users = await allUsers();
  const {keep, remove} = splitUsers(users);
  if (command === "inspect") {
    process.stdout.write(`${JSON.stringify({
      projectId,
      total: users.length,
      preserved: keep.map(maskedRecord),
      removalCount: remove.length,
      removalTargets: remove.map(maskedRecord),
      requiredConfirmation: `DELETE_${remove.length}_NON_REVIEW_ACCOUNTS`,
    }, null, 2)}\n`);
  } else if (command === "cleanup") {
    const expected = `DELETE_${remove.length}_NON_REVIEW_ACCOUNTS`;
    if (remove.length === 0) {
      process.stdout.write("No non-review accounts remain.\n");
    } else {
      if (confirmation !== expected) {
        throw new Error(`Pass ${expected} to confirm the exact live scope.`);
      }
      const removed = await cleanup(remove);
      const after = splitUsers(await allUsers());
      if (after.remove.length !== 0 || after.keep.length !== preservedEmails.size) {
        throw new Error("Post-cleanup account verification failed.");
      }
      process.stdout.write(`${JSON.stringify({
        projectId,
        removed,
        remainingAccounts: after.keep.length,
      }, null, 2)}\n`);
    }
  } else {
    throw new Error("Use inspect or cleanup with its exact confirmation value.");
  }
} finally {
  await deleteApp(app);
}
