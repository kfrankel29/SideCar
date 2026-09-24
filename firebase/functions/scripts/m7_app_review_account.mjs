import {createRequire} from "node:module";
import {chmod, readFile, unlink, writeFile} from "node:fs/promises";
import {randomBytes, randomUUID} from "node:crypto";
import {execFileSync} from "node:child_process";
import {dirname, resolve} from "node:path";
import {fileURLToPath} from "node:url";

import {applicationDefault, deleteApp, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

const require = createRequire(import.meta.url);
const projectId = "sidecar-fb0e7";
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const credentialPath = "/tmp/sidecar-m7-firebase-adc.json";
const reviewCredentialPath = "/tmp/sidecar-app-review.json";
const firebaseConfigPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../../apps/mobile/.local/firebase-ios.json",
);
const reviewAvatarPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../../apps/mobile/assets/branding/sidecar-app-icon.png",
);
const storageBucket = JSON.parse(await readFile(firebaseConfigPath, "utf8"))
  .FIREBASE_STORAGE_BUCKET;
const keychainService = "SideCar App Review";
const command = process.argv[2];

const accounts = {
  rider: {
    email: "app-review-sidecar@example.com",
    firstName: "Maya",
    lastName: "Review",
    displayName: "Maya Review",
    gender: "Female",
    primaryRole: "rider",
  },
  driver: {
    email: "app-review-driver-sidecar@example.com",
    firstName: "Jordan",
    lastName: "Review",
    displayName: "Jordan Review",
    gender: "Male",
    primaryRole: "driver",
  },
};

const demoIds = {
  futureRide: "app-review-future-ride",
  requestRide: "app-review-request-ride",
  historyRide: "app-review-history-ride",
  confirmedBooking: "app-review-confirmed-booking",
  pendingBooking: "app-review-pending-booking",
  historyBooking: "app-review-history-booking",
};

let cliAuth;
let cliApi;
let account;
if (firebaseToolsRoot) {
  cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
  cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
  account = cliAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Run firebase login before managing App Review accounts.");
  }
  await writeFile(credentialPath, JSON.stringify({
    client_id: cliApi.clientId(),
    client_secret: cliApi.clientSecret(),
    refresh_token: account.tokens.refresh_token,
    type: "authorized_user",
  }), {mode: 0o600});
  await chmod(credentialPath, 0o600);
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
} else if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error(
    "Set GOOGLE_APPLICATION_CREDENTIALS or SIDECAR_FIREBASE_TOOLS_ROOT.",
  );
}

const app = initializeApp({projectId, credential: applicationDefault()});
const auth = getAuth(app);
const db = getFirestore(app);

function reviewPassword() {
  return `${randomBytes(20).toString("base64url")}Aa1!`;
}

function encodePolyline(points) {
  let previousLatitude = 0;
  let previousLongitude = 0;
  let encoded = "";
  const encodeValue = (input) => {
    let value = input < 0 ? ~(input << 1) : input << 1;
    let result = "";
    while (value >= 0x20) {
      result += String.fromCharCode((0x20 | (value & 0x1f)) + 63);
      value >>= 5;
    }
    return result + String.fromCharCode(value + 63);
  };
  for (const [latitude, longitude] of points) {
    const nextLatitude = Math.round(latitude * 1e5);
    const nextLongitude = Math.round(longitude * 1e5);
    encoded += encodeValue(nextLatitude - previousLatitude);
    encoded += encodeValue(nextLongitude - previousLongitude);
    previousLatitude = nextLatitude;
    previousLongitude = nextLongitude;
  }
  return encoded;
}

function conversationId(left, right) {
  return `pair_${[left.trim(), right.trim()].sort().join("_")}`;
}

function profileData(definition, photoUrl) {
  return {
    email: definition.email,
    firstName: definition.firstName,
    lastName: definition.lastName,
    displayName: definition.displayName,
    school: "University of California, Santa Barbara",
    age: 24,
    gender: definition.gender,
    language: "English",
    photoUrl,
    primaryRole: definition.primaryRole,
    profileComplete: true,
    accountStatus: "active",
    acceptedLegalTerms: true,
    confirmedAge18: true,
    legalVersion: "2026-09-03",
    creditCents: 1_000,
    driverRating: definition.primaryRole === "driver" ? 4.9 : 0,
    driverRatingCount: definition.primaryRole === "driver" ? 18 : 0,
    driverTrips: definition.primaryRole === "driver" ? 27 : 0,
    riderRating: definition.primaryRole === "rider" ? 4.8 : 0,
    riderRatingCount: definition.primaryRole === "rider" ? 12 : 0,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function writeProfile(user, definition) {
  const objectPath = `app-review/profile-avatars/${user.uid}.png`;
  const downloadToken = randomUUID();
  await getStorage(app).bucket(storageBucket).file(objectPath).save(
    await readFile(reviewAvatarPath),
    {
      contentType: "image/png",
      metadata: {metadata: {firebaseStorageDownloadTokens: downloadToken}},
    },
  );
  const photoUrl = `https://firebasestorage.googleapis.com/v0/b/${storageBucket}` +
    `/o/${encodeURIComponent(objectPath)}?alt=media&token=${downloadToken}`;
  const reference = db.collection("users").doc(user.uid);
  await Promise.all([
    reference.set({
      ...profileData(definition, photoUrl),
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
    reference.collection("verifications").doc("current").set({
      identityStatus: "verified",
      insuranceStatus: "verified",
      insuranceVerificationProvider: "app-review",
      identityVerifiedAt: FieldValue.serverTimestamp(),
      insuranceVerifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
    reference.collection("vehicles").doc("primary").set({
      complete: true,
      make: "Honda",
      model: "Civic",
      year: 2024,
      color: "Blue",
      seats: 4,
      licensePlate: "REVIEW",
      photoUrl: "",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
  ]);
}

async function provisionAccount(definition) {
  const password = reviewPassword();
  let user;
  try {
    user = await auth.getUserByEmail(definition.email);
    user = await auth.updateUser(user.uid, {
      password,
      emailVerified: true,
      disabled: false,
      displayName: definition.displayName,
    });
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    user = await auth.createUser({
      email: definition.email,
      password,
      emailVerified: true,
      displayName: definition.displayName,
    });
  }
  await auth.setCustomUserClaims(user.uid, {
    schoolEmailVerified: true,
    appReviewDemo: true,
  });
  await writeProfile(user, definition);
  execFileSync("/usr/bin/security", [
    "add-generic-password",
    "-U",
    "-a",
    definition.email,
    "-s",
    keychainService,
    "-w",
    password,
  ], {stdio: "ignore"});
  return {email: definition.email, password, uid: user.uid};
}

async function existingAccounts() {
  const [rider, driver] = await Promise.all([
    auth.getUserByEmail(accounts.rider.email),
    auth.getUserByEmail(accounts.driver.email),
  ]);
  return {rider, driver};
}

async function deleteQuery(query) {
  const snapshot = await query.get();
  const writer = db.bulkWriter();
  for (const document of snapshot.docs) writer.delete(document.ref);
  await writer.close();
  return snapshot.size;
}

async function deleteReviewData(reviewAccounts) {
  const uids = [reviewAccounts.rider.uid, reviewAccounts.driver.uid];
  const bookingSnapshots = await Promise.all([
    db.collection("bookings").where("riderId", "in", uids).get(),
    db.collection("bookings").where("driverId", "in", uids).get(),
  ]);
  const bookingIds = [...new Set(bookingSnapshots.flatMap((snapshot) =>
    snapshot.docs.map((document) => document.id)))].filter(Boolean);
  const conversationSnapshots = await Promise.all(uids.map((uid) =>
    db.collection("conversations")
      .where("participantIds", "array-contains", uid).get()));
  const conversations = new Map(conversationSnapshots.flatMap((snapshot) =>
    snapshot.docs.map((document) => [document.ref.path, document])));

  for (const document of conversations.values()) {
    await db.recursiveDelete(document.ref);
  }
  await Promise.all([
    ...uids.map((uid) => deleteQuery(
      db.collection("rides").where("driverId", "==", uid),
    )),
    ...uids.map((uid) => deleteQuery(
      db.collection("notifications").where("userId", "==", uid),
    )),
    ...uids.map((uid) => deleteQuery(
      db.collection("ride_search_alerts").where("userId", "==", uid),
    )),
    ...uids.map((uid) => deleteQuery(
      db.collection("safetyReports").where("reporterUid", "==", uid),
    )),
    ...uids.map((uid) => deleteQuery(
      db.collection("safetyReports").where("reportedUid", "==", uid),
    )),
    ...uids.map((uid) => db.recursiveDelete(
      db.collection("users").doc(uid).collection("blockedUsers"),
    )),
    ...uids.map((uid) => db.recursiveDelete(
      db.collection("users").doc(uid).collection("devices"),
    )),
  ]);
  const writer = db.bulkWriter();
  for (const snapshot of bookingSnapshots) {
    for (const document of snapshot.docs) writer.delete(document.ref);
  }
  for (const id of bookingIds) {
    writer.delete(db.collection("trip_ratings").doc(id));
    writer.delete(db.collection("rider_ratings").doc(id));
  }
  for (const uid of uids) {
    writer.delete(db.collection("referral_redemptions").doc(uid));
    writer.delete(db.collection("payment_accounts").doc(uid));
  }
  await writer.close();
  return {bookings: bookingIds.length, conversations: conversations.size};
}

function rideData({driver, departureAt, status, seatsAvailable, bookedSeats}) {
  const origin = {
    placeId: "sidecar-review-ucsb",
    displayName: "UC Santa Barbara",
    formattedAddress: "University of California, Santa Barbara, CA 93106",
    latitude: 34.4140,
    longitude: -119.8489,
  };
  const destination = {
    placeId: "sidecar-review-lax",
    displayName: "Los Angeles International Airport",
    formattedAddress: "1 World Way, Los Angeles, CA 90045",
    latitude: 33.9416,
    longitude: -118.4085,
  };
  return {
    driverId: driver.uid,
    driverName: accounts.driver.displayName,
    driverInitials: "JR",
    driverPhotoUrl: "",
    driverGender: "Male",
    driverLanguage: "English",
    driverRating: 4.9,
    driverTrips: 27,
    vehicle: {
      makeAndModel: "Honda Civic",
      year: 2024,
      color: "Blue",
      photoUrl: "",
    },
    origin,
    destination,
    departureAt,
    distanceMiles: 103,
    durationSeconds: 7_800,
    seatsTotal: 3,
    seatsAvailable,
    bookedSeats,
    pricePerSeatCents: 3_500,
    maximumPriceCents: 7_800,
    luggageAllowance: "one_suitcase",
    genderRestriction: "any",
    status,
    appReviewFixture: true,
    shareUrl: "https://sidecar-fb0e7.web.app/ride",
    encodedPolyline: encodePolyline([
      [34.4140, -119.8489],
      [34.3370, -119.2780],
      [34.0522, -118.2437],
      [33.9416, -118.4085],
    ]),
    repeatWeekly: false,
    recurrenceId: "",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function bookingData({rider, driver, rideId, departureAt, status}) {
  const origin = {
    placeId: "sidecar-review-ucsb",
    displayName: "UC Santa Barbara",
    formattedAddress: "University of California, Santa Barbara, CA 93106",
    latitude: 34.4140,
    longitude: -119.8489,
  };
  const destination = {
    placeId: "sidecar-review-lax",
    displayName: "Los Angeles International Airport",
    formattedAddress: "1 World Way, Los Angeles, CA 90045",
    latitude: 33.9416,
    longitude: -118.4085,
  };
  const completed = status === "completed";
  const confirmed = status === "confirmed";
  const now = Timestamp.now();
  return {
    rideId,
    riderId: rider.uid,
    riderName: accounts.rider.displayName,
    riderInitials: "MR",
    riderPhotoUrl: "",
    driverId: driver.uid,
    driverName: accounts.driver.displayName,
    driverPhotoUrl: "",
    originName: origin.displayName,
    destinationName: destination.displayName,
    seatKey: "front",
    seatLabel: "Front",
    pickupLocation: origin,
    dropoffLocation: destination,
    departureAt,
    baseFareCents: 3_500,
    serviceFeeCents: 175,
    driverPlatformFeeCents: 175,
    processingFeeCents: 140,
    totalCents: 3_815,
    driverPayoutCents: 3_325,
    paymentMethod: "card",
    paymentStatus: completed || confirmed ? "paid" : "",
    payoutStatus: completed ? "paid" : confirmed ? "pending" : "",
    status,
    appReviewFixture: true,
    ...(completed ? {
      acceptedAt: now,
      confirmedAt: now,
      startedAt: now,
      completedAt: now,
      ratedAt: now,
      riderRatedAt: now,
      paidOutAt: now,
    } : {}),
    ...(confirmed ? {acceptedAt: now, confirmedAt: now} : {}),
    createdAt: now,
    updatedAt: now,
  };
}

async function reviewReferralCode(driverUid) {
  for (let code = 98_000; code < 100_000; code += 1) {
    const id = String(code);
    const reference = db.collection("referral_codes").doc(id);
    const snapshot = await reference.get();
    if (!snapshot.exists || snapshot.data()?.ownerUid === driverUid) {
      await reference.set({
        ownerUid: driverUid,
        appReviewFixture: true,
        createdAt: FieldValue.serverTimestamp(),
      });
      return id;
    }
  }
  throw new Error("No reserved App Review referral code is available.");
}

async function seedReviewData(reviewAccounts) {
  const now = Date.now();
  const futureDeparture = Timestamp.fromMillis(now + 14 * 24 * 60 * 60 * 1_000);
  const requestDeparture = Timestamp.fromMillis(now + 21 * 24 * 60 * 60 * 1_000);
  const historyDeparture = Timestamp.fromMillis(now - 14 * 24 * 60 * 60 * 1_000);
  const {rider, driver} = reviewAccounts;
  await Promise.all([
    writeProfile(rider, accounts.rider),
    writeProfile(driver, accounts.driver),
  ]);
  const referralCode = await reviewReferralCode(driver.uid);
  await db.collection("users").doc(driver.uid).set({
    referralCode,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const conversation = conversationId(rider.uid, driver.uid);
  const timestamp = Timestamp.now();
  const batch = db.batch();
  batch.set(db.collection("rides").doc(demoIds.futureRide), rideData({
    driver,
    departureAt: futureDeparture,
    status: "published",
    seatsAvailable: 2,
    bookedSeats: 1,
  }));
  batch.set(db.collection("rides").doc(demoIds.requestRide), rideData({
    driver,
    departureAt: requestDeparture,
    status: "published",
    seatsAvailable: 3,
    bookedSeats: 0,
  }));
  batch.set(db.collection("rides").doc(demoIds.historyRide), rideData({
    driver,
    departureAt: historyDeparture,
    status: "completed",
    seatsAvailable: 0,
    bookedSeats: 1,
  }));
  batch.set(db.collection("bookings").doc(demoIds.confirmedBooking), bookingData({
    rider,
    driver,
    rideId: demoIds.futureRide,
    departureAt: futureDeparture,
    status: "confirmed",
  }));
  batch.set(db.collection("bookings").doc(demoIds.pendingBooking), bookingData({
    rider,
    driver,
    rideId: demoIds.requestRide,
    departureAt: requestDeparture,
    status: "pending_driver",
  }));
  batch.set(db.collection("bookings").doc(demoIds.historyBooking), bookingData({
    rider,
    driver,
    rideId: demoIds.historyRide,
    departureAt: historyDeparture,
    status: "completed",
  }));
  batch.set(db.collection("trip_ratings").doc(demoIds.historyBooking), {
    bookingId: demoIds.historyBooking,
    rideId: demoIds.historyRide,
    riderId: rider.uid,
    driverId: driver.uid,
    driverRating: 5,
    tripRating: 5,
    comment: "Smooth and safe trip.",
    createdAt: timestamp,
  });
  batch.set(db.collection("rider_ratings").doc(demoIds.historyBooking), {
    bookingId: demoIds.historyBooking,
    rideId: demoIds.historyRide,
    riderId: rider.uid,
    driverId: driver.uid,
    rating: 5,
    comment: "Friendly and punctual rider.",
    createdAt: timestamp,
  });
  batch.set(db.collection("conversations").doc(conversation), {
    bookingId: demoIds.confirmedBooking,
    rideId: demoIds.futureRide,
    pairKey: [rider.uid, driver.uid].sort().join("::"),
    participantIds: [rider.uid, driver.uid],
    participantNames: {
      [rider.uid]: accounts.rider.displayName,
      [driver.uid]: accounts.driver.displayName,
    },
    participantInitials: {[rider.uid]: "MR", [driver.uid]: "JR"},
    participantPhotoUrls: {[rider.uid]: "", [driver.uid]: ""},
    tripLabel: "UC Santa Barbara → Los Angeles International Airport",
    departureAt: futureDeparture,
    unreadCounts: {[rider.uid]: 0, [driver.uid]: 1},
    hiddenFor: {},
    lastMessage: "Perfect — I’ll meet you at the library pickup point.",
    lastMessageAt: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
  });
  batch.set(
    db.collection("conversations").doc(conversation)
      .collection("messages").doc("welcome-rider"),
    {
      senderId: rider.uid,
      recipientId: driver.uid,
      text: "Hi Jordan, is the front seat still available?",
      createdAt: Timestamp.fromMillis(now - 10 * 60 * 1_000),
    },
  );
  batch.set(
    db.collection("conversations").doc(conversation)
      .collection("messages").doc("welcome-driver"),
    {
      senderId: driver.uid,
      recipientId: rider.uid,
      text: "Perfect — I’ll meet you at the library pickup point.",
      createdAt: timestamp,
    },
  );
  batch.set(db.collection("notifications").doc("app-review-driver-request"), {
    userId: driver.uid,
    type: "seat_requested",
    data: {bookingId: demoIds.pendingBooking, rideId: demoIds.requestRide},
    read: false,
    createdAt: timestamp,
    appReviewFixture: true,
  });
  batch.set(db.collection("notifications").doc("app-review-rider-confirmed"), {
    userId: rider.uid,
    type: "payment_confirmed",
    data: {bookingId: demoIds.confirmedBooking, rideId: demoIds.futureRide},
    read: false,
    createdAt: timestamp,
    appReviewFixture: true,
  });
  batch.set(db.collection("payment_accounts").doc(driver.uid), {
    chargesEnabled: true,
    payoutsEnabled: true,
    detailsSubmitted: true,
    bankName: "App Review Demo Bank",
    last4: "4242",
    appReviewFixture: true,
    updatedAt: timestamp,
  });
  await batch.commit();
  return {conversation, referralCode};
}

function keychainPassword(email) {
  return execFileSync("/usr/bin/security", [
    "find-generic-password",
    "-a",
    email,
    "-s",
    keychainService,
    "-w",
  ], {encoding: "utf8"}).trim();
}

async function restoreAccount(definition) {
  const password = keychainPassword(definition.email);
  let user;
  try {
    user = await auth.getUserByEmail(definition.email);
    user = await auth.updateUser(user.uid, {
      password,
      emailVerified: true,
      disabled: false,
      displayName: definition.displayName,
    });
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    user = await auth.createUser({
      email: definition.email,
      password,
      emailVerified: true,
      displayName: definition.displayName,
    });
  }
  await auth.setCustomUserClaims(user.uid, {
    schoolEmailVerified: true,
    appReviewDemo: true,
  });
  await writeProfile(user, definition);
  return {email: definition.email, password, uid: user.uid};
}

async function writeReviewCredentials(rider, driver, fixture) {
  await writeFile(reviewCredentialPath, `${JSON.stringify({
    projectId,
    keychainService,
    rider: {email: rider.email, password: rider.password, uid: rider.uid},
    driver: {email: driver.email, password: driver.password, uid: driver.uid},
    demoIds,
    ...fixture,
  })}\n`, {mode: 0o600});
  await chmod(reviewCredentialPath, 0o600);
}

async function setup() {
  const [rider, driver] = await Promise.all([
    provisionAccount(accounts.rider),
    provisionAccount(accounts.driver),
  ]);
  await deleteReviewData({rider, driver});
  const fixture = await seedReviewData({rider, driver});
  await writeReviewCredentials(rider, driver, fixture);
  process.stdout.write(
    `Provisioned rider and driver App Review accounts and reset demo data in ${projectId}.\n`,
  );
}

async function reset() {
  const [rider, driver] = await Promise.all([
    restoreAccount(accounts.rider),
    restoreAccount(accounts.driver),
  ]);
  const reviewAccounts = {rider, driver};
  await deleteReviewData(reviewAccounts);
  const fixture = await seedReviewData(reviewAccounts);
  await writeReviewCredentials(rider, driver, fixture);
  process.stdout.write(`Reset persistent App Review demo data in ${projectId}.\n`);
}

async function deleteData() {
  const reviewAccounts = await existingAccounts();
  const removed = await deleteReviewData(reviewAccounts);
  process.stdout.write(
    `Removed App Review demo data from ${projectId} ` +
    `(${removed.bookings} bookings, ${removed.conversations} conversations); ` +
    "the two login accounts remain active.\n",
  );
}

async function inspect() {
  const reviewAccounts = await existingAccounts();
  const [rides, riderBookings, driverBookings, riderProfile, driverProfile] =
    await Promise.all([
      db.collection("rides").where("driverId", "==", reviewAccounts.driver.uid).get(),
      db.collection("bookings").where("riderId", "==", reviewAccounts.rider.uid).get(),
      db.collection("bookings").where("driverId", "==", reviewAccounts.driver.uid).get(),
      db.collection("users").doc(reviewAccounts.rider.uid).get(),
      db.collection("users").doc(reviewAccounts.driver.uid).get(),
    ]);
  for (const [role, snapshot] of [["rider", riderProfile], ["driver", driverProfile]]) {
    const profile = snapshot.data();
    if (!profile || !profile.photoUrl || Number(profile.age) < 18 ||
        !profile.firstName || !profile.lastName || !profile.language) {
      throw new Error(`${role} App Review profile cannot pass the mobile profile gate.`);
    }
  }
  process.stdout.write(`${JSON.stringify({
    projectId,
    accounts: {
      rider: {
        email: reviewAccounts.rider.email,
        enabled: !reviewAccounts.rider.disabled,
        verified: reviewAccounts.rider.emailVerified,
        role: riderProfile.data()?.primaryRole ?? "",
      },
      driver: {
        email: reviewAccounts.driver.email,
        enabled: !reviewAccounts.driver.disabled,
        verified: reviewAccounts.driver.emailVerified,
        role: driverProfile.data()?.primaryRole ?? "",
      },
    },
    rides: rides.size,
    riderBookings: riderBookings.size,
    driverBookings: driverBookings.size,
  }, null, 2)}\n`);
}

async function smoke() {
  if (!cliAuth || !cliApi || !account?.tokens?.refresh_token) {
    throw new Error("The smoke command requires SIDECAR_FIREBASE_TOOLS_ROOT.");
  }
  const [reviewAccounts, firebaseConfigJson] = await Promise.all([
    existingAccounts(),
    readFile(firebaseConfigPath, "utf8"),
  ]);
  const credentials = Object.fromEntries(
    Object.entries(reviewAccounts).map(([role, user]) => [role, {
      email: user.email,
      uid: user.uid,
      password: execFileSync("/usr/bin/security", [
        "find-generic-password", "-a", user.email,
        "-s", keychainService, "-w",
      ], {encoding: "utf8"}).trim(),
    }]),
  );
  const firebaseConfig = JSON.parse(firebaseConfigJson);
  const apiKey = firebaseConfig.FIREBASE_API_KEY;
  if (!apiKey) throw new Error("FIREBASE_API_KEY is missing from the local iOS config.");

  const results = {};
  const sessions = {};
  for (const role of ["rider", "driver"]) {
    const credential = credentials[role];
    const response = await fetch(
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword" +
      `?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          email: credential.email,
          password: credential.password,
          returnSecureToken: true,
        }),
      },
    );
    const body = await response.json();
    if (!response.ok || body.localId !== credential.uid) {
      throw new Error(`${role} App Review sign-in failed.`);
    }
    sessions[role] = body;
    results[role] = {email: credential.email, authenticated: true};
  }

  const firebaseAppId = firebaseConfig.FIREBASE_APP_ID;
  if (!firebaseAppId) throw new Error("FIREBASE_APP_ID is missing from the local iOS config.");
  const access = await cliAuth.getAccessToken(
    account.tokens.refresh_token,
    cliApi.getScopes(),
  );
  const debugToken = randomUUID();
  const appResource = `projects/${projectId}/apps/${firebaseAppId}`;
  const registrationResponse = await fetch(
    `https://firebaseappcheck.googleapis.com/v1/${appResource}/debugTokens`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${access.access_token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        displayName: `M7 App Review smoke ${Date.now()}`,
        token: debugToken,
      }),
    },
  );
  const registration = await registrationResponse.json();
  if (!registrationResponse.ok || !registration.name) {
    throw new Error("Unable to register the temporary App Check smoke token.");
  }
  try {
    const exchangeResponse = await fetch(
      `https://firebaseappcheck.googleapis.com/v1/${appResource}:exchangeDebugToken` +
      `?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({debug_token: debugToken}),
      },
    );
    const exchange = await exchangeResponse.json();
    if (!exchangeResponse.ok || !exchange.token) {
      throw new Error("Unable to exchange the temporary App Check smoke token.");
    }
    const payoutResponse = await fetch(
      `https://us-central1-${projectId}.cloudfunctions.net/getDriverPayoutStatus`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${sessions.driver.idToken}`,
          "content-type": "application/json",
          "x-firebase-appcheck": exchange.token,
        },
        body: JSON.stringify({data: {}}),
      },
    );
    const payoutBody = await payoutResponse.json();
    const payout = payoutBody.result;
    if (!payoutResponse.ok || payout?.connected !== true ||
        payout?.payoutsEnabled !== true || payout?.last4 !== "4242") {
      throw new Error("The deployed App Review payout demo check failed.");
    }
    results.driver.payoutDemo = true;

    const achResponse = await fetch(
      `https://us-central1-${projectId}.cloudfunctions.net/createPaymentMethodSetup`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${sessions.rider.idToken}`,
          "content-type": "application/json",
          "x-firebase-appcheck": exchange.token,
        },
        body: JSON.stringify({data: {paymentMethod: "bank"}}),
      },
    );
    const achBody = await achResponse.json();
    if (achBody.error?.status !== "FAILED_PRECONDITION" ||
        !String(achBody.error?.message ?? "").includes("temporarily unavailable")) {
      throw new Error("The deployed ACH shutdown check failed.");
    }
    results.rider.achDisabled = true;

    const cardResponse = await fetch(
      `https://us-central1-${projectId}.cloudfunctions.net/createPaymentMethodSetup`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${sessions.rider.idToken}`,
          "content-type": "application/json",
          "x-firebase-appcheck": exchange.token,
        },
        body: JSON.stringify({data: {paymentMethod: "card"}}),
      },
    );
    const cardBody = await cardResponse.json();
    const cardSetup = cardBody.result;
    if (!cardResponse.ok ||
        !String(cardSetup?.publishableKey ?? "").startsWith("pk_live_") ||
        !String(cardSetup?.clientSecret ?? "").startsWith("seti_") ||
        !String(cardSetup?.customerId ?? "").startsWith("cus_") ||
        !cardSetup?.ephemeralKeySecret) {
      throw new Error("The deployed live card setup check failed.");
    }
    results.rider.liveCardSetup = true;
  } finally {
    await fetch(`https://firebaseappcheck.googleapis.com/v1/${registration.name}`, {
      method: "DELETE",
      headers: {authorization: `Bearer ${access.access_token}`},
    });
  }
  process.stdout.write(`${JSON.stringify({projectId, results}, null, 2)}\n`);
}

async function cleanup() {
  const reviewAccounts = await existingAccounts();
  await deleteReviewData(reviewAccounts);
  const referralCodes = await db.collection("referral_codes")
    .where("ownerUid", "in", [reviewAccounts.rider.uid, reviewAccounts.driver.uid])
    .get();
  const writer = db.bulkWriter();
  for (const document of referralCodes.docs) writer.delete(document.ref);
  await writer.close();
  for (const definition of Object.values(accounts)) {
    const user = await auth.getUserByEmail(definition.email);
    await getStorage(app).bucket(storageBucket)
      .file(`app-review/profile-avatars/${user.uid}.png`)
      .delete({ignoreNotFound: true});
    await db.recursiveDelete(db.collection("users").doc(user.uid));
    await auth.deleteUser(user.uid);
    try {
      execFileSync("/usr/bin/security", [
        "delete-generic-password",
        "-a",
        definition.email,
        "-s",
        keychainService,
      ], {stdio: "ignore"});
    } catch {
      // A missing Keychain item is already clean.
    }
  }
  await unlink(reviewCredentialPath).catch(() => undefined);
  process.stdout.write(`Removed both App Review accounts and demo data from ${projectId}.\n`);
}

try {
  if (command === "setup") await setup();
  else if (command === "reset") await reset();
  else if (command === "delete-data") await deleteData();
  else if (command === "inspect") await inspect();
  else if (command === "smoke") await smoke();
  else if (command === "cleanup") await cleanup();
  else throw new Error("Use setup, reset, delete-data, inspect, smoke, or cleanup.");
} finally {
  await deleteApp(app);
  await unlink(credentialPath).catch(() => undefined);
}
