export function bookedSeatCount(
  seatsTotal: number,
  seatsAvailable: number,
): number {
  return Math.max(0, seatsTotal - seatsAvailable);
}

export function publicSeatInventory(
  status: unknown,
  seatsTotalValue: unknown,
  seatsAvailableValue: unknown,
  bookedSeatsValue: unknown,
): {seatsTotal: number; seatsAvailable: number; bookedSeats: number} {
  const seatsTotal = Number.isInteger(seatsTotalValue) ?
    Math.max(0, Number(seatsTotalValue)) : 0;
  if (status === "cancelled") {
    return {seatsTotal, seatsAvailable: seatsTotal, bookedSeats: 0};
  }
  const seatsAvailable = Number.isInteger(seatsAvailableValue) ?
    Math.min(seatsTotal, Math.max(0, Number(seatsAvailableValue))) : 0;
  const bookedSeats = Number.isInteger(bookedSeatsValue) ?
    Math.min(seatsTotal, Math.max(0, Number(bookedSeatsValue))) :
    bookedSeatCount(seatsTotal, seatsAvailable);
  return {seatsTotal, seatsAvailable, bookedSeats};
}

export function availableSeatsAfterUpdate(
  currentTotal: number,
  currentAvailable: number,
  requestedTotal: number,
): number | null {
  const booked = bookedSeatCount(currentTotal, currentAvailable);
  return requestedTotal < booked ? null : requestedTotal - booked;
}

export function isPriceWithinLimit(
  requestedPriceCents: number,
  maximumPriceCents: number,
): boolean {
  return maximumPriceCents <= 0 || requestedPriceCents <= maximumPriceCents;
}

export function rideIntervalsOverlap(
  firstDepartureMillis: number,
  firstDurationSeconds: number,
  secondDepartureMillis: number,
  secondDurationSeconds: number,
): boolean {
  const firstEnd = firstDepartureMillis + Math.max(1, firstDurationSeconds) * 1000;
  const secondEnd = secondDepartureMillis + Math.max(1, secondDurationSeconds) * 1000;
  return firstDepartureMillis < secondEnd && secondDepartureMillis < firstEnd;
}

export function normalizeImmediateDeparture(
  requestedMillis: number,
  nowMillis: number,
): number | null {
  const fiveMinutes = 5 * 60 * 1000;
  const latestAllowed = nowMillis + 366 * 24 * 60 * 60 * 1000;
  if (requestedMillis < nowMillis - fiveMinutes || requestedMillis > latestAllowed) {
    return null;
  }
  return Math.max(requestedMillis, nowMillis);
}
