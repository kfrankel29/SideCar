import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  FieldPath,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getRemoteConfig} from "firebase-admin/remote-config";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";

import {
  AdminBusinessConfig,
  hasAdminClaim,
  parseAccountStatus,
  parseAdminBusinessConfig,
  parseInsuranceDecision,
} from "./admin_policy.js";
import {
  adminAccountRecord,
  manualVerificationEmail,
  parseAdminProfileUpdate,
} from "./admin_accounts.js";
import {hasOpenAccountObligations} from "./account_security.js";
import {AdminRideRider, adminRideRecord} from "./admin_rides.js";
import {
  AdminBookingView,
  adminBookingRecord,
  bookingMatchesAdminView,
} from "./admin_payments.js";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const auth = getAuth();
const remoteConfig = getRemoteConfig();
const region = "us-central1";
const pageSize = 100;

type Json = Record<string, unknown>;
type RecordKind = "rides" | "bookings" | "payments" | "refunds" |
  "disputes" | "audit";

function object(value: unknown): Json {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request is invalid.");
  }
  return value as Json;
}

function optionalText(value: unknown, field: string, maxLength = 1_000): string {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string" || value.trim().length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value.trim();
}

function requiredText(value: unknown, field: string, maxLength = 1_000): string {
  const result = optionalText(value, field, maxLength);
  if (!result) throw new HttpsError("invalid-argument", `${field} is required.`);
  return result;
}

function requireAdmin(request: {auth?: {uid: string; token: unknown}}): {
  uid: string;
  email: string;
} {
  if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in.");
  const token = request.auth.token as Json;
  if (!hasAdminClaim(token)) {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
  return {
    uid: request.auth.uid,
    email: typeof token.email === "string" ? token.email : "",
  };
}

function timestampIso(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

function recordKind(value: unknown): RecordKind {
  if (value === "rides" || value === "bookings" || value === "payments" ||
      value === "refunds" || value === "disputes" || value === "audit") {
    return value;
  }
  throw new HttpsError("invalid-argument", "Choose a valid admin record type.");
}

function recordCollection(kind: RecordKind): string {
  return kind === "audit" ? "admin_audit_logs" :
    kind === "rides" ? "rides" : "bookings";
}

function adminRecord(id: string, kind: RecordKind, data: Json): Json {
  if (kind === "rides") return adminRideRecord(id, data);
  if (kind === "audit") {
    return {
      id,
      action: data.action ?? "",
      adminUid: data.adminUid ?? "",
      adminEmail: data.adminEmail ?? "",
      targetType: data.targetType ?? "",
      targetId: data.targetId ?? "",
      summary: data.summary ?? "",
      createdAt: timestampIso(data.createdAt),
    };
  }
  return adminBookingRecord(id, data);
}

async function ridersByRide(
  rideIds: ReadonlyArray<string>,
): Promise<Map<string, AdminRideRider[]>> {
  const result = new Map<string, AdminRideRider[]>();
  for (let index = 0; index < rideIds.length; index += 30) {
    const ids = rideIds.slice(index, index + 30);
    if (ids.length === 0) continue;
    const snapshot = await db.collection("bookings")
      .where("rideId", "in", ids)
      .get();
    for (const document of snapshot.docs) {
      const data = document.data();
      const rideId = typeof data.rideId === "string" ? data.rideId : "";
      if (!rideId) continue;
      const riders = result.get(rideId) ?? [];
      riders.push({
        id: typeof data.riderId === "string" ? data.riderId : "",
        name: typeof data.riderName === "string" ? data.riderName : "",
        status: typeof data.status === "string" ? data.status : "",
        seat: typeof data.seat === "string" ? data.seat : "",
      });
      result.set(rideId, riders);
    }
  }
  for (const riders of result.values()) {
    riders.sort((left, right) =>
      (left.name || left.id).localeCompare(right.name || right.id),
    );
  }
  return result;
}

function templateValue(template: Awaited<ReturnType<typeof remoteConfig.getTemplate>>, key: string): string {
  const value = template.parameters[key]?.defaultValue;
  return value && "value" in value ? value.value : "";
}

function configFromTemplate(
  template: Awaited<ReturnType<typeof remoteConfig.getTemplate>>,
): AdminBusinessConfig & {version: string; templateVersion: string} {
  const refundRules = JSON.parse(templateValue(template, "refund_rules_json")) as unknown;
  const config = parseAdminBusinessConfig({
    serviceFeeType: templateValue(template, "service_fee_type"),
    serviceFeeValue: Number(templateValue(template, "service_fee_value")),
    driverFeePercentage: Number(templateValue(template, "driver_fee_percentage")),
    stripeCardPercentage: Number(templateValue(template, "stripe_card_percentage")),
    irsMileageRate: Number(templateValue(template, "irs_mileage_rate")),
    refundRules,
    paymentExpirationHours: Number(templateValue(template, "payment_expiration_hours")),
    tripAutoCompleteHours: Number(templateValue(template, "trip_auto_complete_hours")),
  });
  return {
    ...config,
    version: templateValue(template, "config_version"),
    templateVersion: String(template.version?.versionNumber ?? ""),
  };
}

async function audit(
  admin: {uid: string; email: string},
  action: string,
  targetType: string,
  targetId: string,
  summary: string,
  details: Json = {},
): Promise<void> {
  await db.collection("admin_audit_logs").add({
    adminUid: admin.uid,
    adminEmail: admin.email,
    action,
    targetType,
    targetId,
    summary,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function adminUserOverview(): Promise<{
  users: number;
  pendingInsurance: number;
}> {
  let users = 0;
  let pendingInsurance = 0;
  let pageToken: string | undefined;

  do {
    const page = await auth.listUsers(1_000, pageToken);
    users += page.users.length;
    const references = page.users.map((user) => db.collection("users").doc(user.uid)
      .collection("verifications").doc("current"));
    const snapshots = references.length > 0 ? await db.getAll(...references) : [];
    pendingInsurance += snapshots.filter((snapshot) =>
      snapshot.data()?.manualInsuranceSubmitted === true,
    ).length;
    pageToken = page.pageToken;
  } while (pageToken);

  return {users, pendingInsurance};
}

export const adminGetOverview = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    requireAdmin(request);
    const [userOverview, rides, bookings, disputes] = await Promise.all([
      adminUserOverview(),
      db.collection("rides").count().get(),
      db.collection("bookings").count().get(),
      db.collection("bookings").where("status", "==", "disputed").count().get(),
    ]);
    return {
      counts: {
        users: userOverview.users,
        rides: rides.data().count,
        bookings: bookings.data().count,
        pendingInsurance: userOverview.pendingInsurance,
        disputes: disputes.data().count,
      },
    };
  },
);

export const adminCompleteFirstLogin = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    const admin = requireAdmin(request);
    const user = await auth.getUser(admin.uid);
    const claims = user.customClaims ?? {};
    if (claims.mustChangePassword !== true) {
      return {completed: true};
    }
    const {mustChangePassword: _mustChangePassword, ...updatedClaims} = claims;
    await auth.setCustomUserClaims(admin.uid, updatedClaims);
    await audit(
      admin,
      "admin.first_login_completed",
      "user",
      admin.uid,
      "Administrator replaced the temporary password",
    );
    return {completed: true};
  },
);

export const adminListUsers = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    requireAdmin(request);
    const data = object(request.data ?? {});
    const pageToken = optionalText(data.pageToken, "Page token", 2_000) || undefined;
    const page = await auth.listUsers(pageSize, pageToken);
    const references = page.users.flatMap((user) => {
      const userReference = db.collection("users").doc(user.uid);
      return [
        userReference,
        userReference.collection("verifications").doc("current"),
        userReference.collection("vehicles").doc("primary"),
      ];
    });
    const snapshots = references.length > 0 ? await db.getAll(...references) : [];
    const users = page.users.map((user, index) => {
      const profile = snapshots[index * 3]?.data();
      const verification = snapshots[index * 3 + 1]?.data();
      const vehicle = snapshots[index * 3 + 2]?.data();
      return adminAccountRecord(user, profile, verification, vehicle);
    });
    return {users, nextPageToken: page.pageToken ?? ""};
  },
);

export const adminListRecords = onCall(
  {region, enforceAppCheck: false, maxInstances: 30},
  async (request) => {
    requireAdmin(request);
    const data = object(request.data ?? {});
    const kind = recordKind(data.kind);
    const cursor = optionalText(data.cursor, "Cursor", 256);
    const collection = db.collection(recordCollection(kind));
    let query: FirebaseFirestore.Query;
    if (kind === "audit") {
      query = collection.orderBy("createdAt", "desc");
      if (cursor) {
        const cursorSnapshot = await collection.doc(cursor).get();
        if (!cursorSnapshot.exists) {
          throw new HttpsError("invalid-argument", "The audit cursor is no longer available.");
        }
        query = query.startAfter(cursorSnapshot);
      }
    } else {
      query = collection.orderBy(FieldPath.documentId());
      if (cursor) query = query.startAfter(cursor);
    }
    const requested = kind === "payments" || kind === "refunds" || kind === "disputes" ?
      pageSize * 4 : pageSize;
    const snapshot = await query.limit(requested).get();
    const matching = snapshot.docs.filter((document) =>
      kind === "rides" || kind === "audit" ||
        bookingMatchesAdminView(kind as AdminBookingView, document.data()),
    ).slice(0, pageSize);
    const rideRiders = kind === "rides" ?
      await ridersByRide(matching.map((document) => document.id)) :
      new Map<string, AdminRideRider[]>();
    return {
      records: matching.map((document) => kind === "rides" ?
        adminRideRecord(document.id, document.data(), rideRiders.get(document.id) ?? []) :
        adminRecord(document.id, kind, document.data())),
      nextCursor: snapshot.size === requested ? snapshot.docs.at(-1)?.id ?? "" : "",
    };
  },
);

export const adminGetConfig = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    requireAdmin(request);
    const template = await remoteConfig.getTemplate();
    return {config: configFromTemplate(template)};
  },
);

export const adminUpdateConfig = onCall(
  {region, enforceAppCheck: false, maxInstances: 10},
  async (request) => {
    const admin = requireAdmin(request);
    let config: AdminBusinessConfig;
    try {
      config = parseAdminBusinessConfig(object(request.data).config);
    } catch {
      throw new HttpsError("invalid-argument", "Review the business configuration values.");
    }
    const template = await remoteConfig.getTemplate();
    const before = configFromTemplate(template);
    const marker = `m6-admin-${Date.now()}`;
    const updates: Record<string, {value: string; valueType: "STRING" | "NUMBER" | "JSON"}> = {
      config_version: {value: marker, valueType: "STRING"},
      service_fee_type: {value: config.serviceFeeType, valueType: "STRING"},
      service_fee_value: {value: String(config.serviceFeeValue), valueType: "NUMBER"},
      driver_fee_percentage: {
        value: String(config.driverFeePercentage),
        valueType: "NUMBER",
      },
      stripe_card_percentage: {
        value: String(config.stripeCardPercentage),
        valueType: "NUMBER",
      },
      irs_mileage_rate: {value: String(config.irsMileageRate), valueType: "NUMBER"},
      refund_rules_json: {value: JSON.stringify(config.refundRules), valueType: "JSON"},
      payment_expiration_hours: {value: String(config.paymentExpirationHours), valueType: "NUMBER"},
      trip_auto_complete_hours: {value: String(config.tripAutoCompleteHours), valueType: "NUMBER"},
    };
    for (const [key, update] of Object.entries(updates)) {
      template.parameters[key] = {
        ...template.parameters[key],
        defaultValue: {value: update.value},
        valueType: update.valueType,
      };
    }
    const validated = await remoteConfig.validateTemplate(template);
    const published = await remoteConfig.publishTemplate(validated);
    const after = configFromTemplate(published);
    await audit(
      admin,
      "config.updated",
      "remote_config",
      after.templateVersion,
      "Published M6 business configuration",
      {before, after},
    );
    return {config: after};
  },
);

export const adminSetUserStatus = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    const admin = requireAdmin(request);
    const data = object(request.data);
    const uid = requiredText(data.uid, "User", 128);
    if (uid === admin.uid) {
      throw new HttpsError("failed-precondition", "You cannot change your own admin status.");
    }
    const target = await auth.getUser(uid);
    if (target.customClaims?.admin === true) {
      throw new HttpsError(
        "failed-precondition",
        "Administrator access must be managed outside user moderation.",
      );
    }
    let status;
    try {
      status = parseAccountStatus(data.status);
    } catch {
      throw new HttpsError("invalid-argument", "Choose active, suspended, or banned.");
    }
    const reason = status === "active" ? optionalText(data.reason, "Reason") :
      requiredText(data.reason, "Reason");
    const userReference = db.collection("users").doc(uid);
    const before = (await userReference.get()).data() ?? {};
    await auth.updateUser(uid, {disabled: status !== "active"});
    await auth.revokeRefreshTokens(uid);
    await userReference.set({
      accountStatus: status,
      suspensionReason: reason,
      moderatedBy: admin.uid,
      moderatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await audit(
      admin,
      `user.${status}`,
      "user",
      uid,
      `${status === "active" ? "Restored" : status === "banned" ? "Banned" : "Suspended"} user account`,
      {previousStatus: before.accountStatus ?? "active", reason},
    );
    return {uid, status};
  },
);

export const adminVerifyUserEmail = onCall(
  {
    region,
    enforceAppCheck: false,
    invoker: "public",
    maxInstances: 20,
  },
  async (request) => {
    const admin = requireAdmin(request);
    const data = object(request.data);
    const uid = requiredText(data.uid, "User", 128);
    if (uid === admin.uid) {
      throw new HttpsError(
        "failed-precondition",
        "Your administrator email must be verified outside user management.",
      );
    }
    const target = await auth.getUser(uid);
    if (target.customClaims?.admin === true) {
      throw new HttpsError(
        "failed-precondition",
        "Administrator emails must be verified outside user management.",
      );
    }
    let email;
    try {
      email = manualVerificationEmail(target.email);
    } catch {
      throw new HttpsError(
        "failed-precondition",
        "This user does not have a valid email address to verify.",
      );
    }
    if (!target.emailVerified) {
      await auth.updateUser(uid, {emailVerified: true});
      await auth.setCustomUserClaims(uid, {
        ...(target.customClaims ?? {}),
        schoolEmailVerified: true,
      });
      await auth.revokeRefreshTokens(uid);
      await db.collection("users").doc(uid).set({
        schoolEmailVerified: true,
        schoolEmailVerifiedBy: admin.uid,
        schoolEmailVerifiedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await audit(
        admin,
        "user.email_verified",
        "user",
        uid,
        "Manually verified the user's UCSB email",
        {email},
      );
    }
    return {uid, emailVerified: true};
  },
);

export const adminUpdateUserProfile = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    const admin = requireAdmin(request);
    const data = object(request.data);
    const uid = requiredText(data.uid, "User", 128);
    if (uid === admin.uid) {
      throw new HttpsError("failed-precondition", "Edit your admin account outside user management.");
    }
    const target = await auth.getUser(uid);
    if (target.customClaims?.admin === true) {
      throw new HttpsError("failed-precondition", "Administrator profiles cannot be edited here.");
    }
    let profile;
    try {
      profile = parseAdminProfileUpdate(data.profile);
    } catch {
      throw new HttpsError(
        "invalid-argument",
        "Enter a valid adult UCSB profile and choose rider or driver.",
      );
    }
    const reference = db.collection("users").doc(uid);
    const before = (await reference.get()).data() ?? {};
    await auth.updateUser(uid, {
      email: profile.email,
      displayName: `${profile.firstName} ${profile.lastName}`,
    });
    await reference.set({
      ...profile,
      displayName: `${profile.firstName} ${profile.lastName}`,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await audit(
      admin,
      "user.profile_updated",
      "user",
      uid,
      "Updated user account information",
      {
        before: {
          firstName: before.firstName ?? "",
          lastName: before.lastName ?? "",
          email: before.email ?? target.email ?? "",
          age: before.age ?? 0,
          gender: before.gender ?? "",
          school: before.school ?? "",
          primaryRole: before.primaryRole ?? "",
        },
        after: profile,
      },
    );
    return {uid, profile};
  },
);

export const adminDeleteUserAccount = onCall(
  {region, enforceAppCheck: false, maxInstances: 10, timeoutSeconds: 120},
  async (request) => {
    const admin = requireAdmin(request);
    const data = object(request.data);
    const uid = requiredText(data.uid, "User", 128);
    const reason = requiredText(data.reason, "Reason", 1_000);
    if (data.confirmation !== "DELETE") {
      throw new HttpsError("invalid-argument", "Type DELETE to confirm.");
    }
    if (uid === admin.uid) {
      throw new HttpsError("failed-precondition", "You cannot delete your own admin account.");
    }
    const target = await auth.getUser(uid);
    if (target.customClaims?.admin === true) {
      throw new HttpsError("failed-precondition", "Administrator accounts cannot be deleted here.");
    }

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
        "Finish or cancel this user's open trips and pending payment activity first.",
      );
    }

    const conversations = await db.collection("conversations")
      .where("participantIds", "array-contains", uid)
      .limit(200)
      .get();
    await Promise.all(
      conversations.docs.map((document) => db.recursiveDelete(document.ref)),
    );

    const userReference = db.collection("users").doc(uid);
    const writes = db.batch();
    for (const ride of rides.docs) {
      writes.update(ride.ref, {
        driverName: "Deleted member",
        driverInitials: "SC",
        driverPhotoUrl: "",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
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

    const childCollections = await userReference.listCollections();
    await Promise.all(
      childCollections.map((collection) => db.recursiveDelete(collection)),
    );
    await getStorage().bucket().deleteFiles({prefix: `users/${uid}/`});
    await auth.revokeRefreshTokens(uid);
    await auth.deleteUser(uid);
    await audit(
      admin,
      "user.deleted",
      "user",
      uid,
      "Deleted user account",
      {reason, email: target.email ?? ""},
    );
    return {uid, deleted: true};
  },
);

export const adminGetInsuranceDocument = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    requireAdmin(request);
    const uid = requiredText(object(request.data).uid, "User", 128);
    const verification = (await db.collection("users").doc(uid)
      .collection("verifications").doc("current").get()).data();
    const path = verification?.insuranceDocumentPath;
    if (typeof path !== "string" || !path.startsWith(`users/${uid}/verification/insurance/`)) {
      throw new HttpsError("not-found", "No manual insurance document is available.");
    }
    const [exists] = await getStorage().bucket().file(path).exists();
    if (!exists) {
      throw new HttpsError("not-found", "The insurance document is unavailable.");
    }
    const projectId = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
    if (!projectId) throw new HttpsError("internal", "The document service is unavailable.");
    return {
      url: `https://${region}-${projectId}.cloudfunctions.net/adminInsuranceDocument?uid=${encodeURIComponent(uid)}`,
      expiresInSeconds: 600,
    };
  },
);

export const adminInsuranceDocument = onRequest(
  {
    region,
    maxInstances: 20,
    cors: [
      "https://sidecar-fb0e7.web.app",
      "https://sidecar-fb0e7.firebaseapp.com",
      "https://ride-sidecar.com",
      "https://www.ride-sidecar.com",
    ],
  },
  async (request, response) => {
    const firebaseToken = request.header("x-firebase-auth")?.trim() ?? "";
    if (!firebaseToken) {
      response.status(401).send("Administrator sign-in is required.");
      return;
    }

    let decoded;
    try {
      decoded = await auth.verifyIdToken(firebaseToken);
    } catch {
      response.status(401).send("Administrator sign-in is required.");
      return;
    }
    if (decoded.admin !== true) {
      response.status(403).send("Administrator access is required.");
      return;
    }

    const uid = typeof request.query.uid === "string" ? request.query.uid.trim() : "";
    if (!uid || uid.length > 128) {
      response.status(400).send("Choose a valid user.");
      return;
    }
    const verification = (await db.collection("users").doc(uid)
      .collection("verifications").doc("current").get()).data();
    const path = verification?.insuranceDocumentPath;
    if (typeof path !== "string" || !path.startsWith(`users/${uid}/verification/insurance/`)) {
      response.status(404).send("No manual insurance document is available.");
      return;
    }

    const file = getStorage().bucket().file(path);
    let metadata;
    try {
      [metadata] = await file.getMetadata();
    } catch {
      response.status(404).send("The insurance document is unavailable.");
      return;
    }
    response.set({
      "Cache-Control": "private, no-store, max-age=0",
      "Content-Disposition": "inline",
      "Content-Type": metadata.contentType ?? "application/octet-stream",
      "X-Content-Type-Options": "nosniff",
    });
    await new Promise<void>((resolve) => {
      const stream = file.createReadStream();
      stream.on("error", () => {
        if (!response.headersSent) response.status(500).send("Unable to read the document.");
        else response.end();
        resolve();
      });
      stream.on("end", resolve);
      stream.pipe(response);
    });
  },
);

export const adminReviewInsurance = onCall(
  {region, enforceAppCheck: false, maxInstances: 20},
  async (request) => {
    const admin = requireAdmin(request);
    const data = object(request.data);
    const uid = requiredText(data.uid, "User", 128);
    let decision;
    try {
      decision = parseInsuranceDecision(data.decision);
    } catch {
      throw new HttpsError("invalid-argument", "Approve or reject the insurance document.");
    }
    const reason = decision === "rejected" ? requiredText(data.reason, "Reason") :
      optionalText(data.reason, "Reason");
    const reference = db.collection("users").doc(uid)
      .collection("verifications").doc("current");
    const snapshot = await reference.get();
    const before = snapshot.data();
    if (!before || before.manualInsuranceSubmitted !== true ||
        typeof before.insuranceDocumentPath !== "string") {
      throw new HttpsError("failed-precondition", "No manual insurance submission is pending.");
    }
    const insuranceStatus = decision === "verified" ? "verified" : "requiresAction";
    await reference.set({
      insuranceStatus,
      insuranceVerificationProvider: "manual_admin_review",
      insuranceReviewDecision: decision,
      insuranceReviewReason: reason,
      insuranceReviewedBy: admin.uid,
      insuranceReviewedAt: FieldValue.serverTimestamp(),
      insuranceVerifiedAt: decision === "verified" ? FieldValue.serverTimestamp() : null,
      manualInsuranceSubmitted: false,
      lastError: decision === "rejected" ? reason : "",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await audit(
      admin,
      `insurance.${decision}`,
      "user_verification",
      uid,
      `${decision === "verified" ? "Approved" : "Rejected"} manual insurance document`,
      {previousStatus: before.insuranceStatus ?? "notStarted", reason},
    );
    return {uid, insuranceStatus};
  },
);
