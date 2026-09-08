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
// Keep returned map pins comfortably inside the client's one-mile limit.
// The buffer prevents a pin whose center barely passes the calculation from
// appearing outside the visible route corridor because of map projection and
// marker size.
export const gasStationRouteMaximumMiles = 0.5;

export function searchRadiusMilesForPlace(
  placeTypes: ReadonlyArray<string>,
  exactStopRadiusMiles = 1,
): number {
  const types = new Set(placeTypes);
  if (types.has("administrative_area_level_1")) return 35;
  if (types.has("administrative_area_level_2")) return 22;
  if (types.has("locality")) return 12;
  if (types.has("postal_code")) return 7.5;
  if (types.has("sublocality") || types.has("neighborhood")) return 4;
  return exactStopRadiusMiles;
}

export function distanceMilesBetween(first: GeoPoint, second: GeoPoint): number {
  const earthRadiusMiles = 3958.7613;
  const latitudeDelta = (second.latitude - first.latitude) * Math.PI / 180;
  const longitudeDelta = (second.longitude - first.longitude) * Math.PI / 180;
  const firstLatitude = first.latitude * Math.PI / 180;
  const secondLatitude = second.latitude * Math.PI / 180;
  const haversine = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(firstLatitude) * Math.cos(secondLatitude) *
    Math.sin(longitudeDelta / 2) ** 2;
  return 2 * earthRadiusMiles * Math.asin(Math.min(1, Math.sqrt(haversine)));
}

export function pointMatchesRouteAndSearchArea(params: {
  point: GeoPoint;
  route: ReadonlyArray<GeoPoint>;
  searchAnchors: ReadonlyArray<GeoPoint>;
  maximumRouteDistanceMiles?: number;
  maximumSearchDistanceMiles?: number;
}): boolean {
  if (proximityToRoute(params.point, params.route).distanceMiles >
      (params.maximumRouteDistanceMiles ?? gasStationRouteMaximumMiles)) return false;
  if (params.searchAnchors.length === 0) return true;
  return Math.min(...params.searchAnchors.map((anchor) =>
    distanceMilesBetween(params.point, anchor),
  )) <= (params.maximumSearchDistanceMiles ?? 15.5343);
}

export function gasStationMatchesRoute(
  point: GeoPoint,
  route: ReadonlyArray<GeoPoint>,
): boolean {
  return route.length >= 2 &&
    proximityToRoute(point, route).distanceMiles <= gasStationRouteMaximumMiles;
}

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

export function routeSearchMatch(params: {
  route: ReadonlyArray<GeoPoint>;
  pickup: GeoPoint;
  dropoff: GeoPoint;
  pickupRadiusMiles: number;
  dropoffRadiusMiles: number;
  boundaryExceptions: ReadonlyArray<PolygonRing>;
}): boolean {
  const pickup = routePointAllowed({
    point: params.pickup,
    route: params.route,
    maximumDetourMiles: params.pickupRadiusMiles,
    boundaryExceptions: params.boundaryExceptions,
  });
  const dropoff = routePointAllowed({
    point: params.dropoff,
    route: params.route,
    maximumDetourMiles: params.dropoffRadiusMiles,
    boundaryExceptions: params.boundaryExceptions,
  });
  return pickup.allowed && dropoff.allowed && pickup.progress <= dropoff.progress;
}
