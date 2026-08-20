import {createHash} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {notificationCopy} from "./notification_content.js";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const region = "us-central1";

type Json = Record<string, unknown>;

function object(value: unknown): Json {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request is invalid.");
  }
  return value as Json;
}

function text(value: unknown, field: string, maxLength = 4096): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

function tokenId(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function stringData(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Json)
      .filter(([, item]) => item !== null && item !== undefined)
      .map(([key, item]) => [key, typeof item === "string" ? item : JSON.stringify(item)]),
  );
}

export const registerPushToken = onCall(
  {region, enforceAppCheck: true, maxInstances: 80},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const data = object(request.data);
    const token = text(data.token, "Push token");
    const platform = text(data.platform, "Platform", 20);
    if (!new Set(["ios", "android"]).has(platform)) {
      throw new HttpsError("invalid-argument", "That device platform is unsupported.");
    }
    const currentReference = db.collection("users").doc(request.auth.uid)
      .collection("devices").doc(tokenId(token));
    const existingOwners = await db.collectionGroup("devices")
      .where("token", "==", token).limit(20).get();
    const writes = db.batch();
    for (const document of existingOwners.docs) {
      if (document.ref.path !== currentReference.path) writes.delete(document.ref);
    }
    writes.set(currentReference, {
        token,
        platform,
        active: true,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    await writes.commit();
    return {registered: true};
  },
);

export const unregisterPushToken = onCall(
  {region, enforceAppCheck: true, maxInstances: 80},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const token = text(object(request.data).token, "Push token");
    await db.collection("users").doc(request.auth.uid)
      .collection("devices").doc(tokenId(token)).delete();
    return {unregistered: true};
  },
);

export const deliverPushNotification = onDocumentCreated(
  {region, document: "notifications/{notificationId}", maxInstances: 80},
  async (event) => {
    const notification = event.data?.data();
    if (!notification) return;
    const userId = String(notification.userId ?? "");
    const type = String(notification.type ?? "");
    if (!userId || !type) return;
    const devices = await db.collection("users").doc(userId)
      .collection("devices").where("active", "==", true).limit(20).get();
    const tokens = devices.docs.map((document) => String(document.data().token ?? ""))
      .filter(Boolean);
    if (tokens.length === 0) {
      await event.data?.ref.update({pushStatus: "no_devices"});
      return;
    }
    const data = stringData(notification.data);
    const copy = notificationCopy(type, data);
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title: copy.title, body: copy.body},
      data: {...data, type, route: copy.route, notificationId: event.params.notificationId},
      android: {priority: "high", notification: {channelId: "sidecar_activity"}},
      apns: {
        headers: {"apns-priority": "10"},
        payload: {aps: {sound: "default", badge: 1, contentAvailable: true}},
      },
    });
    const invalid = new Set([
      "messaging/registration-token-not-registered",
      "messaging/invalid-registration-token",
    ]);
    await Promise.all(response.responses.map(async (result, index) => {
      if (result.success || !invalid.has(result.error?.code ?? "")) return;
      await db.collection("users").doc(userId)
        .collection("devices").doc(tokenId(tokens[index]!)).set({
          active: false,
          invalidatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
    }));
    await event.data?.ref.update({
      pushStatus: response.failureCount === 0 ? "delivered" : "partial",
      pushSuccessCount: response.successCount,
      pushFailureCount: response.failureCount,
      pushDeliveredAt: FieldValue.serverTimestamp(),
    });
  },
);

async function createReminder(params: {
  key: string;
  userId: string;
  type: string;
  bookingId: string;
  rideId: string;
}): Promise<void> {
  const reference = db.collection("notifications").doc(params.key);
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(reference)).exists) return;
    transaction.create(reference, {
      userId: params.userId,
      type: params.type,
      data: {bookingId: params.bookingId, rideId: params.rideId},
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

export const sendTripReminders = onSchedule(
  {region, schedule: "every 15 minutes", timeZone: "UTC", maxInstances: 1},
  async () => {
    const now = Date.now();
    const snapshot = await db.collection("bookings")
      .where("departureAt", ">=", Timestamp.fromMillis(now))
      .where("departureAt", "<=", Timestamp.fromMillis(now + 25 * 60 * 60 * 1000))
      .limit(500).get();
    const jobs: Array<Promise<void>> = [];
    for (const document of snapshot.docs) {
      const booking = document.data();
      if (!new Set(["confirmed", "in_progress"]).has(String(booking.status))) continue;
      const departureAt = booking.departureAt as Timestamp;
      const minutes = (departureAt.toMillis() - now) / 60_000;
      const riderId = String(booking.riderId ?? "");
      const driverId = String(booking.driverId ?? "");
      const rideId = String(booking.rideId ?? "");
      if (minutes > 23 * 60 && minutes <= 25 * 60) {
        for (const userId of [riderId, driverId].filter(Boolean)) {
          jobs.push(createReminder({
            key: createHash("sha256").update(`trip_reminder:${document.id}:${userId}`).digest("hex"),
            userId,
            type: "trip_reminder",
            bookingId: document.id,
            rideId,
          }));
        }
      }
      if (minutes > 15 && minutes <= 45 && riderId) {
        jobs.push(createReminder({
          key: createHash("sha256").update(`pickup_code_reminder:${document.id}:${riderId}`).digest("hex"),
          userId: riderId,
          type: "pickup_code_reminder",
          bookingId: document.id,
          rideId,
        }));
      }
    }
    await Promise.all(jobs);
    logger.info("Trip reminder scan complete.", {bookings: snapshot.size, notifications: jobs.length});
  },
);
