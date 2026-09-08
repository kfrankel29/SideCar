import {createRequire} from "node:module";
import {chmod, unlink, writeFile} from "node:fs/promises";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

import {completedRideReimbursementCents} from "../lib/booking_policy.js";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const credentialPath = "/tmp/sidecar-reimbursement-firebase-adc.json";
const apply = process.argv.includes("--apply");

if (!firebaseToolsRoot) {
  throw new Error("SIDECAR_FIREBASE_TOOLS_ROOT is required.");
}

const cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
const cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
const account = cliAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Run firebase login before recalculating reimbursements.");
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

try {
  const [bookings, users] = await Promise.all([
    db.collection("bookings").get(),
    db.collection("users").get(),
  ]);
  const totals = new Map();
  for (const document of bookings.docs) {
    const booking = document.data();
    const driverId = typeof booking.driverId === "string" ? booking.driverId : "";
    if (!driverId) continue;
    const amount = completedRideReimbursementCents(
      booking.status,
      booking.driverPayoutCents,
      booking.baseFareCents,
    );
    if (amount > 0) totals.set(driverId, (totals.get(driverId) ?? 0) + amount);
  }

  const updates = users.docs.flatMap((document) => {
    const current = Number(document.data().totalEarningsCents ?? 0);
    const expected = totals.get(document.id) ?? 0;
    return current === expected ? [] : [{reference: document.ref, current, expected}];
  });
  const currentCents = updates.reduce((sum, item) => sum + item.current, 0);
  const expectedCents = updates.reduce((sum, item) => sum + item.expected, 0);
  process.stdout.write(
    `${apply ? "Applying" : "Dry run:"} ${updates.length} profile correction(s); ` +
    `affected totals ${currentCents} -> ${expectedCents} cents.\n`,
  );

  if (apply) {
    for (let index = 0; index < updates.length; index += 400) {
      const batch = db.batch();
      for (const update of updates.slice(index, index + 400)) {
        batch.set(update.reference, {
          totalEarningsCents: update.expected,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      await batch.commit();
    }
    process.stdout.write("Completed reimbursement totals were recalculated.\n");
  }
} finally {
  await deleteApp(app);
  await unlink(credentialPath).catch(() => undefined);
}
