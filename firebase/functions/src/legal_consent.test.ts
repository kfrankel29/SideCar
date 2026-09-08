import assert from "node:assert/strict";
import test from "node:test";

import {legalVersion, parseLegalAcceptance} from "./legal_consent.js";

test("requires explicit legal acceptance and age confirmation", () => {
  assert.throws(
    () => parseLegalAcceptance({legalVersion, acceptedLegalTerms: true}),
    /legal-consent-required/,
  );
});

test("rejects an outdated legal version", () => {
  assert.throws(
    () => parseLegalAcceptance({
      legalVersion: "old",
      acceptedLegalTerms: true,
      confirmedAge18: true,
    }),
    /legal-version-mismatch/,
  );
});

test("returns canonical URLs for accepted registration", () => {
  const acceptance = parseLegalAcceptance({
    legalVersion,
    acceptedLegalTerms: true,
    confirmedAge18: true,
  });
  assert.equal(acceptance.version, legalVersion);
  assert.equal(acceptance.termsUrl, "https://sidecar-fb0e7.web.app/terms/");
  assert.equal(acceptance.privacyUrl, "https://sidecar-fb0e7.web.app/privacy/");
});
