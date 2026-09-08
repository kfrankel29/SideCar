export const legalVersion = "2026-09-03";

export interface LegalAcceptance {
  version: string;
  termsUrl: string;
  privacyUrl: string;
}

export function parseLegalAcceptance(
  data: Record<string, unknown>,
): LegalAcceptance {
  if (data.acceptedLegalTerms !== true || data.confirmedAge18 !== true) {
    throw new Error("legal-consent-required");
  }
  if (data.legalVersion !== legalVersion) {
    throw new Error("legal-version-mismatch");
  }
  return {
    version: legalVersion,
    termsUrl: "https://sidecar-fb0e7.web.app/terms/",
    privacyUrl: "https://sidecar-fb0e7.web.app/privacy/",
  };
}
