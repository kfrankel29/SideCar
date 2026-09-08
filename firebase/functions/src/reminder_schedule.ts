export const tripReminderThresholds = [24 * 60, 30, 10] as const;

export function dueTripReminderMinutes(minutesUntilDeparture: number): number[] {
  if (!Number.isFinite(minutesUntilDeparture) || minutesUntilDeparture <= 0) return [];
  return tripReminderThresholds.filter((threshold) => {
    if (threshold === 24 * 60) return minutesUntilDeparture > 23 * 60 && minutesUntilDeparture <= 25 * 60;
    if (threshold === 30) return minutesUntilDeparture > 25 && minutesUntilDeparture <= 35;
    return minutesUntilDeparture > 5 && minutesUntilDeparture <= 15;
  });
}
