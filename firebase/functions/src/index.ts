import {createHmac, createHash, randomBytes, randomInt, timingSafeEqual} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getRemoteConfig} from "firebase-admin/remote-config";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const auth = getAuth();
const otpHashSecret = defineSecret("OTP_HASH_SECRET");
const region = "us-central1";
const otpLifetimeMinutes = 10;
const resetSessionMinutes = 10;
const maxAttempts = 6;
const resendWindowSeconds = 60;

type OtpPurpose = "verify_email" | "password_reset";

function text(value: unknown, field: string, maxLength = 200): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", `${field} is required.`);
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

function normalizeEmail(value: unknown): string {
  const email = text(value, "Email", 320).toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid school email.");
  }
  return email;
}

function validatePassword(value: unknown): string {
  if (typeof value !== "string" || value.length > 128) {
    throw new HttpsError("invalid-argument", "Password is invalid.");
  }
  const password = value;
  if (password.length < 8 || !/\d/.test(password)) {
    throw new HttpsError("invalid-argument", "Use 8+ characters with at least one number.");
  }
  return password;
}

async function allowedDomains(): Promise<Set<string>> {
  try {
    const template = await getRemoteConfig().getTemplate();
    const defaultValue = template.parameters["allowed_school_domains"]?.defaultValue;
    if (defaultValue && "value" in defaultValue) {
      const decoded = JSON.parse(defaultValue.value) as unknown;
      if (Array.isArray(decoded)) {
        const domains = decoded
          .filter((item): item is string => typeof item === "string")
          .map((item) => item.trim().toLowerCase().replace(/^@/, ""))
          .filter(Boolean);
        if (domains.length > 0) return new Set(domains);
      }
    }
  } catch {
    // A closed launch allow-list is safer than accepting every .edu address.
  }
  return new Set(["ucsb.edu"]);
}

async function allowedTestEmails(): Promise<Set<string>> {
  try {
    const template = await getRemoteConfig().getTemplate();
    const defaultValue = template.parameters["allowed_test_emails"]?.defaultValue;
    if (defaultValue && "value" in defaultValue) {
      const decoded = JSON.parse(defaultValue.value) as unknown;
      if (Array.isArray(decoded)) {
        return new Set(
          decoded
            .filter((item): item is string => typeof item === "string")
            .map((item) => item.trim().toLowerCase())
            .filter(Boolean),
        );
      }
    }
  } catch {
    // Test exceptions fail closed if Remote Config cannot be read.
  }
  return new Set();
}

async function assertAllowedSchoolEmail(email: string): Promise<void> {
  if ((await allowedTestEmails()).has(email)) return;
  const domain = email.split("@").at(-1) ?? "";
  if (!(await allowedDomains()).has(domain)) {
    throw new HttpsError(
      "permission-denied",
      "Use an approved school email. SideCar is launching at UCSB first.",
    );
  }
}

function documentId(purpose: OtpPurpose, email: string): string {
  return createHash("sha256").update(`${purpose}:${email}`).digest("hex");
}

function digest(value: string): string {
  return createHmac("sha256", otpHashSecret.value()).update(value).digest("hex");
}

function constantTimeMatch(left: string, right: string): boolean {
  const a = Buffer.from(left, "hex");
  const b = Buffer.from(right, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

async function sendOtp(params: {
  email: string;
  purpose: OtpPurpose;
  uid: string;
  enforceResendWindow?: boolean;
}): Promise<void> {
  const {email, purpose, uid, enforceResendWindow = true} = params;
  const reference = db.collection("auth_otps").doc(documentId(purpose, email));
  const now = Timestamp.now();

  if (enforceResendWindow) {
    const existing = await reference.get();
    const lastSentAt = existing.data()?.lastSentAt as Timestamp | undefined;
    if (lastSentAt && now.seconds - lastSentAt.seconds < resendWindowSeconds) {
      throw new HttpsError("resource-exhausted", "Wait a moment before requesting another code.");
    }
  }

  const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
  await reference.set({
    uid,
    email,
    purpose,
    digest: digest(`${purpose}:${uid}:${code}`),
    attempts: 0,
    createdAt: FieldValue.serverTimestamp(),
    lastSentAt: now,
    expiresAt: Timestamp.fromMillis(Date.now() + otpLifetimeMinutes * 60_000),
  });

  const subject = purpose === "verify_email" ? "Verify your SideCar email" : "Reset your SideCar password";
  const action = purpose === "verify_email" ? "verify your school email" : "reset your password";
  await db.collection("mail").add({
    to: email,
    message: {
      subject,
      text: `Your SideCar code is ${code}. It expires in ${otpLifetimeMinutes} minutes.`,
      html: `<p>Use this code to ${action}:</p><p style="font-size:28px;font-weight:700;letter-spacing:6px">${code}</p><p>This code expires in ${otpLifetimeMinutes} minutes and can be used once.</p>`,
    },
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function consumeOtp(params: {
  email: string;
  purpose: OtpPurpose;
  uid: string;
  code: string;
}): Promise<void> {
  const {email, purpose, uid, code} = params;
  const reference = db.collection("auth_otps").doc(documentId(purpose, email));
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data();
    if (!data || data.uid !== uid || data.purpose !== purpose) {
      throw new HttpsError("invalid-argument", "That code is invalid or expired.");
    }
    const expiresAt = data.expiresAt as Timestamp;
    const attempts = Number(data.attempts ?? 0);
    if (expiresAt.toMillis() <= Date.now() || attempts >= maxAttempts) {
      transaction.delete(reference);
      throw new HttpsError("invalid-argument", "That code is invalid or expired.");
    }
    const expected = digest(`${purpose}:${uid}:${code}`);
    if (!constantTimeMatch(data.digest as string, expected)) {
      transaction.update(reference, {attempts: FieldValue.increment(1)});
      throw new HttpsError("invalid-argument", "That code is invalid or expired.");
    }
    transaction.delete(reference);
  });
}

export const createStudentAccount = onCall(
  {region, enforceAppCheck: true, secrets: [otpHashSecret], maxInstances: 30},
  async (request) => {
    const data = request.data as Record<string, unknown>;
    const firstName = text(data.firstName, "First name", 80);
    const lastName = text(data.lastName, "Last name", 80);
    const email = normalizeEmail(data.email);
    const password = validatePassword(data.password);
    await assertAllowedSchoolEmail(email);

    let uid: string | undefined;
    try {
      const user = await auth.createUser({
        email,
        password,
        displayName: `${firstName} ${lastName}`,
        emailVerified: false,
        disabled: false,
      });
      uid = user.uid;
      await db.collection("users").doc(uid).set({
        firstName,
        lastName,
        displayName: `${firstName} ${lastName}`,
        email,
        school: "UC Santa Barbara",
        homeBase: "",
        major: "",
        graduationYear: 0,
        photoUrl: "",
        profileComplete: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await sendOtp({email, purpose: "verify_email", uid, enforceResendWindow: false});
      return {created: true};
    } catch (error) {
      if (uid) {
        await Promise.all([
          auth.deleteUser(uid).catch(() => undefined),
          db.collection("users").doc(uid).delete().catch(() => undefined),
        ]);
      }
      if ((error as {code?: string}).code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "An account already exists for this email.");
      }
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "We could not create your account.");
    }
  },
);

export const completeGoogleStudentSignIn = onCall(
  {region, enforceAppCheck: true, maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const user = await auth.getUser(request.auth.uid);
    if (!user.email) throw new HttpsError("failed-precondition", "This account has no email.");

    try {
      await assertAllowedSchoolEmail(user.email);
    } catch (error) {
      await Promise.all([
        auth.deleteUser(user.uid).catch(() => undefined),
        db.collection("users").doc(user.uid).delete().catch(() => undefined),
      ]);
      throw error;
    }

    const nameParts = (user.displayName ?? "")
      .trim()
      .split(/\s+/)
      .filter(Boolean);
    const firstName = nameParts.at(0) ?? "Student";
    const lastName = nameParts.slice(1).join(" ") || "Member";
    const reference = db.collection("users").doc(user.uid);
    const existing = await reference.get();
    if (!existing.exists) {
      await reference.set({
        firstName,
        lastName,
        displayName: `${firstName} ${lastName}`,
        email: user.email,
        school: "UC Santa Barbara",
        homeBase: "",
        major: "",
        graduationYear: 0,
        photoUrl: user.photoURL ?? "",
        profileComplete: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await auth.setCustomUserClaims(user.uid, {schoolEmailVerified: true});
    return {accepted: true};
  },
);

export const requestEmailVerificationCode = onCall(
  {region, enforceAppCheck: true, secrets: [otpHashSecret], maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const data = request.data as Record<string, unknown>;
    const user = await auth.getUser(request.auth.uid);
    if (!user.email) throw new HttpsError("failed-precondition", "This account has no email.");
    if (user.emailVerified) return {accepted: true};
    await assertAllowedSchoolEmail(user.email);

    if (data.firstName !== undefined || data.lastName !== undefined) {
      const firstName = text(data.firstName, "First name", 80);
      const lastName = text(data.lastName, "Last name", 80);
      const displayName = `${firstName} ${lastName}`;
      await Promise.all([
        auth.updateUser(user.uid, {displayName}),
        db.collection("users").doc(user.uid).set({
          firstName,
          lastName,
          displayName,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
      ]);
    }

    await sendOtp({email: user.email, purpose: "verify_email", uid: user.uid});
    return {accepted: true};
  },
);

export const verifyEmailCode = onCall(
  {region, enforceAppCheck: true, secrets: [otpHashSecret], maxInstances: 30},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const user = await auth.getUser(request.auth.uid);
    if (!user.email) throw new HttpsError("failed-precondition", "This account has no email.");
    const code = text((request.data as Record<string, unknown>).code, "Code", 6);
    if (!/^\d{6}$/.test(code)) throw new HttpsError("invalid-argument", "Enter a six-digit code.");
    await consumeOtp({email: user.email, purpose: "verify_email", uid: user.uid, code});
    await auth.updateUser(user.uid, {emailVerified: true});
    await auth.setCustomUserClaims(user.uid, {schoolEmailVerified: true});
    return {verified: true};
  },
);

export const requestPasswordResetCode = onCall(
  {region, enforceAppCheck: true, secrets: [otpHashSecret], maxInstances: 30},
  async (request) => {
    const email = normalizeEmail((request.data as Record<string, unknown>).email);
    await assertAllowedSchoolEmail(email);
    try {
      const user = await auth.getUserByEmail(email);
      await sendOtp({email, purpose: "password_reset", uid: user.uid});
    } catch (error) {
      if ((error as {code?: string}).code !== "auth/user-not-found") throw error;
    }
    return {accepted: true};
  },
);

export const verifyPasswordResetCode = onCall(
  {region, enforceAppCheck: true, secrets: [otpHashSecret], maxInstances: 30},
  async (request) => {
    const data = request.data as Record<string, unknown>;
    const email = normalizeEmail(data.email);
    const code = text(data.code, "Code", 6);
    if (!/^\d{6}$/.test(code)) throw new HttpsError("invalid-argument", "Enter a six-digit code.");
    let user;
    try {
      user = await auth.getUserByEmail(email);
    } catch {
      throw new HttpsError("invalid-argument", "That code is invalid or expired.");
    }
    await consumeOtp({email, purpose: "password_reset", uid: user.uid, code});
    const resetToken = randomBytes(32).toString("base64url");
    await db.collection("password_reset_sessions").doc(documentId("password_reset", email)).set({
      uid: user.uid,
      email,
      tokenDigest: digest(`reset:${user.uid}:${resetToken}`),
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + resetSessionMinutes * 60_000),
    });
    return {resetToken};
  },
);

export const completePasswordReset = onCall(
  {region, enforceAppCheck: true, secrets: [otpHashSecret], maxInstances: 30},
  async (request) => {
    const data = request.data as Record<string, unknown>;
    const email = normalizeEmail(data.email);
    const resetToken = text(data.resetToken, "Reset token", 256);
    const newPassword = validatePassword(data.newPassword);
    const reference = db.collection("password_reset_sessions").doc(documentId("password_reset", email));
    const uid = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const session = snapshot.data();
      if (!session || (session.expiresAt as Timestamp).toMillis() <= Date.now()) {
        transaction.delete(reference);
        throw new HttpsError("invalid-argument", "Your reset session expired. Request a new code.");
      }
      const sessionUid = session.uid as string;
      const expected = digest(`reset:${sessionUid}:${resetToken}`);
      if (!constantTimeMatch(session.tokenDigest as string, expected)) {
        throw new HttpsError("invalid-argument", "Your reset session is invalid.");
      }
      transaction.delete(reference);
      return sessionUid;
    });
    await auth.updateUser(uid, {password: newPassword});
    await auth.revokeRefreshTokens(uid);
    return {updated: true};
  },
);
