type Json = Record<string, unknown>;

export type AdminBookingView = "bookings" | "payments" | "refunds" | "disputes";

function timestampIso(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const toDate = (value as {toDate?: unknown}).toDate;
  if (typeof toDate !== "function") return null;
  const date = toDate.call(value) as unknown;
  return date instanceof Date && Number.isFinite(date.getTime()) ?
    date.toISOString() : null;
}

export function bookingMatchesAdminView(kind: AdminBookingView, data: Json): boolean {
  if (kind === "bookings") return true;
  if (kind === "payments") {
    return Boolean(data.paymentStatus) || Number(data.totalCents ?? 0) > 0;
  }
  if (kind === "refunds") {
    return String(data.paymentStatus ?? "").includes("refund") ||
      Boolean(data.refundedAt) || Boolean(data.refundReason) ||
      Boolean(data.cancellationSummary);
  }
  return data.status === "disputed" || Boolean(data.disputeReason) ||
    Boolean(data.disputedAt);
}

export function adminBookingRecord(id: string, data: Json): Json {
  const cancellation = data.cancellationSummary &&
    typeof data.cancellationSummary === "object" &&
    !Array.isArray(data.cancellationSummary) ? data.cancellationSummary as Json : {};
  return {
    id,
    rideId: data.rideId ?? "",
    riderId: data.riderId ?? "",
    riderName: data.riderName ?? "",
    driverId: data.driverId ?? "",
    driverName: data.driverName ?? "",
    originName: data.originName ?? "",
    destinationName: data.destinationName ?? "",
    status: data.status ?? "",
    paymentStatus: data.paymentStatus ?? "",
    payoutStatus: data.payoutStatus ?? "",
    totalCents: data.totalCents ?? data.baseFareCents ?? 0,
    riderRefundCents: cancellation.riderRefundCents ?? 0,
    refundReason: data.refundReason ?? "",
    disputeReason: data.disputeReason ?? "",
    departureAt: timestampIso(data.departureAt),
    confirmedAt: timestampIso(data.confirmedAt),
    refundedAt: timestampIso(data.refundedAt),
    disputedAt: timestampIso(data.disputedAt),
    createdAt: timestampIso(data.createdAt),
    updatedAt: timestampIso(data.updatedAt),
  };
}
