import {createRequire} from "node:module";
import {chmod, unlink, writeFile} from "node:fs/promises";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const accountEmail = process.env.SIDECAR_AUDIT_EMAIL?.trim().toLowerCase();
const credentialPath = "/tmp/sidecar-account-audit-adc.json";

if (!firebaseToolsRoot || !accountEmail) {
  throw new Error("SIDECAR_FIREBASE_TOOLS_ROOT and SIDECAR_AUDIT_EMAIL are required.");
}

const cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
const cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
const account = cliAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) throw new Error("Run firebase login first.");

await writeFile(credentialPath, JSON.stringify({
  client_id: cliApi.clientId(),
  client_secret: cliApi.clientSecret(),
  refresh_token: account.tokens.refresh_token,
  type: "authorized_user",
}), {mode: 0o600});
await chmod(credentialPath, 0o600);
process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;

const app = initializeApp({projectId, credential: applicationDefault()});
try {
  const auth = getAuth(app);
  const db = getFirestore(app);
  const user = await auth.getUserByEmail(accountEmail);
  const [rides, riderBookings, driverBookings] = await Promise.all([
    db.collection("rides").where("driverId", "==", user.uid).limit(200).get(),
    db.collection("bookings").where("riderId", "==", user.uid).limit(200).get(),
    db.collection("bookings").where("driverId", "==", user.uid).limit(200).get(),
  ]);
  const summarize = (document) => {
    const data = document.data();
    return {
      status: String(data.status ?? ""),
      departureAt: data.departureAt?.toDate?.().toISOString?.() ?? null,
      paymentStatus: String(data.paymentStatus ?? ""),
      payoutStatus: String(data.payoutStatus ?? ""),
      refundStatus: String(data.refundStatus ?? ""),
    };
  };
  process.stdout.write(`${JSON.stringify({
    disabled: user.disabled,
    rides: rides.docs.map(summarize),
    riderBookings: riderBookings.docs.map(summarize),
    driverBookings: driverBookings.docs.map(summarize),
  }, null, 2)}\n`);
} finally {
  await deleteApp(app);
  await unlink(credentialPath).catch(() => undefined);
}
