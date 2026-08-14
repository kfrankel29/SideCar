export interface RouteWaypoint {
  placeId: string;
  latitude: number;
  longitude: number;
}

export interface OptimizedRoute {
  orderedIndexes: number[];
  legDurationSeconds: number[];
  encodedPolyline: string;
}

function durationSeconds(value: unknown): number {
  if (typeof value !== "string" || !value.endsWith("s")) return 0;
  const seconds = Number(value.slice(0, -1));
  return Number.isFinite(seconds) ? Math.max(0, Math.round(seconds)) : 0;
}

export function parseOptimizedRoute(
  response: Record<string, unknown>,
  waypointCount: number,
): OptimizedRoute {
  const routes = Array.isArray(response.routes) ? response.routes : [];
  const route = routes[0] && typeof routes[0] === "object" ?
    routes[0] as Record<string, unknown> : {};
  const rawOrder = Array.isArray(route.optimizedIntermediateWaypointIndex) ?
    route.optimizedIntermediateWaypointIndex : [];
  const orderedIndexes = rawOrder
    .filter((value): value is number => Number.isInteger(value))
    .filter((value) => value >= 0 && value < waypointCount);
  if (orderedIndexes.length !== waypointCount) {
    orderedIndexes.splice(0, orderedIndexes.length,
      ...Array.from({length: waypointCount}, (_, index) => index));
  }
  const legs = Array.isArray(route.legs) ? route.legs : [];
  const legDurationSeconds = legs.map((leg) =>
    durationSeconds(leg && typeof leg === "object" ?
      (leg as Record<string, unknown>).duration : null));
  const polyline = route.polyline && typeof route.polyline === "object" ?
    route.polyline as Record<string, unknown> : {};
  return {
    orderedIndexes,
    legDurationSeconds,
    encodedPolyline: typeof polyline.encodedPolyline === "string" ?
      polyline.encodedPolyline : "",
  };
}

export function cumulativeArrivalSeconds(
  route: OptimizedRoute,
  waypointCount: number,
): number[] {
  const result: number[] = [];
  let elapsed = 0;
  for (let index = 0; index < waypointCount; index += 1) {
    elapsed += route.legDurationSeconds[index] ?? 0;
    result.push(elapsed);
  }
  return result;
}

export function googleWaypoint(waypoint: RouteWaypoint): Record<string, unknown> {
  if (waypoint.placeId.trim()) return {placeId: waypoint.placeId.trim()};
  return {
    location: {
      latLng: {
        latitude: waypoint.latitude,
        longitude: waypoint.longitude,
      },
    },
  };
}
