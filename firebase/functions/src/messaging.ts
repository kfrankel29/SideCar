import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

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

function text(value: unknown, field: string, maxLength = 200): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase()).join("");
}

function tripLabel(booking: Json, ride: Json): string {
  const rideOrigin = ride.origin && typeof ride.origin === "object" ?
    ride.origin as Json : {};
  const rideDestination = ride.destination && typeof ride.destination === "object" ?
    ride.destination as Json : {};
  const origin = String(booking.originName ?? rideOrigin.displayName ?? "").trim();
  const destination = String(
    booking.destinationName ?? rideDestination.displayName ?? "",
  ).trim();
  return origin && destination ? `${origin} → ${destination}` : "SideCar ride";
}

async function ensureConversation(bookingId: string): Promise<string> {
  const bookingSnapshot = await db.collection("bookings").doc(bookingId).get();
  const booking = bookingSnapshot.data();
  if (!booking) throw new HttpsError("not-found", "That booking is unavailable.");
  const riderId = String(booking.riderId ?? "");
  const driverId = String(booking.driverId ?? "");
  const rideId = String(booking.rideId ?? "");
  if (!riderId || !driverId) {
    throw new HttpsError("failed-precondition", "That booking has no participants.");
  }
  const pairKey = [riderId, driverId].sort().join("::");
  const [rider, driver, ride, pairConversation, legacyConversations] = await Promise.all([
    db.collection("users").doc(riderId).get(),
    db.collection("users").doc(driverId).get(),
    rideId ? db.collection("rides").doc(rideId).get() : Promise.resolve(null),
    db.collection("conversations").where("pairKey", "==", pairKey).limit(1).get(),
    db.collection("conversations")
      .where("participantIds", "array-contains", riderId)
      .limit(50)
      .get(),
  ]);
  const riderData = rider.data() ?? {};
  const driverData = driver.data() ?? {};
  const rideData = ride?.data() ?? {};
  const riderName = String(booking.riderName ?? riderData.displayName ?? "Rider");
  const driverName = String(booking.driverName ?? driverData.displayName ?? "Driver");
  const existingReference = pairConversation.docs[0]?.ref ?? legacyConversations.docs
    .filter((document) => {
      const participants = document.data().participantIds;
      return Array.isArray(participants) && participants.map(String).includes(driverId);
    })
    .sort((left, right) => {
      const leftTime = left.data().updatedAt as Timestamp | undefined;
      const rightTime = right.data().updatedAt as Timestamp | undefined;
      return (rightTime?.toMillis() ?? 0) - (leftTime?.toMillis() ?? 0);
    })[0]?.ref;
  const reference = existingReference ?? db.collection("conversations").doc(
    `pair_${[riderId, driverId].sort().join("_")}`,
  );
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const metadata = {
      bookingId,
      rideId,
      pairKey,
      participantIds: [riderId, driverId],
      participantNames: {[riderId]: riderName, [driverId]: driverName},
      participantInitials: {
        [riderId]: initials(riderName),
        [driverId]: initials(driverName),
      },
      participantPhotoUrls: {
        [riderId]: String(riderData.photoUrl ?? booking.riderPhotoUrl ?? ""),
        [driverId]: String(driverData.photoUrl ?? booking.driverPhotoUrl ?? ""),
      },
      tripLabel: tripLabel(booking, rideData),
      departureAt: booking.departureAt ?? rideData.departureAt ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (snapshot.exists) {
      transaction.set(reference, metadata, {merge: true});
      return;
    }
    transaction.create(reference, {
      ...metadata,
      unreadCounts: {[riderId]: 0, [driverId]: 0},
      lastMessage: "",
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return reference.id;
}

async function ensureDirectConversation(
  currentUserId: string,
  otherUserId: string,
): Promise<string> {
  if (currentUserId === otherUserId) {
    throw new HttpsError("invalid-argument", "Choose another SideCar member.");
  }
  if (await usersBlocked(currentUserId, otherUserId)) {
    throw new HttpsError("permission-denied", "Messages are unavailable for this user.");
  }
  const pairKey = [currentUserId, otherUserId].sort().join("::");
  const [currentSnapshot, otherSnapshot, pairConversation, legacyConversations] = await Promise.all([
    db.collection("users").doc(currentUserId).get(),
    db.collection("users").doc(otherUserId).get(),
    db.collection("conversations").where("pairKey", "==", pairKey).limit(1).get(),
    db.collection("conversations")
      .where("participantIds", "array-contains", currentUserId)
      .limit(50)
      .get(),
  ]);
  if (!otherSnapshot.exists) {
    throw new HttpsError("not-found", "That profile is unavailable.");
  }
  const current = currentSnapshot.data() ?? {};
  const other = otherSnapshot.data() ?? {};
  const currentName = String(current.displayName ?? "SideCar member");
  const otherName = String(other.displayName ?? "SideCar member");
  const existingReference = pairConversation.docs[0]?.ref ?? legacyConversations.docs
    .filter((document) => {
      const participants = document.data().participantIds;
      return Array.isArray(participants) && participants.map(String).includes(otherUserId);
    })
    .sort((left, right) => {
      const leftTime = left.data().updatedAt as Timestamp | undefined;
      const rightTime = right.data().updatedAt as Timestamp | undefined;
      return (rightTime?.toMillis() ?? 0) - (leftTime?.toMillis() ?? 0);
    })[0]?.ref;
  const reference = existingReference ?? db.collection("conversations").doc(
    `pair_${[currentUserId, otherUserId].sort().join("_")}`,
  );
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const metadata = {
      pairKey,
      participantIds: [currentUserId, otherUserId],
      participantNames: {
        [currentUserId]: currentName,
        [otherUserId]: otherName,
      },
      participantInitials: {
        [currentUserId]: initials(currentName),
        [otherUserId]: initials(otherName),
      },
      participantPhotoUrls: {
        [currentUserId]: String(current.photoUrl ?? ""),
        [otherUserId]: String(other.photoUrl ?? ""),
      },
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (snapshot.exists) {
      transaction.set(reference, metadata, {merge: true});
      return;
    }
    transaction.create(reference, {
      ...metadata,
      bookingId: "",
      rideId: "",
      tripLabel: "",
      unreadCounts: {[currentUserId]: 0, [otherUserId]: 0},
      lastMessage: "",
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return reference.id;
}

async function conversationForUser(conversationId: string, uid: string) {
  const reference = db.collection("conversations").doc(conversationId);
  const snapshot = await reference.get();
  const conversation = snapshot.data();
  const participants = Array.isArray(conversation?.participantIds) ?
    conversation.participantIds.map(String) : [];
  if (!conversation || !participants.includes(uid)) {
    throw new HttpsError("permission-denied", "You cannot open that conversation.");
  }
  return {reference, conversation, participants};
}

async function usersBlocked(left: string, right: string): Promise<boolean> {
  const [leftBlocked, rightBlocked] = await Promise.all([
    db.collection("users").doc(left).collection("blockedUsers").doc(right).get(),
    db.collection("users").doc(right).collection("blockedUsers").doc(left).get(),
  ]);
  return leftBlocked.exists || rightBlocked.exists;
}

export const createConversationForBooking = onDocumentCreated(
  {region, document: "bookings/{bookingId}", maxInstances: 40},
  async (event) => {
    if (!event.data) return;
    await ensureConversation(event.params.bookingId);
  },
);

export const openBookingConversation = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const bookingId = text(object(request.data).bookingId, "Booking", 128);
    const booking = (await db.collection("bookings").doc(bookingId).get()).data();
    if (!booking || (booking.riderId !== request.auth.uid && booking.driverId !== request.auth.uid)) {
      throw new HttpsError("permission-denied", "You cannot open that conversation.");
    }
    const conversationId = await ensureConversation(bookingId);
    return {conversationId};
  },
);

export const openDirectConversation = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const otherUserId = text(object(request.data).userId, "User", 128);
    const conversationId = await ensureDirectConversation(
      request.auth.uid,
      otherUserId,
    );
    return {conversationId};
  },
);

export const sendRideMessage = onCall(
  {region, enforceAppCheck: true, maxInstances: 80},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const data = object(request.data);
    const conversationId = text(data.conversationId, "Conversation", 128);
    const messageText = text(data.text, "Message", 2_000);
    const {reference, conversation, participants} = await conversationForUser(
      conversationId,
      request.auth.uid,
    );
    const recipientId = participants.find((uid) => uid !== request.auth!.uid) ?? "";
    if (!recipientId || await usersBlocked(request.auth.uid, recipientId)) {
      throw new HttpsError("permission-denied", "Messages are unavailable for this user.");
    }
    const messageReference = reference.collection("messages").doc();
    await db.runTransaction(async (transaction) => {
      const fresh = await transaction.get(reference);
      if (!fresh.exists) throw new HttpsError("not-found", "That conversation is unavailable.");
      transaction.create(messageReference, {
        senderId: request.auth!.uid,
        recipientId,
        text: messageText,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(reference, {
        lastMessage: messageText,
        lastMessageAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        [`unreadCounts.${recipientId}`]: FieldValue.increment(1),
      });
    });
    await db.collection("notifications").add({
      userId: recipientId,
      type: "new_message",
      data: {
        conversationId,
        bookingId: String(conversation.bookingId ?? conversationId),
        senderName: String((conversation.participantNames as Json | undefined)?.[request.auth.uid] ?? "SideCar member"),
        preview: messageText,
      },
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {messageId: messageReference.id, sentAt: Timestamp.now().toMillis()};
  },
);

export const markConversationRead = onCall(
  {region, enforceAppCheck: true, maxInstances: 80},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const conversationId = text(object(request.data).conversationId, "Conversation", 128);
    const {reference, conversation} = await conversationForUser(
      conversationId,
      request.auth.uid,
    );
    const bookingId = String(conversation.bookingId ?? "").trim();
    if (!conversation.departureAt && bookingId) {
      await ensureConversation(bookingId);
    }
    await reference.update({
      [`unreadCounts.${request.auth.uid}`]: 0,
      [`lastReadAt.${request.auth.uid}`]: FieldValue.serverTimestamp(),
    });
    return {read: true};
  },
);
