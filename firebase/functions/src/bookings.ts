import {createHash, createHmac, timingSafeEqual} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getRemoteConfig} from "firebase-admin/remote-config";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import Stripe from "stripe";
import {
  CheckoutPolicy,
  RefundTier,
  calculateCheckoutAmounts,
  refundForRiderCancellation,
  validateRefundTiers,
} from "./booking_policy.js";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const auth = getAuth();
const stripePaymentsSecretKey = defineSecret("STRIPE_PAYMENTS_SECRET_KEY");
const stripePublishableKey = defineSecret("STRIPE_PUBLISHABLE_KEY");
const stripePaymentsWebhookSecret = defineSecret("STRIPE_PAYMENTS_WEBHOOK_SECRET");
const bookingCodeSecret = defineSecret("BOOKING_CODE_SECRET");
const region = "us-central1";

type Json = Record<string, unknown>;
type BookingStatus =
  "pending_driver" | "declined" | "accepted_payment_pending" |
  "payment_processing" | "confirmed" | "expired" | "cancelled" |
  "lost_seat" | "in_progress" | "completed" | "disputed" |
  "payout_held" | "refunded" | "cancellation_processing" |
  "completion_processing";

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
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

function capitalize(value: string): string {
  return value ? `${value.charAt(0).toUpperCase()}${value.slice(1)}` : value;
}

function stripe(): Stripe {
  return new Stripe(stripePaymentsSecretKey.value(), {maxNetworkRetries: 2});
}

async function stripeCustomerId(uid: string): Promise<string> {
  const reference = db.collection("payment_customers").doc(uid);
  const existing = (await reference.get()).data()?.stripeCustomerId;
  if (typeof existing === "string" && existing) return existing;
  const user = await auth.getUser(uid);
  const customer = await stripe().customers.create({
    email: user.email,
    name: user.displayName,
    metadata: {sidecarUid: uid},
  }, {idempotencyKey: `sidecar-customer-${uid}`});
  await reference.set({
    stripeCustomerId: customer.id,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return customer.id;
}

async function customerSession(uid: string): Promise<{
  customerId: string;
  ephemeralKeySecret: string;
}> {
  const customerId = await stripeCustomerId(uid);
  const key = await stripe().ephemeralKeys.create(
    {customer: customerId},
    {apiVersion: "2025-08-27.basil"},
  );
  if (!key.secret) throw new HttpsError("internal", "Payment setup could not be initialized.");
  return {customerId, ephemeralKeySecret: key.secret};
}

async function remoteValue(key: string): Promise<string> {
  try {
    const template = await getRemoteConfig().getTemplate();
    const value = template.parameters[key]?.defaultValue;
    if (value && "value" in value && value.value.trim()) return value.value.trim();
  } catch (error) {
    logger.warn("M4 Remote Config read failed.", {
      key,
      errorName: error instanceof Error ? error.name : "UnknownError",
    });
  }
  throw new HttpsError("failed-precondition", "Payment configuration is incomplete.");
}

async function remoteNumber(key: string): Promise<number> {
  const value = Number(await remoteValue(key));
  if (!Number.isFinite(value) || value < 0) {
    throw new HttpsError("failed-precondition", "Payment configuration is invalid.");
  }
  return value;
}

async function checkoutPolicy(): Promise<CheckoutPolicy> {
  const [type, value, cardRate, cardFixed, bankRate] = await Promise.all([
    remoteValue("service_fee_type"),
    remoteNumber("service_fee_value"),
    remoteNumber("stripe_card_percentage"),
    remoteNumber("stripe_card_fixed_cents"),
    remoteNumber("stripe_bank_percentage"),
  ]);
  if (type !== "percentage" && type !== "fixed") {
    throw new HttpsError("failed-precondition", "Payment configuration is invalid.");
  }
  return {
    serviceFeeType: type,
    serviceFeeValue: value,
    cardRate: cardRate / 100,
    cardFixedCents: Math.round(cardFixed),
    bankRate: bankRate / 100,
  };
}

async function refundTiers(): Promise<RefundTier[]> {
  try {
    const value = JSON.parse(await remoteValue("refund_rules_json")) as unknown;
    if (!Array.isArray(value)) throw new Error("invalid-refund-rules");
    return validateRefundTiers(value.map((entry) => {
      const item = object(entry);
      const minimumHoursExclusive = item.minimumHoursExclusive;
      if (minimumHoursExclusive !== undefined &&
          typeof minimumHoursExclusive !== "boolean") {
        throw new Error("invalid-refund-boundary");
      }
      return {
        minimumHoursBeforeTrip: Number(item.minimumHoursBeforeTrip),
        minimumHoursExclusive,
        riderRefundPercentage: Number(item.riderRefundPercentage),
        platformPercentage: Number(item.platformPercentage),
        driverPercentage: Number(item.driverPercentage),
      };
    }));
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("failed-precondition", "Refund configuration is invalid.");
  }
}

async function requireVerifiedUser(uid: string, driver = false): Promise<Json> {
  const userReference = db.collection("users").doc(uid);
  const references = [
    userReference,
    userReference.collection("verifications").doc("current"),
    ...(driver ? [userReference.collection("vehicles").doc("primary")] : []),
  ];
  const [record, snapshots] = await Promise.all([
    auth.getUser(uid),
    db.getAll(...references),
  ]);
  const profile = snapshots[0]?.data();
  const verification = snapshots[1]?.data();
  const vehicle = snapshots[2]?.data();
  const schoolVerified = record.emailVerified ||
    record.customClaims?.schoolEmailVerified === true;
  if (!schoolVerified || profile?.profileComplete !== true ||
      verification?.identityStatus !== "verified") {
    throw new HttpsError("failed-precondition", "Complete your profile and verification first.");
  }
  if (driver && (verification?.insuranceStatus !== "verified" ||
      vehicle?.complete !== true)) {
    throw new HttpsError("failed-precondition", "Complete driver verification first.");
  }
  return profile ?? {};
}

function bookingId(rideId: string, riderId: string): string {
  return createHash("sha256").update(`${rideId}:${riderId}`).digest("hex");
}

function pickupCode(id: string): string {
  const digest = createHmac("sha256", bookingCodeSecret.value())
    .update(`pickup:${id}`).digest();
  return (digest.readUInt32BE(0) % 10_000).toString().padStart(4, "0");
}

function pickupCodeMatches(id: string, submitted: string): boolean {
  const expected = Buffer.from(pickupCode(id));
  const candidate = Buffer.from(submitted);
  return expected.length === candidate.length && timingSafeEqual(expected, candidate);
}

function timestampIso(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

function bookingJson(id: string, data: Json, viewerId: string): Json {
  const isRider = data.riderId === viewerId;
  const cancellation = data.cancellationSummary && typeof data.cancellationSummary === "object" ?
    data.cancellationSummary as Json : null;
  return {
    id,
    rideId: data.rideId,
    riderId: data.riderId,
    riderName: data.riderName,
    riderInitials: data.riderInitials,
    riderPhotoUrl: data.riderPhotoUrl ?? "",
    driverId: data.driverId,
    driverName: data.driverName,
    status: data.status,
    originName: data.originName,
    destinationName: data.destinationName,
    departureAt: timestampIso(data.departureAt),
    acceptedAt: timestampIso(data.acceptedAt),
    paymentExpiresAt: timestampIso(data.paymentExpiresAt),
    confirmedAt: timestampIso(data.confirmedAt),
    startedAt: timestampIso(data.startedAt),
    completedAt: timestampIso(data.completedAt),
    baseFareCents: data.baseFareCents ?? 0,
    serviceFeeCents: data.serviceFeeCents ?? 0,
    processingFeeCents: data.processingFeeCents ?? 0,
    totalCents: data.totalCents ?? data.baseFareCents ?? 0,
    paymentMethod: data.paymentMethod ?? "card",
    paymentStatus: data.paymentStatus ?? "",
    payoutStatus: data.payoutStatus ?? "",
    driverPayoutCents: data.driverPayoutCents ?? cancellation?.driverCents ??
      (data.status === "completed" ? data.baseFareCents ?? 0 : 0),
    pickupCode: isRider && ["confirmed", "in_progress", "completed"]
      .includes(String(data.status)) ? pickupCode(id) : null,
    cancellationSummary: data.cancellationSummary ?? null,
    disputeReason: data.disputeReason ?? null,
  };
}

async function notify(userId: string, type: string, data: Json): Promise<void> {
  await db.collection("notifications").add({
    userId,
    type,
    data,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export const requestSeat = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const profile = await requireVerifiedUser(request.auth.uid);
    const rideId = stringValue(object(request.data).rideId, "Ride", 128);
    const rideReference = db.collection("rides").doc(rideId);
    const reference = db.collection("bookings").doc(bookingId(rideId, request.auth.uid));
    let driverId = "";
    await db.runTransaction(async (transaction) => {
      const [rideSnapshot, existingSnapshot] = await Promise.all([
        transaction.get(rideReference),
        transaction.get(reference),
      ]);
      const ride = rideSnapshot.data();
      if (!ride || ride.status !== "published" || Number(ride.seatsAvailable ?? 0) < 1) {
        throw new HttpsError("failed-precondition", "That ride is no longer available.");
      }
      if (ride.driverId === request.auth?.uid) {
        throw new HttpsError("failed-precondition", "You cannot request your own ride.");
      }
      const existingStatus = existingSnapshot.data()?.status as BookingStatus | undefined;
      if (existingStatus && !["declined", "expired", "cancelled", "lost_seat"]
        .includes(existingStatus)) {
        throw new HttpsError("already-exists", "You already requested this ride.");
      }
      driverId = String(ride.driverId);
      const firstName = String(profile.firstName ?? "").trim();
      const lastName = String(profile.lastName ?? "").trim();
      const riderName = String(profile.displayName ?? `${firstName} ${lastName}`).trim();
      const initials = `${firstName.at(0) ?? ""}${lastName.at(0) ?? ""}`.toUpperCase();
      transaction.set(reference, {
        rideId,
        riderId: request.auth!.uid,
        riderName,
        riderInitials: initials,
        riderPhotoUrl: String(profile.photoUrl ?? ""),
        driverId,
        driverName: String(ride.driverName ?? ""),
        originName: object(ride.origin).displayName,
        destinationName: object(ride.destination).displayName,
        departureAt: ride.departureAt,
        baseFareCents: Number(ride.pricePerSeatCents),
        status: "pending_driver" satisfies BookingStatus,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await notify(driverId, "seat_request", {rideId, bookingId: reference.id});
    return {booking: bookingJson(reference.id, (await reference.get()).data()!, request.auth.uid)};
  },
);

export const respondSeatRequest = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid, true);
    const data = object(request.data);
    const id = stringValue(data.bookingId, "Request", 128);
    const accept = data.accept === true;
    const reference = db.collection("bookings").doc(id);
    let riderId = "";
    const expirationHours = await remoteNumber("payment_expiration_hours");
    const acceptedPolicy = accept ? await checkoutPolicy() : null;
    if (accept) {
      const payoutAccount = (await db.collection("payment_accounts")
        .doc(request.auth.uid).get()).data();
      if (payoutAccount?.payoutsEnabled !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Finish payout setup before accepting a paid ride request.",
        );
      }
    }
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const booking = snapshot.data();
      if (!booking || booking.driverId !== request.auth?.uid) {
        throw new HttpsError("permission-denied", "You cannot manage this request.");
      }
      if (booking.status !== "pending_driver") {
        throw new HttpsError("failed-precondition", "This request was already handled.");
      }
      riderId = String(booking.riderId);
      const cardAmounts = acceptedPolicy ? calculateCheckoutAmounts(
        Number(booking.baseFareCents),
        acceptedPolicy,
        "card",
      ) : null;
      transaction.update(reference, accept ? {
        ...cardAmounts,
        paymentMethod: "card",
        status: "accepted_payment_pending" satisfies BookingStatus,
        acceptedAt: FieldValue.serverTimestamp(),
        paymentExpiresAt: Timestamp.fromMillis(Date.now() + expirationHours * 3_600_000),
        updatedAt: FieldValue.serverTimestamp(),
      } : {
        status: "declined" satisfies BookingStatus,
        declinedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await notify(riderId, accept ? "seat_request_accepted" : "seat_request_declined", {bookingId: id});
    return {booking: bookingJson(id, (await reference.get()).data()!, request.auth.uid)};
  },
);

export const createBookingPayment = onCall(
  {
    region,
    enforceAppCheck: true,
    secrets: [stripePaymentsSecretKey, stripePublishableKey],
    maxInstances: 60,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const data = object(request.data);
    const id = stringValue(data.bookingId, "Request", 128);
    const paymentMethod = data.paymentMethod === "bank" ? "bank" : "card";
    const reference = db.collection("bookings").doc(id);
    const snapshot = await reference.get();
    const booking = snapshot.data();
    if (!booking || booking.riderId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "You cannot pay for this request.");
    }
    if (booking.status !== "accepted_payment_pending" && booking.status !== "payment_processing") {
      throw new HttpsError("failed-precondition", "This request is not ready for payment.");
    }
    const expiresAt = booking.paymentExpiresAt as Timestamp | undefined;
    if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
      await reference.update({status: "expired", updatedAt: FieldValue.serverTimestamp()});
      throw new HttpsError("deadline-exceeded", "The 24-hour payment window has expired.");
    }
    const amounts = calculateCheckoutAmounts(
      Number(booking.baseFareCents),
      await checkoutPolicy(),
      paymentMethod,
    );
    const customer = await customerSession(request.auth.uid);
    let existingIntentId = typeof booking.paymentIntentId === "string" ?
      booking.paymentIntentId : "";
    let intent: Stripe.PaymentIntent | null = null;
    if (existingIntentId) {
      intent = await stripe().paymentIntents.retrieve(existingIntentId);
      const previousMethod = typeof booking.paymentMethod === "string" ? booking.paymentMethod : "card";
      if (previousMethod !== paymentMethod && !["canceled", "succeeded"].includes(intent.status)) {
        await stripe().paymentIntents.cancel(intent.id);
        existingIntentId = "";
      }
    }
    if (!existingIntentId || intent?.status === "canceled") {
      intent = await stripe().paymentIntents.create({
        amount: amounts.totalCents,
        currency: "usd",
        customer: customer.customerId,
        payment_method_types: [paymentMethod === "bank" ? "us_bank_account" : "card"],
        setup_future_usage: "off_session",
        metadata: {
          bookingId: id,
          rideId: String(booking.rideId),
          riderId: request.auth.uid,
          driverId: String(booking.driverId),
        },
        transfer_group: `ride_${String(booking.rideId)}`,
        description: "SideCar seat booking",
      }, {idempotencyKey: `booking-payment-${id}-${paymentMethod}`});
      await reference.update({
        ...amounts,
        paymentMethod,
        paymentIntentId: intent.id,
        status: "payment_processing" satisfies BookingStatus,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    if (!intent?.client_secret) {
      throw new HttpsError("internal", "Payment could not be initialized.");
    }
    return {
      clientSecret: intent.client_secret,
      publishableKey: stripePublishableKey.value(),
      customerId: customer.customerId,
      ephemeralKeySecret: customer.ephemeralKeySecret,
      allowsDelayedPaymentMethods: paymentMethod === "bank",
      merchantDisplayName: "SideCar",
      amounts,
    };
  },
);

export const quoteBookingPayment = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const data = object(request.data);
    const id = stringValue(data.bookingId, "Request", 128);
    const paymentMethod = data.paymentMethod === "bank" ? "bank" : "card";
    const booking = (await db.collection("bookings").doc(id).get()).data();
    if (!booking || booking.riderId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "You cannot view this payment.");
    }
    if (!["accepted_payment_pending", "payment_processing"].includes(String(booking.status))) {
      throw new HttpsError("failed-precondition", "This request is not ready for payment.");
    }
    const expiresAt = booking.paymentExpiresAt as Timestamp | undefined;
    if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("deadline-exceeded", "The 24-hour payment window has expired.");
    }
    return {
      amounts: calculateCheckoutAmounts(
        Number(booking.baseFareCents),
        await checkoutPolicy(),
        paymentMethod,
      ),
    };
  },
);

export const createPaymentMethodSetup = onCall(
  {
    region,
    enforceAppCheck: true,
    secrets: [stripePaymentsSecretKey, stripePublishableKey],
    maxInstances: 30,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const customer = await customerSession(request.auth.uid);
    const intent = await stripe().setupIntents.create({
      customer: customer.customerId,
      payment_method_types: ["card", "us_bank_account"],
      usage: "off_session",
      metadata: {sidecarUid: request.auth.uid},
    }, {idempotencyKey: `payment-method-setup-${request.auth.uid}-${Date.now()}`});
    if (!intent.client_secret) {
      throw new HttpsError("internal", "Payment setup could not be initialized.");
    }
    return {
      clientSecret: intent.client_secret,
      publishableKey: stripePublishableKey.value(),
      customerId: customer.customerId,
      ephemeralKeySecret: customer.ephemeralKeySecret,
      merchantDisplayName: "SideCar",
    };
  },
);

export const listPaymentMethods = onCall(
  {region, enforceAppCheck: true, secrets: [stripePaymentsSecretKey], maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const customerId = await stripeCustomerId(request.auth.uid);
    const [cards, banks] = await Promise.all([
      stripe().paymentMethods.list({customer: customerId, type: "card", limit: 20}),
      stripe().paymentMethods.list({customer: customerId, type: "us_bank_account", limit: 20}),
    ]);
    return {
      methods: [
        ...cards.data.map((method) => ({
          id: method.id,
          type: "card",
          label: `${capitalize(method.card?.brand ?? "Card")} •${method.card?.last4 ?? ""}`,
          detail: method.card?.exp_month && method.card?.exp_year ?
            `Expires ${String(method.card.exp_month).padStart(2, "0")}/${String(method.card.exp_year).slice(-2)}` : "",
        })),
        ...banks.data.map((method) => ({
          id: method.id,
          type: "bank",
          label: `${method.us_bank_account?.bank_name ?? "Bank account"} •${method.us_bank_account?.last4 ?? ""}`,
          detail: "ACH bank account",
        })),
      ],
    };
  },
);

async function bookingForPaymentIntent(paymentIntentId: string) {
  const snapshot = await db.collection("bookings")
    .where("paymentIntentId", "==", paymentIntentId)
    .limit(1)
    .get();
  return snapshot.docs[0] ?? null;
}

async function confirmPaidBooking(intent: Stripe.PaymentIntent): Promise<void> {
  const document = await bookingForPaymentIntent(intent.id);
  if (!document) {
    logger.error("Payment succeeded without a matching booking.", {paymentIntentId: intent.id});
    return;
  }
  const bookingReference = document.ref;
  let lostSeat = false;
  let riderId = "";
  let driverId = "";
  let rideId = "";
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(bookingReference);
    const booking = current.data();
    if (!booking || [
      "confirmed",
      "in_progress",
      "completed",
      "refunded",
      "lost_seat",
      "cancellation_processing",
      "cancelled",
    ]
      .includes(String(booking.status))) return;
    rideId = String(booking.rideId);
    riderId = String(booking.riderId);
    driverId = String(booking.driverId);
    const rideReference = db.collection("rides").doc(rideId);
    const rideSnapshot = await transaction.get(rideReference);
    const ride = rideSnapshot.data();
    if (!ride || ride.status !== "published" || Number(ride.seatsAvailable ?? 0) < 1) {
      lostSeat = true;
      transaction.update(bookingReference, {
        status: "lost_seat" satisfies BookingStatus,
        paymentStatus: "refund_pending",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    transaction.update(rideReference, {
      seatsAvailable: FieldValue.increment(-1),
      bookedSeats: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(bookingReference, {
      status: "confirmed" satisfies BookingStatus,
      paymentStatus: "paid",
      chargeId: typeof intent.latest_charge === "string" ? intent.latest_charge : "",
      confirmedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  if (lostSeat) {
    await stripe().refunds.create({payment_intent: intent.id}, {
      idempotencyKey: `lost-seat-refund-${document.id}`,
    });
    await bookingReference.update({
      status: "refunded" satisfies BookingStatus,
      paymentStatus: "refunded",
      refundReason: "last_seat_already_booked",
      refundedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notify(riderId, "payment_refunded_seat_unavailable", {
      bookingId: document.id,
      rideId,
    });
    return;
  }
  if (riderId) {
    await Promise.all([
      notify(riderId, "payment_confirmed", {bookingId: document.id, rideId}),
      notify(driverId, "seat_booked", {bookingId: document.id, rideId}),
    ]);
  }
}

async function markPaymentFailed(intent: Stripe.PaymentIntent): Promise<void> {
  const document = await bookingForPaymentIntent(intent.id);
  if (!document) return;
  const data = document.data();
  if (data.status !== "payment_processing") return;
  await document.ref.update({
    status: "accepted_payment_pending" satisfies BookingStatus,
    paymentStatus: "failed",
    paymentFailureMessage: intent.last_payment_error?.message ?? "Payment failed.",
    updatedAt: FieldValue.serverTimestamp(),
  });
  await notify(String(data.riderId), "payment_failed", {bookingId: document.id});
}

export const stripePaymentsWebhook = onRequest(
  {
    region,
    secrets: [stripePaymentsSecretKey, stripePaymentsWebhookSecret],
    maxInstances: 60,
    timeoutSeconds: 60,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method not allowed");
      return;
    }
    const signature = request.header("stripe-signature");
    if (!signature) {
      response.status(400).send("Missing signature");
      return;
    }
    let event: Stripe.Event;
    try {
      event = stripe().webhooks.constructEvent(
        request.rawBody,
        signature,
        stripePaymentsWebhookSecret.value(),
      );
    } catch {
      response.status(400).send("Invalid signature");
      return;
    }
    const eventReference = db.collection("stripe_events").doc(event.id);
    const eventSnapshot = await eventReference.get();
    if (eventSnapshot.exists) {
      response.status(200).json({received: true});
      return;
    }
    try {
      if (event.type === "payment_intent.succeeded") {
        await confirmPaidBooking(event.data.object);
      } else if (event.type === "payment_intent.payment_failed") {
        await markPaymentFailed(event.data.object);
      }
      await eventReference.create({
        type: event.type,
        processedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 3_600_000),
      });
      response.status(200).json({received: true});
    } catch (error) {
      logger.error("Stripe payment webhook processing failed.", {
        eventId: event.id,
        eventType: event.type,
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      response.status(500).send("Webhook processing failed");
    }
  },
);

export const listMyBookings = onCall(
  {region, enforceAppCheck: true, secrets: [bookingCodeSecret], maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid);
    const snapshot = await db.collection("bookings")
      .where("riderId", "==", request.auth.uid)
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();
    return {
      bookings: snapshot.docs.map((document) =>
        bookingJson(document.id, document.data(), request.auth!.uid)),
    };
  },
);

export const listRideRequests = onCall(
  {region, enforceAppCheck: true, maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid, true);
    const data = object(request.data ?? {});
    const rideId = typeof data.rideId === "string" && data.rideId.trim() ?
      stringValue(data.rideId, "Ride", 128) : "";
    let query: FirebaseFirestore.Query = db.collection("bookings")
      .where("driverId", "==", request.auth.uid);
    if (rideId) query = query.where("rideId", "==", rideId);
    const snapshot = await query.limit(200).get();
    const bookings = snapshot.docs
      .map((document) => bookingJson(document.id, document.data(), request.auth!.uid))
      .sort((left, right) => Date.parse(String(left.departureAt)) - Date.parse(String(right.departureAt)));
    return {bookings};
  },
);

export const refreshBooking = onCall(
  {region, enforceAppCheck: true, secrets: [bookingCodeSecret], maxInstances: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const id = stringValue(object(request.data).bookingId, "Request", 128);
    const snapshot = await db.collection("bookings").doc(id).get();
    const booking = snapshot.data();
    if (!booking || (booking.riderId !== request.auth.uid && booking.driverId !== request.auth.uid)) {
      throw new HttpsError("not-found", "That booking is unavailable.");
    }
    return {booking: bookingJson(id, booking, request.auth.uid)};
  },
);

async function connectedAccountId(driverId: string): Promise<string> {
  const snapshot = await db.collection("payment_accounts").doc(driverId).get();
  const accountId = snapshot.data()?.stripeAccountId;
  return typeof accountId === "string" ? accountId : "";
}

async function transferDriverShare(params: {
  bookingId: string;
  rideId: string;
  driverId: string;
  amountCents: number;
  reason: string;
  attempt: number;
}): Promise<string> {
  if (params.amountCents <= 0) return "";
  const accountId = await connectedAccountId(params.driverId);
  if (!accountId) {
    await db.collection("payout_obligations").doc(`${params.reason}_${params.bookingId}`).set({
      ...params,
      status: "account_required",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await db.collection("admin_notifications").add({
      type: "driver_payout_account_required",
      ...params,
      createdAt: FieldValue.serverTimestamp(),
    });
    return "";
  }
  const transfer = await stripe().transfers.create({
    amount: params.amountCents,
    currency: "usd",
    destination: accountId,
    transfer_group: `ride_${params.rideId}`,
    metadata: {
      bookingId: params.bookingId,
      rideId: params.rideId,
      reason: params.reason,
    },
  }, {idempotencyKey: `${params.reason}-transfer-${params.bookingId}-${params.attempt}`});
  return transfer.id;
}

export const cancelSeatBooking = onCall(
  {region, enforceAppCheck: true, secrets: [stripePaymentsSecretKey], maxInstances: 30, timeoutSeconds: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const id = stringValue(object(request.data).bookingId, "Booking", 128);
    const reference = db.collection("bookings").doc(id);
    const snapshot = await reference.get();
    let booking = snapshot.data();
    if (!booking || booking.riderId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "You cannot cancel this booking.");
    }
    const status = String(booking.status) as BookingStatus;
    if (["pending_driver", "accepted_payment_pending", "payment_processing"]
      .includes(status)) {
      if (status === "payment_processing" && typeof booking.paymentIntentId === "string") {
        const intent = await stripe().paymentIntents.retrieve(booking.paymentIntentId);
        if (intent.status === "succeeded") {
          throw new HttpsError("aborted", "Payment completed. Refresh before cancelling.");
        }
        if (!["canceled", "succeeded"].includes(intent.status)) {
          await stripe().paymentIntents.cancel(intent.id);
        }
      }
      await reference.update({
        status: "cancelled" satisfies BookingStatus,
        cancelledBy: "rider",
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await notify(String(booking.driverId), "seat_request_cancelled", {bookingId: id});
      return {status: "cancelled", riderRefundCents: 0};
    }
    if (status !== "confirmed" && status !== "cancellation_processing") {
      throw new HttpsError("failed-precondition", "This booking cannot be cancelled.");
    }
    let allocation = booking.cancellationSummary as ReturnType<
      typeof refundForRiderCancellation
    > | undefined;
    if (status === "confirmed") {
      const departureAt = booking.departureAt as Timestamp;
      allocation = refundForRiderCancellation(
        Number(booking.totalCents),
        departureAt.toMillis(),
        Date.now(),
        await refundTiers(),
      );
      const rideReference = db.collection("rides").doc(String(booking.rideId));
      await db.runTransaction(async (transaction) => {
        const [currentBooking, currentRide] = await Promise.all([
          transaction.get(reference),
          transaction.get(rideReference),
        ]);
        if (currentBooking.data()?.status !== "confirmed") {
          throw new HttpsError("aborted", "This booking changed. Refresh and try again.");
        }
        transaction.update(reference, {
          status: "cancellation_processing" satisfies BookingStatus,
          cancelledBy: "rider",
          cancellationSummary: allocation,
          cancellationStartedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (currentRide.exists) {
          transaction.update(rideReference, {
            seatsAvailable: FieldValue.increment(1),
            bookedSeats: FieldValue.increment(-1),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      });
      booking = (await reference.get()).data();
    }
    if (!booking || !allocation) {
      throw new HttpsError("internal", "Cancellation could not be completed.");
    }
    const totalCents = Number(booking.totalCents);
    if (allocation.riderRefundCents > 0) {
      await stripe().refunds.create({
        payment_intent: String(booking.paymentIntentId),
        amount: allocation.riderRefundCents,
      }, {idempotencyKey: `rider-cancel-refund-${id}`});
    }
    const transferId = await transferDriverShare({
      bookingId: id,
      rideId: String(booking.rideId),
      driverId: String(booking.driverId),
      amountCents: allocation.driverCents,
      reason: "rider_cancellation",
      attempt: 1,
    });
    await Promise.all([
      reference.update({
        status: "cancelled" satisfies BookingStatus,
        paymentStatus: allocation.riderRefundCents === totalCents ? "refunded" : "partially_refunded",
        cancellationTransferId: transferId,
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }),
      notify(String(booking.driverId), "confirmed_booking_cancelled", {bookingId: id}),
    ]);
    return {status: "cancelled", ...allocation};
  },
);

export const cancelDriverRide = onCall(
  {region, enforceAppCheck: true, secrets: [stripePaymentsSecretKey], maxInstances: 20, timeoutSeconds: 120},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid, true);
    const rideId = stringValue(object(request.data).rideId, "Ride", 128);
    const rideReference = db.collection("rides").doc(rideId);
    const rideSnapshot = await rideReference.get();
    const ride = rideSnapshot.data();
    if (!ride || ride.driverId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "You can only cancel your own ride.");
    }
    const bookingSnapshot = await db.collection("bookings")
      .where("rideId", "==", rideId).get();
    const refundable = bookingSnapshot.docs.filter((document) => {
      const booking = document.data();
      const canResume = booking.status === "cancellation_processing" &&
        booking.cancelledBy === "driver";
      return (["confirmed", "payment_processing"].includes(String(booking.status)) || canResume) &&
        typeof booking.paymentIntentId === "string";
    });
    const batch = db.batch();
    bookingSnapshot.docs.forEach((document) => {
      const status = String(document.data().status);
      if (["confirmed", "payment_processing"].includes(status)) {
        batch.update(document.ref, {
          status: "cancellation_processing" satisfies BookingStatus,
          cancelledBy: "driver",
          cancellationStartedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else if (["pending_driver", "accepted_payment_pending"].includes(status)) {
        batch.update(document.ref, {
          status: "cancelled" satisfies BookingStatus,
          cancelledBy: "driver",
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    batch.update(rideReference, {
      status: "cancelled",
      seatsAvailable: Number(ride.seatsTotal ?? 0),
      bookedSeats: 0,
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    for (const document of refundable) {
      const booking = document.data();
      const intent = await stripe().paymentIntents.retrieve(String(booking.paymentIntentId));
      if (intent.status === "succeeded") {
        await stripe().refunds.create({
          payment_intent: intent.id,
        }, {idempotencyKey: `driver-cancel-refund-${document.id}`});
      } else if (intent.status !== "canceled") {
        await stripe().paymentIntents.cancel(intent.id);
      }
      await document.ref.update({
        status: intent.status === "succeeded" ?
          "refunded" satisfies BookingStatus : "cancelled" satisfies BookingStatus,
        paymentStatus: intent.status === "succeeded" ? "refunded" : "cancelled",
        cancelledBy: "driver",
        refundReason: "driver_cancelled",
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await notify(String(booking.riderId), "ride_cancelled_full_refund", {
        bookingId: document.id,
        rideId,
      });
    }
    return {rideId, status: "cancelled", refundsIssued: refundable.length};
  },
);

export const verifyPickupCode = onCall(
  {region, enforceAppCheck: true, secrets: [bookingCodeSecret], maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid, true);
    const data = object(request.data);
    const id = stringValue(data.bookingId, "Booking", 128);
    const code = stringValue(data.code, "Pickup code", 4);
    if (!/^\d{4}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Enter the rider's 4-digit pickup code.");
    }
    const reference = db.collection("bookings").doc(id);
    const snapshot = await reference.get();
    const booking = snapshot.data();
    if (!booking || booking.driverId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "You cannot start this booking.");
    }
    if (booking.status !== "confirmed") {
      throw new HttpsError("failed-precondition", "This booking is not ready to start.");
    }
    if (!pickupCodeMatches(id, code)) {
      throw new HttpsError("invalid-argument", "That pickup code does not match.");
    }
    const ride = (await db.collection("rides").doc(String(booking.rideId)).get()).data();
    const durationSeconds = Math.max(60, Number(ride?.durationSeconds ?? 0));
    const estimatedEnd = Timestamp.fromMillis(
      Date.now() + durationSeconds * 1_000,
    );
    await reference.update({
      status: "in_progress" satisfies BookingStatus,
      pickupCodeVerifiedAt: FieldValue.serverTimestamp(),
      startedAt: FieldValue.serverTimestamp(),
      estimatedCompletionAt: estimatedEnd,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notify(String(booking.riderId), "trip_started", {bookingId: id});
    return {status: "in_progress", estimatedCompletionAt: estimatedEnd.toDate().toISOString()};
  },
);

async function completeAndPayBooking(
  reference: FirebaseFirestore.DocumentReference,
): Promise<boolean> {
  let booking: Json | undefined;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const current = snapshot.data();
    if (!current) return;
    if (current.status === "completion_processing") {
      booking = current;
      return;
    }
    if (current.status !== "in_progress") return;
    const completionAt = current.estimatedCompletionAt as Timestamp | undefined;
    if (!completionAt || completionAt.toMillis() > Date.now()) return;
    const payoutAttempt = Math.max(0, Number(current.payoutAttempt ?? 0)) + 1;
    booking = {...current, payoutAttempt};
    transaction.update(reference, {
      status: "completion_processing" satisfies BookingStatus,
      payoutStatus: "processing",
      payoutAttempt,
      completionStartedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  if (!booking) return false;
  try {
    const transferId = await transferDriverShare({
      bookingId: reference.id,
      rideId: String(booking.rideId),
      driverId: String(booking.driverId),
      amountCents: Number(booking.driverPayoutCents ?? booking.baseFareCents),
      reason: "trip_completion",
      attempt: Number(booking.payoutAttempt ?? 1),
    });
    await reference.update({
      status: "completed" satisfies BookingStatus,
      payoutStatus: transferId ? "paid" : "account_required",
      payoutTransferId: transferId,
      completedAt: FieldValue.serverTimestamp(),
      paidOutAt: transferId ? FieldValue.serverTimestamp() : null,
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    await reference.update({
      status: "payout_held" satisfies BookingStatus,
      payoutStatus: "failed",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.collection("admin_notifications").add({
      type: "payout_failed",
      bookingId: reference.id,
      errorName: error instanceof Error ? error.name : "UnknownError",
      createdAt: FieldValue.serverTimestamp(),
    });
    return false;
  }
  await Promise.all([
    notify(String(booking.riderId), "trip_completed", {bookingId: reference.id}),
    notify(String(booking.driverId), "payout_released", {bookingId: reference.id}),
  ]);
  return true;
}

export const completeTrip = onCall(
  {region, enforceAppCheck: true, secrets: [stripePaymentsSecretKey], maxInstances: 30, timeoutSeconds: 60},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const id = stringValue(object(request.data).bookingId, "Booking", 128);
    const reference = db.collection("bookings").doc(id);
    const booking = (await reference.get()).data();
    if (!booking || (booking.driverId !== request.auth.uid && booking.riderId !== request.auth.uid)) {
      throw new HttpsError("permission-denied", "You cannot complete this booking.");
    }
    if (!await completeAndPayBooking(reference)) {
      throw new HttpsError("failed-precondition", "The trip cannot be completed yet.");
    }
    return {status: "completed"};
  },
);

export const disputeBooking = onCall(
  {region, enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const data = object(request.data);
    const id = stringValue(data.bookingId, "Booking", 128);
    const reason = stringValue(data.reason, "Reason", 1_000);
    const reference = db.collection("bookings").doc(id);
    const snapshot = await reference.get();
    const booking = snapshot.data();
    if (!booking || (booking.riderId !== request.auth.uid && booking.driverId !== request.auth.uid)) {
      throw new HttpsError("permission-denied", "You cannot dispute this booking.");
    }
    if (!["confirmed", "in_progress", "completed", "payout_held"]
      .includes(String(booking.status))) {
      throw new HttpsError("failed-precondition", "This booking cannot be disputed.");
    }
    if (booking.payoutStatus === "paid") {
      throw new HttpsError("failed-precondition", "Contact support about this completed payout.");
    }
    await reference.update({
      status: "disputed" satisfies BookingStatus,
      disputeReason: reason,
      disputedBy: request.auth.uid,
      disputedAt: FieldValue.serverTimestamp(),
      payoutStatus: "held",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.collection("admin_notifications").add({
      type: "booking_disputed",
      bookingId: id,
      rideId: booking.rideId,
      reason,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {status: "disputed"};
  },
);

export const createDriverConnectAccount = onCall(
  {region, enforceAppCheck: true, secrets: [stripePaymentsSecretKey], maxInstances: 20, timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const profile = await requireVerifiedUser(request.auth.uid, true);
    const reference = db.collection("payment_accounts").doc(request.auth.uid);
    const existing = (await reference.get()).data();
    let accountId = typeof existing?.stripeAccountId === "string" ? existing.stripeAccountId : "";
    if (!accountId) {
      const record = await auth.getUser(request.auth.uid);
      const account = await stripe().accounts.create({
        type: "express",
        country: "US",
        email: record.email,
        business_type: "individual",
        business_profile: {
          product_description: "Peer-to-peer university ridesharing",
        },
        metadata: {sidecarUid: request.auth.uid},
      }, {idempotencyKey: `connect-account-${request.auth.uid}`});
      accountId = account.id;
      await reference.set({
        stripeAccountId: accountId,
        displayName: profile.displayName ?? "",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    const returnUrl = await remoteValue("stripe_connect_return_url");
    const refreshUrl = await remoteValue("stripe_connect_refresh_url");
    const link = await stripe().accountLinks.create({
      account: accountId,
      return_url: returnUrl,
      refresh_url: refreshUrl,
      type: "account_onboarding",
    });
    return {url: link.url};
  },
);

export const getDriverPayoutStatus = onCall(
  {region, enforceAppCheck: true, secrets: [stripePaymentsSecretKey], maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    await requireVerifiedUser(request.auth.uid, true);
    const accountId = await connectedAccountId(request.auth.uid);
    if (!accountId) {
      return {
        connected: false,
        payoutsEnabled: false,
        detailsSubmitted: false,
        bankName: "",
        last4: "",
        availableCents: 0,
        pendingCents: 0,
      };
    }
    const [account, balance, externalAccounts] = await Promise.all([
      stripe().accounts.retrieve(accountId),
      stripe().balance.retrieve({stripeAccount: accountId}),
      stripe().accounts.listExternalAccounts(accountId, {object: "bank_account", limit: 1}),
    ]);
    const bank = externalAccounts.data[0];
    const usd = (entries: Stripe.Balance.Available[]) => entries
      .filter((entry) => entry.currency === "usd")
      .reduce((sum, entry) => sum + entry.amount, 0);
    await db.collection("payment_accounts").doc(request.auth.uid).set({
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
      detailsSubmitted: account.details_submitted,
      bankName: bank && bank.object === "bank_account" ? bank.bank_name : "",
      last4: bank && bank.object === "bank_account" ? bank.last4 : "",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {
      connected: true,
      payoutsEnabled: account.payouts_enabled,
      detailsSubmitted: account.details_submitted,
      bankName: bank && bank.object === "bank_account" ? bank.bank_name : "",
      last4: bank && bank.object === "bank_account" ? bank.last4 : "",
      availableCents: usd(balance.available),
      pendingCents: usd(balance.pending),
    };
  },
);

export const expireUnpaidBookings = onSchedule(
  {
    region,
    schedule: "every 15 minutes",
    timeZone: "UTC",
    secrets: [stripePaymentsSecretKey],
  },
  async () => {
    const snapshot = await db.collection("bookings")
      .where("status", "in", ["accepted_payment_pending", "payment_processing"])
      .where("paymentExpiresAt", "<=", Timestamp.now())
      .limit(250)
      .get();
    for (const document of snapshot.docs) {
      const booking = document.data();
      if (booking.status === "payment_processing" && typeof booking.paymentIntentId === "string") {
        try {
          const intent = await stripe().paymentIntents.retrieve(booking.paymentIntentId);
          if (intent.status === "succeeded") continue;
          if (intent.status !== "canceled") await stripe().paymentIntents.cancel(intent.id);
        } catch (error) {
          logger.warn("Could not cancel expired PaymentIntent.", {
            bookingId: document.id,
            errorName: error instanceof Error ? error.name : "UnknownError",
          });
        }
      }
      await document.ref.update({
        status: "expired" satisfies BookingStatus,
        expiredAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await Promise.all([
        notify(String(booking.riderId), "payment_window_expired", {bookingId: document.id}),
        notify(String(booking.driverId), "seat_request_expired", {bookingId: document.id}),
      ]);
    }
  },
);

export const settleTrips = onSchedule(
  {
    region,
    schedule: "every 15 minutes",
    timeZone: "UTC",
    secrets: [stripePaymentsSecretKey],
    timeoutSeconds: 300,
  },
  async () => {
    const ready = await db.collection("bookings")
      .where("status", "==", "in_progress")
      .where("estimatedCompletionAt", "<=", Timestamp.now())
      .limit(250)
      .get();
    for (const document of ready.docs) await completeAndPayBooking(document.ref);

    const autoCompleteHours = await remoteNumber("trip_auto_complete_hours");
    const missingCodeCutoff = Timestamp.fromMillis(Date.now() - autoCompleteHours * 3_600_000);
    const missingCode = await db.collection("bookings")
      .where("status", "==", "confirmed")
      .where("departureAt", "<=", missingCodeCutoff)
      .limit(250)
      .get();
    for (const document of missingCode.docs) {
      await document.ref.update({
        status: "payout_held" satisfies BookingStatus,
        payoutStatus: "held_missing_pickup_code",
        updatedAt: FieldValue.serverTimestamp(),
      });
      await db.collection("admin_notifications").add({
        type: "pickup_code_missing_payout_held",
        bookingId: document.id,
        rideId: document.data().rideId,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  },
);
