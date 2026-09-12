import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";

if (getApps().length === 0) initializeApp();

const auth = getAuth();
const db = getFirestore();
const storage = getStorage();
const region = "us-central1";

const activeRideStatuses = new Set(["open", "published", "in_progress"]);
const scheduledBookingStatuses = new Set([
  "pending_driver",
  "accepted_payment_pending",
  "confirmed",
  "in_progress",
]);
const financialBookingStatuses = new Set([
  "payment_processing",
  "cancellation_processing",
  "completion_processing",
  "payout_held",
]);

type AccountObligationRecord = {
  status?: unknown;
  departureAt?: unknown;
};

const staleTripGraceMs = 24 * 60 * 60 * 1000;

function timestampMillis(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (value && typeof value === "object") {
    const timestamp = value as {toMillis?: () => number; toDate?: () => Date};
    if (typeof timestamp.toMillis === "function") return timestamp.toMillis();
    if (typeof timestamp.toDate === "function") return timestamp.toDate().getTime();
  }
  return null;
}

function record(value: unknown): AccountObligationRecord {
  if (value && typeof value === "object") return value as AccountObligationRecord;
  return {status: value};
}

function isCurrentTrip(value: AccountObligationRecord, nowMs: number): boolean {
  const departureAt = timestampMillis(value.departureAt);
  return departureAt === null || departureAt >= nowMs - staleTripGraceMs;
}

export function hasOpenAccountObligations(
  rideRecords: unknown[],
  bookingRecords: unknown[],
  nowMs = Date.now(),
): boolean {
  const ridesBlock = rideRecords.some((value) => {
    const candidate = record(value);
    return activeRideStatuses.has(String(candidate.status)) &&
      isCurrentTrip(candidate, nowMs);
  });
  if (ridesBlock) return true;
  return bookingRecords.some((value) => {
    const candidate = record(value);
    const status = String(candidate.status);
    if (financialBookingStatuses.has(status)) return true;
    return scheduledBookingStatuses.has(status) && isCurrentTrip(candidate, nowMs);
  });
}

export const requestAccountDeletion = onCall(
  {
    region,
    enforceAppCheck: true,
    maxInstances: 10,
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in again.");
    }
    const confirmation = (request.data as {confirmation?: unknown})?.confirmation;
    if (confirmation !== "DELETE") {
      throw new HttpsError("invalid-argument", "Type DELETE to confirm.");
    }

    const authTime = Number(request.auth.token.auth_time ?? 0);
    if (!Number.isFinite(authTime) || Date.now() / 1000 - authTime > 600) {
      throw new HttpsError(
        "failed-precondition",
        "For security, sign out and sign back in before deleting your account.",
      );
    }

    const uid = request.auth.uid;
    const [rides, riderBookings, driverBookings] = await Promise.all([
      db.collection("rides").where("driverId", "==", uid).limit(200).get(),
      db.collection("bookings").where("riderId", "==", uid).limit(200).get(),
      db.collection("bookings").where("driverId", "==", uid).limit(200).get(),
    ]);
    const bookingDocuments = new Map([
      ...riderBookings.docs.map((document) => [document.id, document] as const),
      ...driverBookings.docs.map((document) => [document.id, document] as const),
    ]);
    if (hasOpenAccountObligations(
      rides.docs.map((document) => document.data()),
      [...bookingDocuments.values()].map((document) => document.data()),
    )) {
      throw new HttpsError(
        "failed-precondition",
        "Finish or cancel open trips and wait for pending refunds or payouts first.",
      );
    }

    const conversations = await db.collection("conversations")
      .where("participantIds", "array-contains", uid)
      .limit(200)
      .get();
    await Promise.all(
      conversations.docs.map((document) => db.recursiveDelete(document.ref)),
    );

    const writes = db.batch();
    for (const ride of rides.docs) {
      writes.update(ride.ref, {
        driverName: "Deleted member",
        driverInitials: "SC",
        driverPhotoUrl: "",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    const userReference = db.collection("users").doc(uid);
    writes.set(userReference, {
      accountStatus: "deleted",
      firstName: "Deleted",
      lastName: "member",
      displayName: "Deleted member",
      email: "",
      photoUrl: "",
      profileComplete: false,
      deletedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await writes.commit();

    const userCollections = await userReference.listCollections();
    await Promise.all(
      userCollections.map((collection) => db.recursiveDelete(collection)),
    );
    await storage.bucket().deleteFiles({prefix: `users/${uid}/`});
    await auth.revokeRefreshTokens(uid);
    await auth.deleteUser(uid);
    return {deleted: true};
  },
);
