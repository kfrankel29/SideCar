import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const region = "us-central1";

function userId(value: unknown): string {
  if (typeof value !== "string" || !value.trim() || value.length > 128) {
    throw new HttpsError("invalid-argument", "User is required.");
  }
  return value.trim();
}

export const getPublicProfile = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const targetUserId = userId(request.data?.userId);
    const snapshot = await db.collection("users").doc(targetUserId).get();
    const profile = snapshot.data();
    if (!profile || profile.profileComplete !== true) {
      throw new HttpsError("not-found", "That profile is unavailable.");
    }
    return {
      profile: {
        userId: targetUserId,
        displayName: String(profile.displayName ?? ""),
        photoUrl: String(profile.photoUrl ?? ""),
        age: Number(profile.age ?? 0),
        gender: String(profile.gender ?? ""),
        language: String(profile.language ?? ""),
        rating: Number(profile.rating ?? profile.driverRating ?? 0),
        tripCount: Number(profile.tripCount ?? profile.driverTrips ?? 0),
      },
    };
  },
);
