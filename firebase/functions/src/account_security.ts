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

const activeRideStatuses = new Set(["open", "in_progress"]);
const activeBookingStatuses = new Set([
  "requested",
  "accepted",
  "payment_pending",
  "payment_processing",
  "confirmed",
  "in_progress",
  "cancellation_processing",
  "payout_held",
]);

export function hasOpenAccountObligations(
  rideStatuses: unknown[],
  bookingStatuses: unknown[],
): boolean {
  return rideStatuses.some((value) => activeRideStatuses.has(String(value))) ||
    bookingStatuses.some((value) => activeBookingStatuses.has(String(value)));
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
      rides.docs.map((document) => document.data().status),
      [...bookingDocuments.values()].map((document) => document.data().status),
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
