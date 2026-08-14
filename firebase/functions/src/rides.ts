import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {
  getRemoteConfig,
  type RemoteConfigTemplate,
} from "firebase-admin/remote-config";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {
  PricingMode,
  calculateRidePricing,
  luggageRank,
  matchesDriverLanguage,
  normalizeSearchText,
} from "./ride_pricing.js";
import {
  PolygonRing,
  decodeGooglePolyline,
  routePointAllowed,
} from "./ride_routing.js";
import {weeklyDepartures} from "./ride_recurrence.js";
import {compareClosestDepartures} from "./ride_search.js";
import {
  normalizeImmediateDeparture,
  publicSeatInventory,
  rideIntervalsOverlap,
} from "./ride_management.js";
import {preferredDriverPhotoUrl} from "./ride_driver_profile.js";
import {AsyncTtlCache} from "./async_ttl_cache.js";
import {
  compactEncodedPolyline,
  googleStaticMapUrl,
  rideMapPreviewUrl,
} from "./ride_map_preview.js";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const auth = getAuth();
const googleMapsApiKey = defineSecret("GOOGLE_MAPS_API_KEY");
const googleStaticMapsApiKey = defineSecret("GOOGLE_STATIC_MAPS_API_KEY");
const region = "us-central1";
const maxSearchResults = 100;
const remoteTemplateCache = new AsyncTtlCache<RemoteConfigTemplate>(60_000);

type Json = Record<string, unknown>;

interface PlaceDetails {
  placeId: string;
  displayName: string;
  formattedAddress: string;
  latitude: number;
  longitude: number;
  searchText: string;
}

interface RouteDetails {
  distanceMeters: number;
  durationSeconds: number;
  encodedPolyline: string;
}

function object(value: unknown): Json {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request is invalid.");
  }
  return value as Json;
}

function stringValue(value: unknown, field: string, maxLength = 200): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const result = value.trim();
  if (!result || result.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return result;
}

function integer(value: unknown, field: string, minimum: number, maximum: number): number {
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value as number;
}

function choice<T extends string>(
  value: unknown,
  field: string,
  allowed: readonly T[],
): T {
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value as T;
}

function timestamp(value: unknown, field: string): Timestamp {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const millis = Date.parse(value);
  if (!Number.isFinite(millis)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return Timestamp.fromMillis(millis);
}

async function requireVerifiedUser(
  uid: string,
  driver = false,
): Promise<Json> {
  const userReference = db.collection("users").doc(uid);
  const references = [
    userReference,
    userReference.collection("verifications").doc("current"),
    ...(driver ? [userReference.collection("vehicles").doc("primary")] : []),
  ];
  const [userRecord, snapshots] = await Promise.all([
    auth.getUser(uid),
    db.getAll(...references),
  ]);
  const profile = snapshots[0]?.data();
  const verification = snapshots[1]?.data();
  const vehicle = snapshots[2]?.data();
  const emailVerified = userRecord.emailVerified ||
    userRecord.customClaims?.schoolEmailVerified === true;
  if (!emailVerified || profile?.profileComplete !== true ||
      verification?.identityStatus !== "verified") {
    throw new HttpsError(
      "failed-precondition",
      "Complete your profile and identity verification first.",
    );
  }
  if (driver && (verification?.insuranceStatus !== "verified" ||
      vehicle?.complete !== true)) {
    throw new HttpsError(
      "failed-precondition",
      "Complete your driver, vehicle, and insurance verification first.",
    );
  }
  return {...profile, vehicle};
}

async function remoteValue(key: string): Promise<string> {
  try {
    const template = await remoteTemplateCache.get(
      () => getRemoteConfig().getTemplate(),
    );
    const value = template.parameters[key]?.defaultValue;
    if (value && "value" in value && value.value.trim()) return value.value.trim();
  } catch {
    throw new HttpsError(
      "unavailable",
      "Ride configuration is temporarily unavailable. Try again.",
    );
  }
  throw new HttpsError(
    "failed-precondition",
    "Ride configuration is incomplete.",
  );
}

async function remoteNumber(key: string): Promise<number> {
  const parsed = Number(await remoteValue(key));
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Ride configuration is invalid.",
    );
  }
  return parsed;
}

async function remoteString(key: string): Promise<string> {
  return remoteValue(key);
}

async function boundaryExceptionRings(): Promise<PolygonRing[]> {
  let decoded: unknown;
  try {
    decoded = JSON.parse(await remoteValue("pickup_dropoff_boundary_geojson"));
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("failed-precondition", "Ride boundary configuration is invalid.");
  }
  const coordinates = object(decoded).coordinates;
  if (!Array.isArray(coordinates)) {
    throw new HttpsError("failed-precondition", "Ride boundary configuration is invalid.");
  }
  const rings: PolygonRing[] = [];
  for (const ring of coordinates) {
    if (!Array.isArray(ring)) continue;
    const points: Array<readonly [number, number]> = [];
    for (const coordinate of ring) {
      if (!Array.isArray(coordinate) || coordinate.length < 2 ||
          typeof coordinate[0] !== "number" || typeof coordinate[1] !== "number") {
        continue;
      }
      points.push([coordinate[0], coordinate[1]]);
    }
    if (points.length >= 4) rings.push(points);
  }
  if (rings.length === 0) {
    throw new HttpsError("failed-precondition", "Ride boundary configuration is invalid.");
  }
  return rings;
}

async function jsonResponse(url: string, init: RequestInit): Promise<Json> {
  let response: Response;
  try {
    response = await fetch(url, {...init, signal: AbortSignal.timeout(10_000)});
  } catch {
    throw new HttpsError("unavailable", "Maps is temporarily unavailable. Try again.");
  }
  if (!response.ok) {
    throw new HttpsError("unavailable", "Maps could not validate this route. Try again.");
  }
  return object(await response.json());
}

async function placeDetails(placeId: string): Promise<PlaceDetails> {
  const id = stringValue(placeId, "Place", 300);
  const response = await jsonResponse(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(id)}`,
    {
      method: "GET",
      headers: {
        "X-Goog-Api-Key": googleMapsApiKey.value(),
        "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
      },
    },
  );
  const displayName = object(response.displayName).text;
  const location = object(response.location);
  if (typeof displayName !== "string" ||
      typeof response.formattedAddress !== "string" ||
      typeof location.latitude !== "number" ||
      typeof location.longitude !== "number") {
    throw new HttpsError("invalid-argument", "Choose a valid place from the list.");
  }
  const searchText = normalizeSearchText(`${displayName} ${response.formattedAddress}`);
  return {
    placeId: id,
    displayName,
    formattedAddress: response.formattedAddress,
    latitude: location.latitude,
    longitude: location.longitude,
    searchText,
  };
}

async function routeDetails(originPlaceId: string, destinationPlaceId: string): Promise<RouteDetails> {
  const response = await jsonResponse(
    "https://routes.googleapis.com/directions/v2:computeRoutes",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": googleMapsApiKey.value(),
        "X-Goog-FieldMask": "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline",
      },
      body: JSON.stringify({
        origin: {placeId: originPlaceId},
        destination: {placeId: destinationPlaceId},
        travelMode: "DRIVE",
        routingPreference: "TRAFFIC_UNAWARE",
        computeAlternativeRoutes: false,
        languageCode: "en-US",
        units: "IMPERIAL",
      }),
    },
  );
  const routes = response.routes;
  const route = Array.isArray(routes) ? object(routes[0]) : null;
  const polyline = route ? object(route.polyline) : null;
  const distanceMeters = route?.distanceMeters;
  const duration = route?.duration;
  if (typeof distanceMeters !== "number" || distanceMeters <= 0 ||
      typeof duration !== "string" || typeof polyline?.encodedPolyline !== "string") {
    throw new HttpsError("invalid-argument", "No drivable route was found between those places.");
  }
  const durationSeconds = Number.parseInt(duration.replace(/s$/, ""), 10);
  return {
    distanceMeters,
    durationSeconds: Number.isFinite(durationSeconds) ? durationSeconds : 0,
    encodedPolyline: polyline.encodedPolyline,
  };
}

function publicRide(id: string, data: Json, currentDriverPhotoUrl = ""): Json {
  const departureAt = data.departureAt;
  const {seatsTotal, seatsAvailable, bookedSeats} = publicSeatInventory(
    data.status,
    data.seatsTotal,
    data.seatsAvailable,
    data.bookedSeats,
  );
  return {
    id,
    driverId: data.driverId,
    driverName: data.driverName,
    driverInitials: data.driverInitials,
    driverPhotoUrl: preferredDriverPhotoUrl(
      currentDriverPhotoUrl,
      data.driverPhotoUrl,
    ),
    driverGender: data.driverGender,
    driverLanguage: data.driverLanguage ?? "",
    driverRating: data.driverRating ?? 0,
    driverTrips: data.driverTrips ?? 0,
    vehicle: data.vehicle,
    origin: data.origin,
    destination: data.destination,
    departureAt: departureAt instanceof Timestamp ? departureAt.toDate().toISOString() : null,
    distanceMiles: data.distanceMiles,
    durationSeconds: data.durationSeconds,
    seatsTotal,
    seatsAvailable,
    bookedSeats,
    pricePerSeatCents: data.pricePerSeatCents,
    maximumPriceCents: data.maximumPriceCents,
    luggageAllowance: data.luggageAllowance,
    genderRestriction: data.genderRestriction,
    status: data.status,
    shareUrl: data.shareUrl,
    mapPreviewUrl: rideMapPreviewUrl(
      id,
      typeof data.encodedPolyline === "string" ? data.encodedPolyline : "",
    ),
    encodedPolyline: data.encodedPolyline,
    repeatWeekly: data.repeatWeekly === true,
    recurrenceId: data.recurrenceId ?? "",
    verified: true,
  };
}

async function publicRides(
  records: Array<{id: string; data: Json}>,
): Promise<Json[]> {
  const driverIds = [...new Set(records
    .map(({data}) => typeof data.driverId === "string" ? data.driverId : "")
    .filter(Boolean))];
  if (driverIds.length === 0) {
    return records.map(({id, data}) => publicRide(id, data));
  }
  const profileSnapshots = await db.getAll(
    ...driverIds.map((driverId) => db.collection("users").doc(driverId)),
  );
  const photoUrls = new Map<string, string>();
  profileSnapshots.forEach((snapshot) => {
    const photoUrl = snapshot.data()?.photoUrl;
    if (typeof photoUrl === "string" && photoUrl.trim()) {
      photoUrls.set(snapshot.id, photoUrl.trim());
    }
  });
  return records.map(({id, data}) => publicRide(
    id,
    data,
    photoUrls.get(String(data.driverId ?? "")) ?? "",
  ));
}

async function blockedDriverIds(
  viewerUid: string,
  candidateDriverIds: Iterable<string>,
): Promise<Set<string>> {
  const candidates = [...new Set(candidateDriverIds)].filter(
    (uid) => uid && uid !== viewerUid,
  );
  const ownBlocks = await db.collection("users").doc(viewerUid)
    .collection("blockedUsers").get();
  const blocked = new Set(ownBlocks.docs.map((document) => document.id));
  if (candidates.length === 0) return blocked;
  const reciprocal = await db.getAll(
    ...candidates.map((uid) => db.collection("users").doc(uid)
      .collection("blockedUsers").doc(viewerUid)),
  );
  reciprocal.forEach((snapshot, index) => {
    if (snapshot.exists) blocked.add(candidates[index]!);
  });
  return blocked;
}

function initials(profile: Json): string {
  return [profile.firstName, profile.lastName]
    .filter((value): value is string => typeof value === "string" && value.length > 0)
    .map((value) => value[0]?.toUpperCase() ?? "")
    .join("")
    .slice(0, 2);
}

export const searchPlaces = onCall(
  {region, enforceAppCheck: true, secrets: [googleMapsApiKey], maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const query = stringValue(object(request.data).query, "Search", 120);
    if (query.length < 2) return {places: []};
    const response = await jsonResponse(
      "https://places.googleapis.com/v1/places:autocomplete",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": googleMapsApiKey.value(),
          "X-Goog-FieldMask": "suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat",
        },
        body: JSON.stringify({
          input: query,
          includedRegionCodes: ["us"],
          locationBias: {
            circle: {
              center: {latitude: 34.4133, longitude: -119.8610},
              radius: 50000.0,
            },
          },
          languageCode: "en-US",
        }),
      },
    );
    const suggestions = Array.isArray(response.suggestions) ? response.suggestions : [];
    const places = suggestions.flatMap((suggestion) => {
      const prediction = object(object(suggestion).placePrediction);
      const text = object(prediction.text).text;
      const formatting = object(prediction.structuredFormat);
      const mainText = object(formatting.mainText).text;
      const secondaryText = formatting.secondaryText ? object(formatting.secondaryText).text : "";
      if (typeof prediction.placeId !== "string" || typeof text !== "string" ||
          typeof mainText !== "string" || typeof secondaryText !== "string") return [];
      return [{placeId: prediction.placeId, displayName: text, mainText, secondaryText}];
    }).slice(0, 6);
    return {places};
  },
);

export const createRide = onCall(
  {
    region,
    enforceAppCheck: true,
    secrets: [googleMapsApiKey],
    maxInstances: 30,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const profile = await requireVerifiedUser(request.auth.uid, true);
    const data = object(request.data);
    const originPlaceId = stringValue(data.originPlaceId, "Origin", 300);
    const destinationPlaceId = stringValue(data.destinationPlaceId, "Destination", 300);
    if (originPlaceId === destinationPlaceId) {
      throw new HttpsError("invalid-argument", "Choose two different places.");
    }
    let departureAt = timestamp(data.departureAt, "Departure time");
    const now = Date.now();
    const normalizedDeparture = normalizeImmediateDeparture(departureAt.toMillis(), now);
    if (normalizedDeparture === null) {
      throw new HttpsError("invalid-argument", "Choose a departure time that has not passed.");
    }
    departureAt = Timestamp.fromMillis(normalizedDeparture);
    const seats = integer(data.seats, "Seats", 1, 6);
    const requestedPriceCents = integer(data.pricePerSeatCents, "Price", 1, 100_000);
    const luggageAllowance = choice(
      data.luggageAllowance,
      "Luggage allowance",
      ["backpack", "one_suitcase", "two_plus_bags"] as const,
    );
    const genderRestriction = choice(
      data.genderRestriction,
      "Rider restriction",
      ["any", "women_only", "men_only"] as const,
    );
    const repeatWeekly = false;

    const [
      origin,
      destination,
      route,
      mileageRate,
      pricingModeValue,
    ] = await Promise.all([
      placeDetails(originPlaceId),
      placeDetails(destinationPlaceId),
      routeDetails(originPlaceId, destinationPlaceId),
      remoteNumber("irs_mileage_rate"),
      remoteString("pricing_mode"),
    ]);
    const pricingMode: PricingMode = pricingModeValue === "platform_calculated" ?
      "platform_calculated" : "driver_sets_under_cap";
    let pricing;
    try {
      pricing = calculateRidePricing({
        distanceMeters: route.distanceMeters,
        seatsAvailable: seats,
        mileageRate,
        requestedPriceCents,
        mode: pricingMode,
      });
    } catch (error) {
      if ((error as Error).message === "price-over-cap") {
        throw new HttpsError(
          "out-of-range",
          "That price is above the cost-sharing limit for this route.",
        );
      }
      throw new HttpsError("failed-precondition", "A price could not be calculated for this route.");
    }

    const departures = weeklyDepartures(
      departureAt.toDate(),
      1,
    );
    const references = departures.map(() => db.collection("rides").doc());
    const reference = references[0]!;
    const recurrenceId = repeatWeekly ? reference.id : "";
    const shareBase = await remoteString("ride_share_base_url");
    const vehicle = object(profile.vehicle);
    const driverName = `${String(profile.firstName ?? "")} ${String(profile.lastName ?? "")}`.trim();
    const baseRide = {
      driverId: request.auth.uid,
      driverName,
      driverInitials: initials(profile),
      driverPhotoUrl: String(profile.photoUrl ?? "").trim(),
      driverGender: normalizeSearchText(String(profile.gender ?? "")),
      driverLanguage: String(profile.language ?? "").trim(),
      driverRating: Number(profile.driverRating ?? 0),
      driverTrips: Number(profile.driverTrips ?? 0),
      vehicle: {
        makeAndModel: `${String(vehicle.make ?? "")} ${String(vehicle.model ?? "")}`.trim(),
        year: vehicle.year,
        color: vehicle.color,
        photoUrl: vehicle.photoUrl,
      },
      origin,
      destination,
      distanceMeters: route.distanceMeters,
      distanceMiles: pricing.distanceMiles,
      durationSeconds: route.durationSeconds,
      encodedPolyline: route.encodedPolyline,
      seatsTotal: seats,
      seatsAvailable: seats,
      pricePerSeatCents: pricing.pricePerSeatCents,
      maximumPriceCents: pricing.maximumPriceCents,
      mileageRate,
      pricingMode,
      luggageAllowance,
      genderRestriction,
      status: "published",
      immutable: true,
      repeatWeekly,
      recurrenceId,
    };
    const scheduleReference = db.collection("ride_schedules").doc(request.auth.uid);
    await db.runTransaction(async (transaction) => {
      await transaction.get(scheduleReference);
      const existingRides = await transaction.get(
        db.collection("rides")
          .where("driverId", "==", request.auth!.uid)
          .limit(200),
      );
      const overlaps = existingRides.docs.some((document) => {
        const existing = document.data();
        const existingDeparture = existing.departureAt;
        if (existing.status !== "published" ||
            !(existingDeparture instanceof Timestamp)) return false;
        return departures.some((candidate) => rideIntervalsOverlap(
          candidate.getTime(),
          route.durationSeconds,
          existingDeparture.toMillis(),
          Number(existing.durationSeconds ?? 0),
        ));
      });
      if (overlaps) {
        throw new HttpsError(
          "already-exists",
          "This ride overlaps another ride you already posted.",
        );
      }
      departures.forEach((departure, index) => {
        const occurrence = references[index]!;
        const shareUrl = `${shareBase}${shareBase.includes("?") ? "&" : "?"}id=${occurrence.id}`;
        transaction.create(occurrence, {
          ...baseRide,
          departureAt: Timestamp.fromDate(departure),
          recurrenceIndex: index,
          shareUrl,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      transaction.set(scheduleReference, {
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
    const firstRide = {
      ...baseRide,
      departureAt,
      recurrenceIndex: 0,
      shareUrl: `${shareBase}${shareBase.includes("?") ? "&" : "?"}id=${reference.id}`,
    };
    return {
      ride: publicRide(
        reference.id,
        firstRide,
        String(profile.photoUrl ?? "").trim(),
      ),
    };
  },
);

export const updateRide = onCall(
  {region, enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in again.");
    }
    await requireVerifiedUser(request.auth.uid, true);
    const rideId = stringValue(object(request.data).rideId, "Ride", 128);
    const reference = db.collection("rides").doc(rideId);
    const ride = (await reference.get()).data();
    if (!ride || ride.driverId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "You can only edit your own ride.");
    }
    throw new HttpsError(
      "failed-precondition",
      "Published rides cannot be edited. Cancel this ride and post a new one.",
    );
  },
);

export const cancelRide = onCall(
  {region, enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in again.");
    }
    await requireVerifiedUser(request.auth.uid, true);
    const rideId = stringValue(object(request.data).rideId, "Ride", 128);
    const reference = db.collection("rides").doc(rideId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const ride = snapshot.data();
      if (!ride || ride.driverId !== request.auth?.uid) {
        throw new HttpsError("permission-denied", "You can only cancel your own ride.");
      }
      if (ride.status !== "published") return;
      transaction.update(reference, {
        status: "cancelled",
        seatsAvailable: Number(ride.seatsTotal ?? 0),
        bookedSeats: 0,
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return {rideId, status: "cancelled"};
  },
);

export const searchRides = onCall(
  {
    region,
    enforceAppCheck: true,
    secrets: [googleMapsApiKey],
    maxInstances: 60,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const data = object(request.data);
    const startAt = timestamp(data.startAt, "Search date");
    const endAt = timestamp(data.endAt, "Search date");
    if (endAt.toMillis() <= startAt.toMillis() ||
        endAt.toMillis() - startAt.toMillis() > 48 * 60 * 60_000) {
      throw new HttpsError("invalid-argument", "Choose a valid search date.");
    }
    stringValue(data.originQuery, "Origin", 160);
    stringValue(data.destinationQuery, "Destination", 160);
    const pickupPlaceId = stringValue(data.pickupPlaceId, "Pickup area", 300);
    const dropoffPlaceId = stringValue(data.dropoffPlaceId, "Drop-off area", 300);
    const driverGender = choice(data.driverGender ?? "any", "Driver gender", ["any", "women", "men"] as const);
    const driverLanguage = typeof data.driverLanguage === "string" &&
      data.driverLanguage.trim() ?
      stringValue(data.driverLanguage, "Driver language", 80) : "";
    const luggageRequired = choice(
      data.luggageRequired ?? "backpack",
      "Luggage",
      ["backpack", "one_suitcase", "two_plus_bags"] as const,
    );
    const sort = choice(data.sort ?? "soonest", "Sort", ["soonest", "top_rated", "most_seats"] as const);
    const minimumRating = typeof data.minimumRating === "number" ?
      Math.max(0, Math.min(5, data.minimumRating)) : 0;

    const [pickup, dropoff, maximumDetourMiles, boundaryExceptions] =
      await Promise.all([
        placeDetails(pickupPlaceId),
        placeDetails(dropoffPlaceId),
        remoteNumber("max_route_detour_miles"),
        boundaryExceptionRings(),
      ]);

    const snapshot = await db.collection("rides")
      .where("status", "==", "published")
      .where("departureAt", ">=", startAt)
      .where("departureAt", "<", endAt)
      .orderBy("departureAt")
      .limit(maxSearchResults)
      .get();
    const documentMatches = (
      document: (typeof snapshot.docs)[number],
      blocked: Set<string>,
    ): boolean => {
        const ride = document.data();
        const driverId = ride.driverId;
        if (typeof driverId !== "string" || driverId === request.auth?.uid || blocked.has(driverId)) return false;
        if (typeof ride.encodedPolyline !== "string") return false;
        let route;
        try {
          route = decodeGooglePolyline(ride.encodedPolyline);
        } catch {
          return false;
        }
        const pickupMatch = routePointAllowed({
          point: pickup,
          route,
          maximumDetourMiles,
          boundaryExceptions,
        });
        const dropoffMatch = routePointAllowed({
          point: dropoff,
          route,
          maximumDetourMiles,
          boundaryExceptions,
        });
        if (!pickupMatch.allowed || !dropoffMatch.allowed ||
            pickupMatch.progress > dropoffMatch.progress) return false;
        if (driverGender !== "any") {
          const normalizedGender = String(ride.driverGender ?? "");
          if (driverGender === "women" && normalizedGender !== "female" && normalizedGender !== "woman") return false;
          if (driverGender === "men" && normalizedGender !== "male" && normalizedGender !== "man") return false;
        }
        if (!matchesDriverLanguage(ride.driverLanguage, driverLanguage)) return false;
        if (luggageRank(String(ride.luggageAllowance ?? "")) < luggageRank(luggageRequired)) return false;
        if (Number(ride.driverRating ?? 0) < minimumRating) return false;
        return Number(ride.seatsAvailable ?? 0) > 0;
      };
    let candidateDocuments = snapshot.docs;
    let blocked = await blockedDriverIds(
      request.auth.uid,
      candidateDocuments.map((document) =>
        String(document.data().driverId ?? "")),
    );
    let matchingDocuments = candidateDocuments.filter((document) =>
      documentMatches(document, blocked));
    let showingClosest = false;

    if (matchingDocuments.length === 0) {
      showingClosest = true;
      const searchRadius = 30 * 24 * 60 * 60_000;
      const fallbackStart = Timestamp.fromMillis(
        Math.max(Date.now(), startAt.toMillis() - searchRadius),
      );
      const fallbackEnd = Timestamp.fromMillis(endAt.toMillis() + searchRadius);
      const fallbackSnapshot = await db.collection("rides")
        .where("status", "==", "published")
        .where("departureAt", ">=", fallbackStart)
        .where("departureAt", "<", fallbackEnd)
        .orderBy("departureAt")
        .limit(maxSearchResults)
        .get();
      candidateDocuments = fallbackSnapshot.docs;
      blocked = await blockedDriverIds(
        request.auth.uid,
        candidateDocuments.map((document) =>
          String(document.data().driverId ?? "")),
      );
      matchingDocuments = candidateDocuments
        .filter((document) => documentMatches(document, blocked))
        .sort((left, right) => {
          const leftDeparture = (left.data().departureAt as Timestamp).toMillis();
          const rightDeparture = (right.data().departureAt as Timestamp).toMillis();
          return compareClosestDepartures(
            leftDeparture,
            rightDeparture,
            startAt.toMillis(),
            endAt.toMillis(),
          );
        });
    }

    const rides = await publicRides(matchingDocuments.map((document) => ({
      id: document.id,
      data: document.data(),
    })));
    rides.sort((left, right) => {
      if (sort === "top_rated") return Number(right.driverRating) - Number(left.driverRating);
      if (sort === "most_seats") return Number(right.seatsAvailable) - Number(left.seatsAvailable);
      if (showingClosest) {
        return compareClosestDepartures(
          Date.parse(String(left.departureAt)),
          Date.parse(String(right.departureAt)),
          startAt.toMillis(),
          endAt.toMillis(),
        );
      }
      return Date.parse(String(left.departureAt)) - Date.parse(String(right.departureAt));
    });
    return {rides};
  },
);

export const listLeavingSoon = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const snapshot = await db.collection("rides")
      .where("status", "==", "published")
      .where("departureAt", ">=", Timestamp.now())
      .orderBy("departureAt")
      .limit(20)
      .get();
    const blocked = await blockedDriverIds(
      request.auth.uid,
      snapshot.docs.map((document) => String(document.data().driverId ?? "")),
    );
    const rideDocuments = snapshot.docs
      .filter((document) => {
        const driverId = document.data().driverId;
        return typeof driverId === "string" &&
          driverId !== request.auth?.uid &&
          !blocked.has(driverId) &&
          Number(document.data().seatsAvailable ?? 0) > 0;
      })
      .slice(0, 6);
    const rides = await publicRides(rideDocuments.map((document) => ({
      id: document.id,
      data: document.data(),
    })));
    return {rides};
  },
);

export const getRide = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const rideId = stringValue(object(request.data).rideId, "Ride", 128);
    const snapshot = await db.collection("rides").doc(rideId).get();
    const ride = snapshot.data();
    if (!ride) {
      throw new HttpsError("not-found", "That ride is no longer available.");
    }
    let isParticipant = false;
    if (ride.driverId !== request.auth.uid && ride.status !== "published") {
      const participant = await db.collection("bookings")
        .where("rideId", "==", rideId)
        .where("riderId", "==", request.auth.uid)
        .limit(10)
        .get();
      isParticipant = participant.docs.some((document) =>
        ["confirmed", "in_progress", "completed"]
          .includes(String(document.data().status)));
      if (!isParticipant) {
        throw new HttpsError("not-found", "That ride is no longer available.");
      }
    }
    if (ride.driverId !== request.auth.uid) {
      const blocked = await blockedDriverIds(
        request.auth.uid,
        [String(ride.driverId)],
      );
      if (blocked.has(String(ride.driverId))) {
        throw new HttpsError("not-found", "That ride is no longer available.");
      }
    }
    const [publicResult] = await publicRides([{id: snapshot.id, data: ride}]);
    return {ride: publicResult};
  },
);

export const listMyRides = onCall(
  {region, enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid, true);
    const snapshot = await db.collection("rides")
      .where("driverId", "==", request.auth.uid)
      .orderBy("departureAt")
      .limit(100)
      .get();
    return {
      rides: await publicRides(snapshot.docs.map((document) => ({
        id: document.id,
        data: document.data(),
      }))),
    };
  },
);

export const rideMapPreview = onRequest(
  {
    region,
    secrets: [googleStaticMapsApiKey],
    maxInstances: 30,
    timeoutSeconds: 20,
  },
  async (request, response) => {
    if (request.method !== "GET") {
      response.status(405).send("Method not allowed");
      return;
    }
    const rideId = typeof request.query.id === "string" ?
      request.query.id.trim() : "";
    if (!rideId || rideId.length > 128) {
      response.status(404).send("Ride not found");
      return;
    }
    const snapshot = await db.collection("rides").doc(rideId).get();
    const ride = snapshot.data();
    if (!ride || !["published", "in_progress"].includes(String(ride.status))) {
      response.status(404).send("Ride not found");
      return;
    }
    const storedPolyline = typeof ride.encodedPolyline === "string" ?
      ride.encodedPolyline : "";
    const encodedPolyline = compactEncodedPolyline(storedPolyline);
    if (!encodedPolyline) {
      response.status(422).send("Route preview unavailable");
      return;
    }
    const origin = object(ride.origin);
    const destination = object(ride.destination);
    const originLatitude = Number(origin.latitude);
    const originLongitude = Number(origin.longitude);
    const destinationLatitude = Number(destination.latitude);
    const destinationLongitude = Number(destination.longitude);
    if (![originLatitude, originLongitude, destinationLatitude, destinationLongitude]
      .every(Number.isFinite)) {
      response.status(422).send("Route preview unavailable");
      return;
    }

    const mapUrl = googleStaticMapUrl({
      apiKey: googleStaticMapsApiKey.value(),
      encodedPolyline,
      origin: {latitude: originLatitude, longitude: originLongitude},
      destination: {
        latitude: destinationLatitude,
        longitude: destinationLongitude,
      },
    });
    try {
      const mapResponse = await fetch(mapUrl, {
        signal: AbortSignal.timeout(12_000),
      });
      const contentType = mapResponse.headers.get("content-type") ?? "";
      if (!mapResponse.ok || !contentType.startsWith("image/")) {
        const providerMessage = (await mapResponse.text())
          .replaceAll(googleStaticMapsApiKey.value(), "[redacted]")
          .slice(0, 300);
        logger.warn("Ride map provider response was unsuccessful.", {
          rideId,
          status: mapResponse.status,
          contentType,
          providerMessage,
        });
        response.status(502).send("Route preview unavailable");
        return;
      }
      const image = Buffer.from(await mapResponse.arrayBuffer());
      if (image.length === 0 || image.length > 4_000_000) {
        response.status(502).send("Route preview unavailable");
        return;
      }
      response.set("Cache-Control", "public, max-age=86400, s-maxage=604800, stale-while-revalidate=86400");
      response.set("Content-Type", contentType);
      response.status(200).send(image);
    } catch (error) {
      logger.warn("Ride map provider request failed.", {
        rideId,
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      response.status(502).send("Route preview unavailable");
    }
  },
);

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export const rideSharePage = onRequest(
  {region, maxInstances: 60},
  async (request, response) => {
    if (request.method !== "GET") {
      response.status(405).send("Method not allowed");
      return;
    }
    const rideId = typeof request.query.id === "string" ? request.query.id.trim() : "";
    if (!rideId || rideId.length > 128) {
      response.status(404).send("Ride not found");
      return;
    }
    const snapshot = await db.collection("rides").doc(rideId).get();
    const ride = snapshot.data();
    if (!ride || ride.status !== "published") {
      response.status(404).send("Ride not found");
      return;
    }
    const origin = object(ride.origin);
    const destination = object(ride.destination);
    const route = `${String(origin.displayName ?? "Ride")} → ${String(destination.displayName ?? "Destination")}`;
    const departure = (ride.departureAt as Timestamp).toDate();
    const date = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Los_Angeles",
      weekday: "short",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    }).format(departure);
    const price = `$${(Number(ride.pricePerSeatCents) / 100).toFixed(0)}`;
    const summary = `${date} · ${ride.seatsAvailable} seats · ${price} per seat`;
    const deepLink = `sidecar://app/rides/${encodeURIComponent(rideId)}`;
    response.set("Cache-Control", "public, max-age=60");
    response.status(200).type("html").send(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(route)} · SideCar</title>
<meta property="og:title" content="${escapeHtml(route)}"><meta property="og:description" content="${escapeHtml(summary)}">
<meta name="description" content="${escapeHtml(summary)}">
<style>body{margin:0;background:#f4f4f4;color:#111;font-family:Georgia,serif}.card{box-sizing:border-box;max-width:430px;margin:10vh auto;background:#fff;border:1px solid #e1e1e1;border-radius:16px;padding:32px}h1{font-size:28px;margin:0 0 12px}p{color:#707070;line-height:1.5}.button{display:block;margin-top:28px;padding:15px;border-radius:9px;background:#111;color:#fff;text-align:center;text-decoration:none;font-weight:700}</style>
</head><body><main class="card"><p>SideCar ride</p><h1>${escapeHtml(route)}</h1><p>${escapeHtml(summary)}</p><a class="button" href="${escapeHtml(deepLink)}">Open in SideCar</a></main></body></html>`);
  },
);
