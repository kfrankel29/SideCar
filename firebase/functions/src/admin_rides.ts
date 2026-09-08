type Json = Record<string, unknown>;

function objectOrEmpty(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value) ?
    value as Json : {};
}

function timestampIso(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const toDate = (value as {toDate?: unknown}).toDate;
  if (typeof toDate !== "function") return null;
  const date = toDate.call(value) as unknown;
  return date instanceof Date && Number.isFinite(date.getTime()) ?
    date.toISOString() : null;
}

export interface AdminRideRider {
  id: string;
  name: string;
  status: string;
  seat: string;
}

export function adminRideRecord(
  id: string,
  data: Json,
  riders: ReadonlyArray<AdminRideRider> = [],
): Json {
  const origin = objectOrEmpty(data.origin);
  const destination = objectOrEmpty(data.destination);
  return {
    id,
    driverId: data.driverId ?? "",
    driverName: data.driverName ?? "",
    originName: origin.displayName ?? origin.name ?? data.originName ?? "",
    destinationName:
      destination.displayName ?? destination.name ?? data.destinationName ?? "",
    status: data.status ?? "",
    departureAt: timestampIso(data.departureAt),
    seatsTotal: data.seatsTotal ?? 0,
    seatsAvailable: data.seatsAvailable ?? 0,
    pricePerSeatCents: data.pricePerSeatCents ?? 0,
    createdAt: timestampIso(data.createdAt),
    updatedAt: timestampIso(data.updatedAt),
    riders: riders.map((rider) => ({...rider})),
  };
}
