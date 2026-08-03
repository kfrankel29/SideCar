export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface RouteProximity {
  distanceMiles: number;
  progress: number;
}

export type PolygonRing = ReadonlyArray<readonly [number, number]>;

const milesPerLatitudeDegree = 69.0;

export function decodeGooglePolyline(value: string): GeoPoint[] {
  const points: GeoPoint[] = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;
  while (index < value.length) {
    const latitudeResult = decodeComponent(value, index);
    index = latitudeResult.nextIndex;
    latitude += latitudeResult.delta;
    const longitudeResult = decodeComponent(value, index);
    index = longitudeResult.nextIndex;
    longitude += longitudeResult.delta;
    points.push({latitude: latitude / 1e5, longitude: longitude / 1e5});
  }
  return points;
}

function decodeComponent(
  value: string,
  startIndex: number,
): {delta: number; nextIndex: number} {
  let result = 0;
  let shift = 0;
  let index = startIndex;
  let byte: number;
  do {
    if (index >= value.length) throw new Error("invalid-polyline");
    byte = value.charCodeAt(index++) - 63;
    if (byte < 0 || byte > 63) throw new Error("invalid-polyline");
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  const delta = result & 1 ? ~(result >> 1) : result >> 1;
  return {delta, nextIndex: index};
}

export function proximityToRoute(
  point: GeoPoint,
  route: ReadonlyArray<GeoPoint>,
): RouteProximity {
  if (route.length < 2) throw new Error("route-too-short");
  const longitudeScale = milesPerLatitudeDegree *
    Math.cos(point.latitude * Math.PI / 180);
  let closest: RouteProximity = {
    distanceMiles: Number.POSITIVE_INFINITY,
    progress: 0,
  };
  for (let index = 0; index < route.length - 1; index++) {
    const start = route[index]!;
    const end = route[index + 1]!;
    const startX = (start.longitude - point.longitude) * longitudeScale;
    const startY = (start.latitude - point.latitude) * milesPerLatitudeDegree;
    const endX = (end.longitude - point.longitude) * longitudeScale;
    const endY = (end.latitude - point.latitude) * milesPerLatitudeDegree;
    const deltaX = endX - startX;
    const deltaY = endY - startY;
    const lengthSquared = deltaX * deltaX + deltaY * deltaY;
    const projection = lengthSquared === 0 ? 0 :
      Math.max(0, Math.min(1, -(startX * deltaX + startY * deltaY) / lengthSquared));
    const closestX = startX + projection * deltaX;
    const closestY = startY + projection * deltaY;
    const distanceMiles = Math.hypot(closestX, closestY);
    if (distanceMiles < closest.distanceMiles) {
      closest = {distanceMiles, progress: index + projection};
    }
  }
  return closest;
}

export function pointInPolygon(point: GeoPoint, ring: PolygonRing): boolean {
  if (ring.length < 4) return false;
  let inside = false;
  for (let current = 0, previous = ring.length - 1;
    current < ring.length;
    previous = current++) {
    const [currentLongitude, currentLatitude] = ring[current]!;
    const [previousLongitude, previousLatitude] = ring[previous]!;
    const intersects = currentLatitude > point.latitude !==
      previousLatitude > point.latitude &&
      point.longitude < (previousLongitude - currentLongitude) *
      (point.latitude - currentLatitude) /
      (previousLatitude - currentLatitude) + currentLongitude;
    if (intersects) inside = !inside;
  }
  return inside;
}

export function routePointAllowed(params: {
  point: GeoPoint;
  route: ReadonlyArray<GeoPoint>;
  maximumDetourMiles: number;
  boundaryExceptions: ReadonlyArray<PolygonRing>;
}): RouteProximity & {insideBoundaryException: boolean; allowed: boolean} {
  const proximity = proximityToRoute(params.point, params.route);
  const insideBoundaryException = params.boundaryExceptions.some(
    (ring) => pointInPolygon(params.point, ring),
  );
  return {
    ...proximity,
    insideBoundaryException,
    allowed: insideBoundaryException ||
      proximity.distanceMiles <= params.maximumDetourMiles,
  };
}
