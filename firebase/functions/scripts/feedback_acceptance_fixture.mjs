import {createRequire} from "node:module";
import {chmod, readFile, unlink, writeFile} from "node:fs/promises";
import {randomBytes, randomUUID} from "node:crypto";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const iosAppId = "1:766275767825:ios:383d5eea95be5dc93cabb0";
const androidAppId = "1:766275767825:android:b2109df465aa77ea3cabb0";
const fixturePath = process.env.SIDECAR_FEEDBACK_FIXTURE_PATH ??
  "/tmp/sidecar-feedback-acceptance.json";
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const credentialPath = "/tmp/sidecar-feedback-firebase-adc.json";

if (!firebaseToolsRoot) {
  throw new Error("SIDECAR_FIREBASE_TOOLS_ROOT is required.");
}

const cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
const cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
const account = cliAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Run firebase login before creating acceptance fixtures.");
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
const command = process.argv[2];

async function createAccount(role, suffix) {
  const email = `feedback-${role}-${suffix}@example.com`;
  const password = `${randomBytes(18).toString("base64url")}Aa1!`;
  const user = await auth.createUser({
    email,
    password,
    emailVerified: true,
    displayName: `Feedback ${role}`,
  });
  const reference = db.collection("users").doc(user.uid);
  await Promise.all([
    reference.set({
      email,
      firstName: "Feedback",
      lastName: role === "driver" ? "Driver" : "Rider",
      displayName: `Feedback ${role}`,
      school: "University of California, Santa Barbara",
      age: 24,
      gender: role === "driver" ? "Male" : "Female",
      language: "English",
      photoUrl: "https://sidecar-fb0e7.web.app/icons/Icon-192.png",
      primaryRole: role,
      profileComplete: true,
      accountStatus: "active",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }),
    reference.collection("verifications").doc("current").set({
      identityStatus: "verified",
      insuranceStatus: "verified",
      insuranceVerificationProvider: "qa",
      updatedAt: FieldValue.serverTimestamp(),
    }),
    reference.collection("vehicles").doc("primary").set({
      complete: true,
      make: "QA",
      model: "Route Test",
      year: 2026,
      color: "Black",
      seats: 4,
      photoUrl: "",
      updatedAt: FieldValue.serverTimestamp(),
    }),
  ]);
  return {email, password, uid: user.uid};
}

async function registerAppCheckDebugToken(appId, debugToken, displayName) {
  const access = await cliAuth.getAccessToken(
    account.tokens.refresh_token,
    cliApi.getScopes(),
  );
  const response = await fetch(
    `https://firebaseappcheck.googleapis.com/v1/projects/${projectId}/apps/${appId}/debugTokens`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${access.access_token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({displayName, token: debugToken}),
    },
  );
  if (!response.ok && response.status !== 409) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(
      `App Check registration failed (${response.status}): ${
        payload?.error?.message ?? "unknown error"
      }`,
    );
  }
}

async function unregisterAppCheckDebugToken(appId, debugToken) {
  if (!debugToken) return;
  const access = await cliAuth.getAccessToken(
    account.tokens.refresh_token,
    cliApi.getScopes(),
  );
  const listResponse = await fetch(
    `https://firebaseappcheck.googleapis.com/v1/projects/${projectId}/apps/${appId}/debugTokens?pageSize=100`,
    {headers: {authorization: `Bearer ${access.access_token}`}},
  );
  if (!listResponse.ok) {
    throw new Error(`App Check token list failed (${listResponse.status}).`);
  }
  const payload = await listResponse.json();
  const match = (payload.debugTokens ?? []).find(
    (candidate) => candidate.token === debugToken,
  );
  if (!match?.name) return;
  const deleteResponse = await fetch(
    `https://firebaseappcheck.googleapis.com/v1/${match.name}`,
    {
      method: "DELETE",
      headers: {authorization: `Bearer ${access.access_token}`},
    },
  );
  if (!deleteResponse.ok && deleteResponse.status !== 404) {
    throw new Error(`App Check token deletion failed (${deleteResponse.status}).`);
  }
}

async function ensureAppCheckDebugToken() {
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  if (typeof fixture.SIDECAR_APP_CHECK_DEBUG_TOKEN === "string" &&
      fixture.SIDECAR_APP_CHECK_DEBUG_TOKEN.length > 0) {
    return;
  }
  const debugToken = randomUUID();
  await Promise.all([iosAppId, androidAppId].map((appId) =>
    registerAppCheckDebugToken(
      appId,
      debugToken,
      `Feedback acceptance ${new Date().toISOString()}`,
    ),
  ));
  await writeFile(fixturePath, `${JSON.stringify({
    ...fixture,
    SIDECAR_APP_CHECK_DEBUG_TOKEN: debugToken,
  })}\n`, {mode: 0o600});
  await chmod(fixturePath, 0o600);
  process.stdout.write("Registered an isolated iOS and Android App Check acceptance token.\n");
}

async function setup() {
  const suffix = `${Date.now()}-${randomBytes(3).toString("hex")}`;
  const driver = await createAccount("driver", suffix);
  const rider = await createAccount("rider", suffix);
  await writeFile(fixturePath, `${JSON.stringify({
    M5_E2E_FIRST_EMAIL: driver.email,
    M5_E2E_FIRST_PASSWORD: driver.password,
    M5_E2E_SECOND_EMAIL: rider.email,
    M5_E2E_SECOND_PASSWORD: rider.password,
    QA_DRIVER_UID: driver.uid,
    QA_RIDER_UID: rider.uid,
  })}\n`, {mode: 0o600});
  await chmod(fixturePath, 0o600);
  await ensureAppCheckDebugToken();
  process.stdout.write(`Created two isolated feedback QA accounts in ${projectId}.\n`);
}

async function hydrate() {
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  await Promise.all([
    db.collection("users").doc(fixture.QA_DRIVER_UID).update({
      email: fixture.M5_E2E_FIRST_EMAIL,
      updatedAt: FieldValue.serverTimestamp(),
    }),
    db.collection("users").doc(fixture.QA_RIDER_UID).update({
      email: fixture.M5_E2E_SECOND_EMAIL,
      updatedAt: FieldValue.serverTimestamp(),
    }),
  ]);
  const rides = await db.collection("rides")
    .where("driverId", "==", fixture.QA_DRIVER_UID)
    .limit(20)
    .get();
  const routeDocument = rides.docs
    .filter((document) => {
      const data = document.data();
      return typeof data.encodedPolyline === "string" &&
        data.encodedPolyline.length > 0;
    })
    .sort((left, right) => {
      const leftTime = left.data().createdAt?.toMillis?.() ?? 0;
      const rightTime = right.data().createdAt?.toMillis?.() ?? 0;
      return rightTime - leftTime;
    })[0];
  if (!routeDocument) {
    throw new Error(
      "Run live_feedback_e2e_test.dart once before hydrating the M5 fixture.",
    );
  }

  const route = routeDocument.data();
  const departureAt = Timestamp.fromMillis(Date.now() + (90 * 24 * 60 * 60 * 1000));
  await routeDocument.ref.update({
    status: "published",
    departureAt,
    seatsTotal: Math.max(1, Number(route.seatsTotal ?? 1)),
    seatsAvailable: Math.max(1, Number(route.seatsAvailable ?? 1)),
    bookedSeats: 0,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const bookingReference = db.collection("bookings").doc(
    `feedback-${routeDocument.id}-${fixture.QA_RIDER_UID}`,
  );
  await Promise.all([
    db.collection("trip_ratings").doc(bookingReference.id).delete(),
    db.collection("rider_ratings").doc(bookingReference.id).delete(),
  ]);
  const origin = route.origin && typeof route.origin === "object" ? route.origin : {};
  const destination = route.destination && typeof route.destination === "object" ?
    route.destination : {};
  const now = Timestamp.now();
  await bookingReference.set({
    rideId: routeDocument.id,
    riderId: fixture.QA_RIDER_UID,
    riderName: "Feedback Rider",
    riderInitials: "FR",
    riderPhotoUrl: "https://sidecar-fb0e7.web.app/icons/Icon-192.png",
    driverId: fixture.QA_DRIVER_UID,
    driverName: "Feedback Driver",
    driverPhotoUrl: "https://sidecar-fb0e7.web.app/icons/Icon-192.png",
    originName: String(origin.displayName ?? origin.formattedAddress ?? "Goleta"),
    destinationName: String(
      destination.displayName ?? destination.formattedAddress ?? "San Francisco",
    ),
    seatKey: "front",
    seatLabel: "Front",
    pickupLocation: origin,
    dropoffLocation: destination,
    departureAt,
    baseFareCents: Math.max(1, Number(route.pricePerSeatCents ?? 2500)),
    serviceFeeCents: 0,
    processingFeeCents: 0,
    totalCents: Math.max(1, Number(route.pricePerSeatCents ?? 2500)),
    driverPayoutCents: Math.max(1, Number(route.pricePerSeatCents ?? 2500)),
    paymentMethod: "card",
    paymentStatus: "paid",
    payoutStatus: "paid",
    status: "completed",
    acceptedAt: now,
    confirmedAt: now,
    startedAt: now,
    completedAt: now,
    createdAt: now,
    updatedAt: now,
  });
  await writeFile(fixturePath, `${JSON.stringify({
    ...fixture,
    QA_ROUTE_ID: routeDocument.id,
    QA_BOOKING_ID: bookingReference.id,
  })}\n`, {mode: 0o600});
  await chmod(fixturePath, 0o600);
  process.stdout.write(
    `Hydrated isolated M5 acceptance route ${routeDocument.id}: ` +
    `${String(origin.displayName ?? origin.formattedAddress ?? "Goleta")} -> ` +
    `${String(destination.displayName ?? destination.formattedAddress ?? "San Francisco")} ` +
    `in ${projectId}.\n`,
  );
}

async function deleteQuery(query) {
  const snapshot = await query.get();
  const writer = db.bulkWriter();
  for (const document of snapshot.docs) writer.delete(document.ref);
  await writer.close();
}

async function resetTransientData() {
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  const [rides, driverBookings, riderBookings] = await Promise.all([
    db.collection("rides").where("driverId", "==", fixture.QA_DRIVER_UID).get(),
    db.collection("bookings").where("driverId", "==", fixture.QA_DRIVER_UID).get(),
    db.collection("bookings").where("riderId", "==", fixture.QA_RIDER_UID).get(),
  ]);
  const writer = db.bulkWriter();
  for (const document of rides.docs) {
    if (document.id !== fixture.QA_ROUTE_ID) writer.delete(document.ref);
  }
  const bookings = new Map([
    ...driverBookings.docs,
    ...riderBookings.docs,
  ].map((document) => [document.ref.path, document]));
  for (const document of bookings.values()) {
    if (document.id !== fixture.QA_BOOKING_ID) writer.delete(document.ref);
  }
  await writer.close();
  process.stdout.write(`Removed transient feedback QA records from ${projectId}.\n`);
}

async function inspectRoutes() {
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  const rides = await db.collection("rides")
    .where("driverId", "==", fixture.QA_DRIVER_UID)
    .limit(20)
    .get();
  const summaries = rides.docs.map((document) => {
    const data = document.data();
    const origin = data.origin && typeof data.origin === "object" ? data.origin : {};
    const destination = data.destination && typeof data.destination === "object" ?
      data.destination : {};
    return {
      id: document.id,
      status: String(data.status ?? ""),
      origin: String(origin.displayName ?? origin.formattedAddress ?? ""),
      destination: String(destination.displayName ?? destination.formattedAddress ?? ""),
      createdAt: data.createdAt?.toDate?.().toISOString?.() ?? "",
      polylineLength: String(data.encodedPolyline ?? "").length,
    };
  }).sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  process.stdout.write(`${JSON.stringify(summaries, null, 2)}\n`);
}

async function inspectOrRepairShareUrls({apply}) {
  const legacyBase = "https://ride-sidecar.com/ride";
  const activeBase = "https://sidecar-fb0e7.web.app/ride";
  const snapshot = await db.collection("rides")
    .where("shareUrl", ">=", legacyBase)
    .where("shareUrl", "<", `${legacyBase}\uf8ff`)
    .get();
  if (apply && !snapshot.empty) {
    const writer = db.bulkWriter();
    for (const document of snapshot.docs) {
      const shareUrl = String(document.data().shareUrl ?? "");
      writer.update(document.ref, {
        shareUrl: `${activeBase}${shareUrl.slice(legacyBase.length)}`,
      });
    }
    await writer.close();
  }
  process.stdout.write(
    `${apply ? "Repaired" : "Found"} ${snapshot.size} legacy ride share URLs in ${projectId}.\n`,
  );
}

async function cleanup() {
  const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
  const bookingId = fixture.QA_BOOKING_ID;
  await Promise.all([
    deleteQuery(db.collection("rides").where("driverId", "==", fixture.QA_DRIVER_UID)),
    deleteQuery(db.collection("bookings").where("driverId", "==", fixture.QA_DRIVER_UID)),
    deleteQuery(db.collection("bookings").where("riderId", "==", fixture.QA_RIDER_UID)),
    bookingId ? db.collection("trip_ratings").doc(bookingId).delete() : undefined,
    bookingId ? db.collection("rider_ratings").doc(bookingId).delete() : undefined,
  ]);
  for (const uid of [fixture.QA_DRIVER_UID, fixture.QA_RIDER_UID]) {
    await db.recursiveDelete(db.collection("users").doc(uid));
    await auth.deleteUser(uid).catch((error) => {
      if (error?.code !== "auth/user-not-found") throw error;
    });
  }
  await Promise.all([iosAppId, androidAppId].map((appId) =>
    unregisterAppCheckDebugToken(
      appId,
      fixture.SIDECAR_APP_CHECK_DEBUG_TOKEN,
    ),
  ));
  await unlink(fixturePath).catch(() => undefined);
  process.stdout.write(`Removed isolated feedback QA fixtures from ${projectId}.\n`);
}

try {
  if (command === "setup") await setup();
  else if (command === "appcheck") await ensureAppCheckDebugToken();
  else if (command === "hydrate") await hydrate();
  else if (command === "inspect") await inspectRoutes();
  else if (command === "inspect-share-urls") {
    await inspectOrRepairShareUrls({apply: false});
  } else if (command === "repair-share-urls") {
    await inspectOrRepairShareUrls({apply: true});
  }
  else if (command === "reset-transient") await resetTransientData();
  else if (command === "cleanup") await cleanup();
  else throw new Error(
    "Use setup, appcheck, hydrate, inspect, inspect-share-urls, repair-share-urls, " +
    "reset-transient, or cleanup.",
  );
} finally {
  await deleteApp(app);
  await unlink(credentialPath).catch(() => undefined);
}
