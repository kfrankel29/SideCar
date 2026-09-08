import {createHash} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  isRideUpdateNotification,
  notificationCopy,
} from "./notification_content.js";
import {dueTripReminderMinutes} from "./reminder_schedule.js";

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

async function requireActiveUser(uid: string): Promise<void> {
  const profile = (await db.collection("users").doc(uid).get()).data();
  if (profile?.accountStatus === "suspended" || profile?.accountStatus === "banned") {
    throw new HttpsError("permission-denied", "This account is not active.");
  }
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
    await requireActiveUser(request.auth.uid);
    const data = object(request.data);
    const token = text(data.token, "Push token");
    const platform = text(data.platform, "Platform", 20);
    if (!new Set(["ios", "android"]).has(platform)) {
      throw new HttpsError("invalid-argument", "That device platform is unsupported.");
    }
    const currentReference = db.collection("users").doc(request.auth.uid)
      .collection("devices").doc(tokenId(token));
    const writes = db.batch();
    try {
      const existingOwners = await db.collectionGroup("devices")
        .where("token", "==", token).limit(20).get();
      for (const document of existingOwners.docs) {
        if (document.ref.path !== currentReference.path) writes.delete(document.ref);
      }
    } catch (error) {
      if ((error as {code?: number}).code !== 9) throw error;
      logger.warn("Device-token owner cleanup is waiting for its Firestore index.", {
        userId: request.auth.uid,
        platform,
      });
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
    await requireActiveUser(request.auth.uid);
    const token = text(object(request.data).token, "Push token");
    await db.collection("users").doc(request.auth.uid)
      .collection("devices").doc(tokenId(token)).delete();
    return {unregistered: true};
  },
);

export const getRideNotificationState = onCall(
  {region, enforceAppCheck: true, maxInstances: 80},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireActiveUser(request.auth.uid);
    const snapshot = await db.collection("notifications")
      .where("userId", "==", request.auth.uid)
      .where("read", "==", false)
      .limit(100)
      .get();
    const unreadCount = snapshot.docs.filter((document) =>
      isRideUpdateNotification(String(document.data().type ?? "")),
    ).length;
    return {unreadCount};
  },
);

export const markRideNotificationsRead = onCall(
  {region, enforceAppCheck: true, maxInstances: 80},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireActiveUser(request.auth.uid);
    const snapshot = await db.collection("notifications")
      .where("userId", "==", request.auth.uid)
      .where("read", "==", false)
      .limit(500)
      .get();
    const unreadRideUpdates = snapshot.docs.filter((document) =>
      isRideUpdateNotification(String(document.data().type ?? "")),
    );
    if (unreadRideUpdates.length > 0) {
      const batch = db.batch();
      for (const document of unreadRideUpdates) {
        batch.update(document.ref, {
          read: true,
          readAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    return {markedRead: unreadRideUpdates.length};
  },
);

export const deliverPushNotification = onDocumentCreated(
  {
    region,
    document: "notifications/{notificationId}",
    maxInstances: 80,
    retry: true,
  },
  async (event) => {
    const notificationSnapshot = event.data;
    const notification = notificationSnapshot?.data();
    if (!notificationSnapshot || !notification) return;
    const currentStatus = String(
      (await notificationSnapshot.ref.get()).data()?.pushStatus ?? "",
    );
    if (["delivered", "partial", "no_devices"].includes(currentStatus)) return;
    const userId = String(notification.userId ?? "");
    const type = String(notification.type ?? "");
    if (!userId || !type) return;
    const devices = await db.collection("users").doc(userId)
      .collection("devices").where("active", "==", true).limit(20).get();
    const tokens = devices.docs.map((document) => String(document.data().token ?? ""))
      .filter(Boolean);
    if (tokens.length === 0) {
      await notificationSnapshot.ref.update({pushStatus: "no_devices"});
      logger.warn("Push notification has no active recipient devices.", {
        notificationId: event.params.notificationId,
        userId,
        type,
      });
      return;
    }
    const data = stringData(notification.data);
    const copy = notificationCopy(type, data);
    await notificationSnapshot.ref.update({
      pushStatus: "sending",
      pushAttemptCount: FieldValue.increment(1),
      pushLastAttemptAt: FieldValue.serverTimestamp(),
    });
    let response;
    try {
      response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {title: copy.title, body: copy.body},
        data: {...data, type, route: copy.route, notificationId: event.params.notificationId},
        android: {
          collapseKey: event.params.notificationId,
          priority: "high",
          notification: {channelId: "sidecar_activity"},
        },
        apns: {
          headers: {
            "apns-collapse-id": event.params.notificationId,
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {aps: {sound: "default", badge: 1, contentAvailable: true}},
        },
      });
    } catch (error) {
      await notificationSnapshot.ref.update({
        pushStatus: "failed",
        pushFailureReason: error instanceof Error ? error.message.slice(0, 500) : "Unknown push error",
        pushFailedAt: FieldValue.serverTimestamp(),
      });
      logger.error("Push delivery failed before FCM accepted the message.", {
        notificationId: event.params.notificationId,
        userId,
        type,
        error,
      });
      throw error;
    }
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
    const failureCodes = [...new Set(response.responses
      .flatMap((result) => result.error?.code ? [result.error.code] : []))];
    await notificationSnapshot.ref.update({
      pushStatus: response.successCount === 0 ? "failed" :
        response.failureCount === 0 ? "delivered" : "partial",
      pushSuccessCount: response.successCount,
      pushFailureCount: response.failureCount,
      pushFailureCodes: failureCodes,
      pushDeliveredAt: FieldValue.serverTimestamp(),
    });
    logger.info("Push delivery completed.", {
      notificationId: event.params.notificationId,
      userId,
      type,
      successCount: response.successCount,
      failureCount: response.failureCount,
      failureCodes,
    });
  },
);

async function createReminder(params: {
  key: string;
  userId: string;
  type: string;
  bookingId: string;
  rideId: string;
  reminderMinutes?: number;
}): Promise<void> {
  const reference = db.collection("notifications").doc(params.key);
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(reference)).exists) return;
    transaction.create(reference, {
      userId: params.userId,
      type: params.type,
      data: {
        bookingId: params.bookingId,
        rideId: params.rideId,
        ...(params.reminderMinutes ? {reminderMinutes: params.reminderMinutes} : {}),
      },
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

export const sendTripReminders = onSchedule(
  {region, schedule: "every 5 minutes", timeZone: "UTC", maxInstances: 1},
  async () => {
    const now = Date.now();
    const snapshot = await db.collection("bookings")
      .where("departureAt", ">=", Timestamp.fromMillis(now))
      .where("departureAt", "<=", Timestamp.fromMillis(now + 25 * 60 * 60 * 1000))
      .limit(500).get();
    const jobs: Array<Promise<void>> = [];
    for (const document of snapshot.docs) {
      const booking = document.data();
      if (String(booking.status) !== "confirmed") continue;
      const departureAt = booking.departureAt as Timestamp;
      const minutes = (departureAt.toMillis() - now) / 60_000;
      const riderId = String(booking.riderId ?? "");
      const driverId = String(booking.driverId ?? "");
      const rideId = String(booking.rideId ?? "");
      for (const reminderMinutes of dueTripReminderMinutes(minutes)) {
        for (const userId of [riderId, driverId].filter(Boolean)) {
          jobs.push(createReminder({
            key: createHash("sha256")
              .update(`trip_reminder:${reminderMinutes}:${document.id}:${userId}`)
              .digest("hex"),
            userId,
            type: "trip_reminder",
            bookingId: document.id,
            rideId,
            reminderMinutes,
          }));
        }
      }
    }
    await Promise.all(jobs);
    logger.info("Trip reminder scan complete.", {bookings: snapshot.size, notifications: jobs.length});
  },
);
