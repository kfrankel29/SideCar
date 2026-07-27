import assert from "node:assert/strict";
import test from "node:test";
import {parseManualInsuranceDocument} from "./manual_insurance.js";

test("accepts the supported manual insurance formats", () => {
  for (const [contentType, extension] of [
    ["image/jpeg", "jpg"],
    ["image/png", "png"],
    ["application/pdf", "pdf"],
  ]) {
    const document = parseManualInsuranceDocument(
      Buffer.from("insurance").toString("base64"),
      contentType,
    );
    assert.equal(document.contentType, contentType);
    assert.equal(document.extension, extension);
    assert.equal(document.bytes.toString(), "insurance");
  }
});

test("rejects unsupported, empty, malformed, and oversized documents", () => {
  assert.throws(
    () => parseManualInsuranceDocument("aW5zdXJhbmNl", "image/gif"),
    /unsupported-content-type/,
  );
  assert.throws(
    () => parseManualInsuranceDocument("", "image/jpeg"),
    /empty-document/,
  );
  assert.throws(
    () => parseManualInsuranceDocument("not base64", "image/jpeg"),
    /invalid-base64/,
  );
  assert.throws(
    () => parseManualInsuranceDocument(
      Buffer.alloc(10 * 1024 * 1024).toString("base64"),
      "application/pdf",
    ),
    /document-too-large/,
  );
});
