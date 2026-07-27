const allowedContentTypes = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["application/pdf", "pdf"],
]);

const maxDocumentBytes = 10 * 1024 * 1024;

export type ManualInsuranceDocument = {
  bytes: Buffer;
  contentType: string;
  extension: string;
};

export function parseManualInsuranceDocument(
  encodedBytes: unknown,
  requestedContentType: unknown,
): ManualInsuranceDocument {
  if (typeof requestedContentType !== "string") {
    throw new Error("unsupported-content-type");
  }
  const contentType = requestedContentType.trim().toLowerCase();
  const extension = allowedContentTypes.get(contentType);
  if (!extension) {
    throw new Error("unsupported-content-type");
  }
  if (typeof encodedBytes !== "string" || encodedBytes.length === 0) {
    throw new Error("empty-document");
  }

  const normalized = encodedBytes.replace(/\s/g, "");
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(normalized) ||
      normalized.length % 4 !== 0) {
    throw new Error("invalid-base64");
  }

  const bytes = Buffer.from(normalized, "base64");
  if (bytes.length === 0) {
    throw new Error("empty-document");
  }
  if (bytes.length >= maxDocumentBytes) {
    throw new Error("document-too-large");
  }

  return {bytes, contentType, extension};
}
