export function distanceFromDateWindow(
  departureMillis: number,
  startMillis: number,
  endMillis: number,
): number {
  if (departureMillis < startMillis) return startMillis - departureMillis;
  if (departureMillis >= endMillis) return departureMillis - endMillis;
  return 0;
}

export function compareClosestDepartures(
  leftMillis: number,
  rightMillis: number,
  startMillis: number,
  endMillis: number,
): number {
  const distance = distanceFromDateWindow(
    leftMillis,
    startMillis,
    endMillis,
  ) - distanceFromDateWindow(rightMillis, startMillis, endMillis);
  return distance === 0 ? leftMillis - rightMillis : distance;
}
