import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  RouteWaypoint,
  cumulativeArrivalSeconds,
  googleWaypoint,
  parseOptimizedRoute,
} from "./live_trip_route.js";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
export const liveTripMapsSecret = defineSecret("GOOGLE_MAPS_API_KEY");
const region = "us-central1";

type Json = Record<string, unknown>;
type TripPhase = "pickups" | "dropoffs" | "complete";

interface TripBooking {
  id: string;
  riderId: string;
  riderName: string;
  pickup: TripLocation;
  dropoff: TripLocation;
  pickedUp: boolean;
}

interface TripLocation extends RouteWaypoint {
  displayName: string;
  formattedAddress: string;
}

function object(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Json : {};
}

function requiredString(value: unknown, label: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpsError("failed-precondition", `${label} is unavailable.`);
  }
  return value.trim();
}

function tripLocation(value: unknown, label: string): TripLocation {
  const data = object(value);
  const latitude = Number(data.latitude);
  const longitude = Number(data.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpsError("failed-precondition", `${label} is unavailable.`);
  }
  return {
    placeId: typeof data.placeId === "string" ? data.placeId : "",
    displayName: requiredString(data.displayName, label),
    formattedAddress: requiredString(data.formattedAddress, label),
    latitude,
    longitude,
  };
}

function iso(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

function publicStop(value: unknown): Json {
  const stop = object(value);
  return {
    bookingId: stop.bookingId,
    riderId: stop.riderId,
    riderName: stop.riderName,
    kind: stop.kind,
    order: stop.order,
    location: stop.location,
    eta: iso(stop.eta),
    completedAt: iso(stop.completedAt),
  };
}

function publicPlan(value: unknown): Json {
  const plan = object(value);
  return {
    phase: plan.phase,
    startedAt: iso(plan.startedAt),
    updatedAt: iso(plan.updatedAt),
    pickupStops: Array.isArray(plan.pickupStops) ? plan.pickupStops.map(publicStop) : [],
    dropoffStops: Array.isArray(plan.dropoffStops) ? plan.dropoffStops.map(publicStop) : [],
    pickupPolyline: plan.pickupPolyline ?? "",
    dropoffPolyline: plan.dropoffPolyline ?? "",
  };
}

async function mapsRoute(
  origin: TripLocation,
  destination: TripLocation,
  intermediates: TripLocation[],
) {
  if (intermediates.length === 0) {
    return parseOptimizedRoute({routes: [{legs: []}]}, 0);
  }
  let response: Response;
  try {
    response = await fetch(
      "https://routes.googleapis.com/directions/v2:computeRoutes",
      {
        method: "POST",
        signal: AbortSignal.timeout(15_000),
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": liveTripMapsSecret.value(),
          "X-Goog-FieldMask": [
            "routes.optimizedIntermediateWaypointIndex",
            "routes.legs.duration",
            "routes.polyline.encodedPolyline",
          ].join(","),
        },
        body: JSON.stringify({
          origin: googleWaypoint(origin),
          destination: googleWaypoint(destination),
          intermediates: intermediates.map(googleWaypoint),
          travelMode: "DRIVE",
          routingPreference: "TRAFFIC_AWARE",
          optimizeWaypointOrder: true,
          computeAlternativeRoutes: false,
          languageCode: "en-US",
          units: "IMPERIAL",
        }),
      },
    );
  } catch {
    throw new HttpsError("unavailable", "The live route is temporarily unavailable. Try again.");
  }
  if (!response.ok) {
    throw new HttpsError("unavailable", "Google Maps could not optimize this trip. Try again.");
  }
  const payload = await response.json() as unknown;
  const parsed = parseOptimizedRoute(object(payload), intermediates.length);
  if (parsed.legDurationSeconds.length < intermediates.length) {
    throw new HttpsError("unavailable", "Google Maps could not calculate all stop ETAs.");
  }
  return parsed;
}

async function tripBookings(rideId: string): Promise<TripBooking[]> {
  const snapshot = await db.collection("bookings")
    .where("rideId", "==", rideId)
    .limit(10)
    .get();
  return snapshot.docs
    .filter((document) => ["confirmed", "in_progress", "completed"]
      .includes(String(document.data().status)))
    .map((document) => {
      const booking = document.data();
      return {
        id: document.id,
        riderId: requiredString(booking.riderId, "Rider"),
        riderName: requiredString(booking.riderName, "Rider name"),
        pickup: tripLocation(booking.pickupLocation, "Pickup address"),
        dropoff: tripLocation(booking.dropoffLocation, "Drop-off address"),
        pickedUp: ["in_progress", "completed"].includes(String(booking.status)),
      };
    });
}

function stop(
  booking: TripBooking,
  kind: "pickup" | "dropoff",
  order: number,
  etaMillis: number,
  completedAt: Timestamp | null = null,
): Json {
  return {
    bookingId: booking.id,
    riderId: booking.riderId,
    riderName: booking.riderName,
    kind,
    order,
    location: kind === "pickup" ? booking.pickup : booking.dropoff,
    eta: Timestamp.fromMillis(etaMillis),
    completedAt,
  };
}

async function buildPlan(
  ride: Json,
  bookings: TripBooking[],
  startedAt: Timestamp,
): Promise<Json> {
  if (bookings.length === 0) {
    throw new HttpsError("failed-precondition", "This ride has no confirmed riders yet.");
  }
  const origin = tripLocation(ride.origin, "Ride departure point");
  const destination = tripLocation(ride.destination, "Ride destination");
  const pickupRoute = await mapsRoute(origin, destination, bookings.map((item) => item.pickup));
  const pickupArrivals = cumulativeArrivalSeconds(pickupRoute, bookings.length);
  const orderedPickups = pickupRoute.orderedIndexes.map((index) => bookings[index]!);
  const lastPickup = orderedPickups.at(-1)?.pickup ?? origin;
  const pickupEndSeconds = pickupArrivals.at(-1) ?? 0;
  const dropoffRoute = await mapsRoute(
    lastPickup,
    destination,
    bookings.map((item) => item.dropoff),
  );
  const dropoffArrivals = cumulativeArrivalSeconds(dropoffRoute, bookings.length);
  const orderedDropoffs = dropoffRoute.orderedIndexes.map((index) => bookings[index]!);
  const startMillis = startedAt.toMillis();
  const pickupStops = orderedPickups.map((booking, index) => stop(
    booking,
    "pickup",
    index,
    startMillis + (pickupArrivals[index] ?? 0) * 1_000,
    booking.pickedUp ? startedAt : null,
  ));
  const dropoffStops = orderedDropoffs.map((booking, index) => stop(
    booking,
    "dropoff",
    index,
    startMillis + (pickupEndSeconds + (dropoffArrivals[index] ?? 0)) * 1_000,
  ));
  const phase: TripPhase = bookings.every((booking) => booking.pickedUp) ?
    "dropoffs" : "pickups";
  return {
    phase,
    startedAt,
    updatedAt: Timestamp.now(),
    pickupStops,
    dropoffStops,
    pickupPolyline: pickupRoute.encodedPolyline,
    dropoffPolyline: dropoffRoute.encodedPolyline,
  };
}

async function authorizeTripViewer(rideId: string, uid: string): Promise<Json> {
  const rideSnapshot = await db.collection("rides").doc(rideId).get();
  const ride = rideSnapshot.data();
  if (!ride) throw new HttpsError("not-found", "That ride is unavailable.");
  if (ride.driverId === uid) return ride;
  const participant = await db.collection("bookings")
    .where("rideId", "==", rideId)
    .where("riderId", "==", uid)
    .limit(10)
    .get();
  const isParticipant = participant.docs.some((document) =>
    ["confirmed", "in_progress", "completed"]
      .includes(String(document.data().status)));
  if (isParticipant) return ride;
  throw new HttpsError("permission-denied", "You cannot view this live trip.");
}

export const startLiveTrip = onCall(
  {
    region,
    enforceAppCheck: true,
    secrets: [liveTripMapsSecret],
    timeoutSeconds: 45,
    maxInstances: 30,
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const rideId = requiredString(object(request.data).rideId, "Ride");
    const reference = db.collection("rides").doc(rideId);
    const snapshot = await reference.get();
    const ride = snapshot.data();
    if (!ride || ride.driverId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "You cannot start this trip.");
    }
    if (ride.liveTrip && ride.status === "in_progress") {
      return {liveTrip: publicPlan(ride.liveTrip)};
    }
    if (ride.status !== "published") {
      throw new HttpsError("failed-precondition", "This ride cannot be started.");
    }
    const bookings = await tripBookings(rideId);
    const startedAt = Timestamp.now();
    const liveTrip = await buildPlan(ride, bookings, startedAt);
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(reference);
      const data = current.data();
      if (!data || data.driverId !== request.auth?.uid) {
        throw new HttpsError("permission-denied", "You cannot start this trip.");
      }
      if (data.status !== "published" && data.status !== "in_progress") {
        throw new HttpsError("failed-precondition", "This ride cannot be started.");
      }
      if (!data.liveTrip) {
        transaction.update(reference, {
          status: "in_progress",
          startedAt,
          liveTrip,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    const saved = (await reference.get()).data();
    return {liveTrip: publicPlan(saved?.liveTrip ?? liveTrip)};
  },
);

export const getLiveTrip = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const rideId = requiredString(object(request.data).rideId, "Ride");
    const ride = await authorizeTripViewer(rideId, request.auth.uid);
    if (!ride.liveTrip || ride.status !== "in_progress") {
      throw new HttpsError("failed-precondition", "This trip has not started yet.");
    }
    return {liveTrip: publicPlan(ride.liveTrip)};
  },
);

export async function refreshLiveTripAfterPickup(
  rideId: string,
  bookingId: string,
): Promise<Timestamp | null> {
  const reference = db.collection("rides").doc(rideId);
  const snapshot = await reference.get();
  const ride = snapshot.data();
  if (!ride?.liveTrip || ride.status !== "in_progress") return null;
  const liveTrip = object(ride.liveTrip);
  const pickupStops = Array.isArray(liveTrip.pickupStops) ?
    liveTrip.pickupStops.map((item) => object(item)) : [];
  const completedAt = Timestamp.now();
  const updatedPickups = pickupStops.map((item) => item.bookingId === bookingId ?
    {...item, completedAt} : item);
  const allPickedUp = updatedPickups.length > 0 &&
    updatedPickups.every((item) => item.completedAt instanceof Timestamp);
  let updatedPlan: Json = {
    ...liveTrip,
    pickupStops: updatedPickups,
    phase: allPickedUp ? "dropoffs" : "pickups",
    updatedAt: Timestamp.now(),
  };
  if (allPickedUp) {
    const bookings = await tripBookings(rideId);
    const currentPickup = bookings.find((item) => item.id === bookingId)?.pickup ??
      tripLocation(ride.origin, "Ride departure point");
    const destination = tripLocation(ride.destination, "Ride destination");
    const dropoffRoute = await mapsRoute(
      currentPickup,
      destination,
      bookings.map((item) => item.dropoff),
    );
    const arrivals = cumulativeArrivalSeconds(dropoffRoute, bookings.length);
    const startMillis = completedAt.toMillis();
    const ordered = dropoffRoute.orderedIndexes.map((index) => bookings[index]!);
    updatedPlan = {
      ...updatedPlan,
      dropoffStops: ordered.map((booking, index) => stop(
        booking,
        "dropoff",
        index,
        startMillis + (arrivals[index] ?? 0) * 1_000,
      )),
      dropoffPolyline: dropoffRoute.encodedPolyline,
    };
  }
  await reference.update({liveTrip: updatedPlan, updatedAt: FieldValue.serverTimestamp()});
  const dropoffStops = Array.isArray(updatedPlan.dropoffStops) ? updatedPlan.dropoffStops : [];
  const riderDropoff = dropoffStops.map(object).find((item) => item.bookingId === bookingId);
  return riderDropoff?.eta instanceof Timestamp ? riderDropoff.eta : null;
}
