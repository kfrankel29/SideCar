export interface InsuranceTestVerificationContext {
  email: string | undefined;
  emailVerified: boolean;
  schoolEmailVerified: boolean;
  allowedTestEmails: ReadonlySet<string>;
  identityStatus: unknown;
  vehicleComplete: unknown;
}

export type InsuranceTestVerificationEligibility =
  | {allowed: true}
  | {
    allowed: false;
    reason: "email" | "email-verification" | "identity" | "vehicle";
  };

export function insuranceTestVerificationEligibility(
  context: InsuranceTestVerificationContext,
): InsuranceTestVerificationEligibility {
  const email = context.email?.trim().toLowerCase() ?? "";
  if (!email || !context.allowedTestEmails.has(email)) {
    return {allowed: false, reason: "email"};
  }
  if (!context.emailVerified && !context.schoolEmailVerified) {
    return {allowed: false, reason: "email-verification"};
  }
  if (context.identityStatus !== "verified") {
    return {allowed: false, reason: "identity"};
  }
  if (context.vehicleComplete !== true) {
    return {allowed: false, reason: "vehicle"};
  }
  return {allowed: true};
}
