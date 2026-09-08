type Json = Record<string, unknown>;

export interface AdminProfileUpdate {
  firstName: string;
  lastName: string;
  email: string;
  age: number;
  gender: string;
  school: string;
  primaryRole: "rider" | "driver";
}

function requiredString(value: unknown, field: string, max: number): string {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    throw new Error(`${field}-invalid`);
  }
  return value.trim();
}

export function parseAdminProfileUpdate(value: unknown): AdminProfileUpdate {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("profile-invalid");
  }
  const data = value as Json;
  const email = requiredString(data.email, "email", 320).toLowerCase();
  if (!/^[^@\s]+@ucsb\.edu$/i.test(email)) throw new Error("email-invalid");
  const age = Number(data.age);
  if (!Number.isInteger(age) || age < 18 || age > 100) {
    throw new Error("age-invalid");
  }
  const role = data.primaryRole;
  if (role !== "rider" && role !== "driver") throw new Error("role-invalid");
  return {
    firstName: requiredString(data.firstName, "first-name", 80),
    lastName: requiredString(data.lastName, "last-name", 80),
    email,
    age,
    gender: requiredString(data.gender, "gender", 80),
    school: requiredString(data.school, "school", 120),
    primaryRole: role,
  };
}

export function manualVerificationEmail(value: unknown): string {
  const email = requiredString(value, "email", 320).toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new Error("email-invalid");
  }
  return email;
}

export interface AdminAuthUser {
  uid: string;
  email?: string;
  emailVerified: boolean;
  disabled: boolean;
  customClaims?: Record<string, unknown>;
}

function timestampIso(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const toDate = (value as {toDate?: unknown}).toDate;
  if (typeof toDate !== "function") return null;
  const date = toDate.call(value) as unknown;
  return date instanceof Date && Number.isFinite(date.getTime()) ?
    date.toISOString() : null;
}

export function adminAccountRecord(
  user: AdminAuthUser,
  profile: Json | undefined,
  verification: Json | undefined,
  vehicle: Json | undefined,
): Json {
  return {
    uid: user.uid,
    email: user.email ?? "",
    emailVerified: user.emailVerified,
    disabled: user.disabled,
    isAdmin: user.customClaims?.admin === true,
    firstName: profile?.firstName ?? "",
    lastName: profile?.lastName ?? "",
    age: Number(profile?.age ?? 0),
    gender: profile?.gender ?? "",
    school: profile?.school ?? "UC Santa Barbara",
    primaryRole: profile?.primaryRole ?? "rider",
    profileComplete: profile?.profileComplete === true,
    accountStatus: profile?.accountStatus ?? "active",
    suspensionReason: profile?.suspensionReason ?? "",
    photoUrl: profile?.photoUrl ?? "",
    createdAt: timestampIso(profile?.createdAt),
    updatedAt: timestampIso(profile?.updatedAt),
    verification: {
      identityStatus: verification?.identityStatus ?? "notStarted",
      driverStatus: vehicle?.complete === true ? "verified" : "notStarted",
      insuranceStatus: verification?.insuranceStatus ?? "notStarted",
      insuranceProvider: verification?.insuranceVerificationProvider ?? "",
      manualInsuranceSubmitted: verification?.manualInsuranceSubmitted === true,
      insuranceDocumentAvailable:
        typeof verification?.insuranceDocumentPath === "string" &&
        Boolean(verification.insuranceDocumentPath),
      insuranceReviewReason:
        verification?.insuranceReviewReason ?? verification?.lastError ?? "",
      updatedAt: timestampIso(verification?.updatedAt),
    },
  };
}
