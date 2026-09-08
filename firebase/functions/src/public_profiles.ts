import {getApps, initializeApp} from "firebase-admin/app";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
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

type PublicReview = {
  reviewId: string;
  reviewerId: string;
  rating: number;
  comment: string;
  createdAt: Timestamp | null;
};

function reviewTimestamp(value: unknown): Timestamp | null {
  return value instanceof Timestamp ? value : null;
}

export const getPublicProfile = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const targetUserId = userId(request.data?.userId);
    const snapshot = await db.collection("users").doc(targetUserId).get();
    const profile = snapshot.data();
    if (!profile ||
        profile.profileComplete !== true ||
        profile.accountStatus === "deleted") {
      throw new HttpsError("not-found", "That profile is unavailable.");
    }
    const [driverReviews, riderReviews] = await Promise.all([
      db.collection("trip_ratings").where("driverId", "==", targetUserId).limit(50).get(),
      db.collection("rider_ratings").where("riderId", "==", targetUserId).limit(50).get(),
    ]);
    const reviews: PublicReview[] = [
      ...driverReviews.docs.map((document) => {
        const data = document.data();
        return {
          reviewId: document.id,
          reviewerId: String(data.riderId ?? ""),
          rating: Number(data.driverRating ?? 0),
          comment: String(data.comment ?? "").trim(),
          createdAt: reviewTimestamp(data.createdAt),
        };
      }),
      ...riderReviews.docs.map((document) => {
        const data = document.data();
        return {
          reviewId: document.id,
          reviewerId: String(data.driverId ?? ""),
          rating: Number(data.rating ?? 0),
          comment: String(data.comment ?? "").trim(),
          createdAt: reviewTimestamp(data.createdAt),
        };
      }),
    ].filter((review) => review.reviewerId && review.rating >= 1 && review.rating <= 5)
      .sort((first, second) =>
        (second.createdAt?.toMillis() ?? 0) - (first.createdAt?.toMillis() ?? 0),
      )
      .slice(0, 20);
    const reviewerIds = [...new Set(reviews.map((review) => review.reviewerId))];
    const reviewerSnapshots = await Promise.all(
      reviewerIds.map((id) => db.collection("users").doc(id).get()),
    );
    const reviewers = new Map(reviewerSnapshots.map((document) => [
      document.id,
      document.data() ?? {},
    ]));
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
        reviews: reviews.map((review) => {
          const reviewer = reviewers.get(review.reviewerId) ?? {};
          return {
            reviewId: review.reviewId,
            reviewerName: String(reviewer.displayName ?? "SideCar rider"),
            reviewerPhotoUrl: String(reviewer.photoUrl ?? ""),
            rating: review.rating,
            comment: review.comment,
            createdAt: review.createdAt?.toDate().toISOString() ?? "",
          };
        }),
      },
    };
  },
);
