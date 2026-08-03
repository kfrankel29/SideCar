const millisecondsPerWeek = 7 * 24 * 60 * 60 * 1000;

export function weeklyDepartures(
  firstDeparture: Date,
  occurrences: number,
): Date[] {
  if (!Number.isFinite(firstDeparture.getTime())) {
    throw new Error("invalid-departure");
  }
  if (!Number.isInteger(occurrences) || occurrences < 1 || occurrences > 26) {
    throw new Error("invalid-occurrences");
  }
  return Array.from(
    {length: occurrences},
    (_, index) => new Date(firstDeparture.getTime() + index * millisecondsPerWeek),
  );
}
