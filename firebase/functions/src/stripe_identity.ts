export type StripeIdentitySessionReference = {
  metadata?: Record<string, string> | null;
  client_reference_id?: string | null;
};

export type StripeIdentityExistingSession = {
  status?: string | null;
  url?: string | null;
};

export type StripeIdentityExistingSessionOutcome =
  | {kind: "verified"}
  | {kind: "resume"; url: string}
  | {kind: "create"};

export function stripeIdentityExistingSessionOutcome(
  session: StripeIdentityExistingSession,
): StripeIdentityExistingSessionOutcome {
  if (session.status === "verified") return {kind: "verified"};
  if (typeof session.url === "string" && session.url.length > 0) {
    return {kind: "resume", url: session.url};
  }
  return {kind: "create"};
}

export function stripeIdentityStatusForEvent(eventType: string): string {
  if (eventType.endsWith(".verified")) return "verified";
  if (eventType.endsWith(".requires_input")) return "requiresAction";
  if (eventType.endsWith(".canceled")) return "failed";
  if (eventType.endsWith(".redacted")) return "notStarted";
  return "pending";
}

export function stripeIdentitySessionUid(
  session: StripeIdentitySessionReference,
): string | null {
  const metadataUid = session.metadata?.uid?.trim();
  if (metadataUid) return metadataUid;

  const clientReferenceId = session.client_reference_id?.trim();
  return clientReferenceId || null;
}
