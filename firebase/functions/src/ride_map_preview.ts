import {createHash} from "node:crypto";

const staticMapsEndpoint = "https://maps.googleapis.com/maps/api/staticmap";
const publicMapPreviewBaseUrl = "https://sidecar-fb0e7.web.app/ride-map";
const routeMapWidth = 640;
const routeMapHeight = 252;
const topMapExtension = 100;

export interface RideMapPreviewRequest {
  apiKey: string;
  encodedPolyline: string;
  origin: {latitude: number; longitude: number};
  destination: {latitude: number; longitude: number};
}

export function rideMapPreviewUrl(
  rideId: string,
  encodedPolyline = "",
): string {
  const url = new URL(publicMapPreviewBaseUrl);
  url.searchParams.set("id", rideId);
  if (encodedPolyline) {
    const routeDigest = createHash("sha256")
      .update(encodedPolyline)
      .digest("hex")
      .slice(0, 12);
    url.searchParams.set("v", `5-${routeDigest}`);
  }
  return url.toString();
}

export function compactEncodedPolyline(
  encodedPolyline: string,
  maximumLength = 4_000,
): string {
  if (encodedPolyline.length <= maximumLength) return encodedPolyline;
  const points = decodePolyline(encodedPolyline);
  if (points.length < 2) return "";

  let pointLimit = Math.min(points.length, 512);
  while (pointLimit >= 2) {
    const sampled = evenlySample(points, pointLimit);
    const encoded = encodePolyline(sampled);
    if (encoded.length <= maximumLength || pointLimit === 2) return encoded;
    pointLimit = Math.max(2, Math.floor(pointLimit * 0.75));
  }
  return "";
}

export function googleStaticMapUrl(request: RideMapPreviewRequest): string {
  const viewport = extendedMapViewport(request);
  const url = new URL(staticMapsEndpoint);
  url.searchParams.set("key", request.apiKey);
  url.searchParams.set(
    "size",
    `${routeMapWidth}x${routeMapHeight + topMapExtension}`,
  );
  url.searchParams.set("scale", "2");
  url.searchParams.set("format", "png");
  url.searchParams.set("maptype", "roadmap");
  url.searchParams.set(
    "center",
    `${viewport.center.latitude},${viewport.center.longitude}`,
  );
  url.searchParams.set("zoom", String(viewport.zoom));
  url.searchParams.append(
    "style",
    "feature:all|element:geometry|color:0xf7f7f7",
  );
  url.searchParams.append(
    "style",
    "feature:road|element:geometry|color:0xe1e4e6",
  );
  url.searchParams.append(
    "style",
    "feature:road|element:labels|visibility:off",
  );
  url.searchParams.append("style", "feature:poi|visibility:off");
  url.searchParams.append("style", "feature:transit|visibility:off");
  url.searchParams.append(
    "style",
    "feature:administrative|element:labels|visibility:off",
  );
  url.searchParams.append(
    "style",
    "feature:water|element:geometry|color:0xe8edef",
  );
  url.searchParams.set(
    "path",
    `color:0x111111ff|weight:4|enc:${request.encodedPolyline}`,
  );
  url.searchParams.append(
    "markers",
    `size:tiny|color:0xffffff|${request.origin.latitude},${request.origin.longitude}`,
  );
  url.searchParams.append(
    "markers",
    `size:tiny|color:0x111111|${request.destination.latitude},${request.destination.longitude}`,
  );
  return url.toString();
}

function extendedMapViewport(request: RideMapPreviewRequest): {
  center: {latitude: number; longitude: number};
  zoom: number;
} {
  const route = decodePolyline(request.encodedPolyline);
  const points = route.length > 1 ? route : [request.origin, request.destination];
  const projected = points.map(projectLocation);
  const xs = projected.map((point) => point.x);
  const ys = projected.map((point) => point.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const minimumSpan = 1 / (256 * 2 ** 20);
  const spanX = Math.max(maxX - minX, minimumSpan);
  const spanY = Math.max(maxY - minY, minimumSpan);
  const horizontalZoom = Math.log2((routeMapWidth - 48) / (256 * spanX));
  const verticalZoom = Math.log2((routeMapHeight - 40) / (256 * spanY));
  const zoom = Math.max(0, Math.min(20, Math.floor(
    Math.min(horizontalZoom, verticalZoom),
  )));
  const worldSize = 256 * 2 ** zoom;
  const centerX = (minX + maxX) / 2;
  const routeCenterY = (minY + maxY) / 2;
  const extendedCenterY = routeCenterY - topMapExtension / (2 * worldSize);
  return {
    center: unprojectLocation(centerX, extendedCenterY),
    zoom,
  };
}

function projectLocation(point: {latitude: number; longitude: number}): {
  x: number;
  y: number;
} {
  const latitude = Math.max(-85, Math.min(85, point.latitude));
  const sinLatitude = Math.sin(latitude * Math.PI / 180);
  return {
    x: (point.longitude + 180) / 360,
    y: 0.5 - Math.log((1 + sinLatitude) / (1 - sinLatitude)) /
      (4 * Math.PI),
  };
}

function unprojectLocation(x: number, y: number): {
  latitude: number;
  longitude: number;
} {
  const longitude = x * 360 - 180;
  const mercator = Math.PI * (1 - 2 * y);
  const latitude = Math.atan(Math.sinh(mercator)) * 180 / Math.PI;
  return {latitude, longitude};
}

function decodePolyline(value: string): Array<{
  latitude: number;
  longitude: number;
}> {
  const points: Array<{latitude: number; longitude: number}> = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;
  try {
    while (index < value.length) {
      const latitudeDelta = decodeCoordinate(value, index);
      index = latitudeDelta.nextIndex;
      latitude += latitudeDelta.value;
      const longitudeDelta = decodeCoordinate(value, index);
      index = longitudeDelta.nextIndex;
      longitude += longitudeDelta.value;
      points.push({
        latitude: latitude / 1e5,
        longitude: longitude / 1e5,
      });
    }
  } catch {
    return [];
  }
  return points;
}

function evenlySample<T>(values: T[], limit: number): T[] {
  if (values.length <= limit) return values;
  const lastIndex = values.length - 1;
  return Array.from({length: limit}, (_, index) =>
    values[Math.round(index * lastIndex / (limit - 1))]!,
  );
}

function encodePolyline(points: Array<{
  latitude: number;
  longitude: number;
}>): string {
  let previousLatitude = 0;
  let previousLongitude = 0;
  let encoded = "";
  for (const point of points) {
    const latitude = Math.round(point.latitude * 1e5);
    const longitude = Math.round(point.longitude * 1e5);
    encoded += encodeCoordinate(latitude - previousLatitude);
    encoded += encodeCoordinate(longitude - previousLongitude);
    previousLatitude = latitude;
    previousLongitude = longitude;
  }
  return encoded;
}

function encodeCoordinate(delta: number): string {
  let value = delta < 0 ? ~(delta << 1) : delta << 1;
  let encoded = "";
  while (value >= 0x20) {
    encoded += String.fromCharCode((0x20 | (value & 0x1f)) + 63);
    value >>= 5;
  }
  return encoded + String.fromCharCode(value + 63);
}

function decodeCoordinate(value: string, startIndex: number): {
  value: number;
  nextIndex: number;
} {
  let index = startIndex;
  let shift = 0;
  let result = 0;
  let byte = 0;
  do {
    if (index >= value.length) throw new Error("Invalid encoded polyline");
    byte = value.charCodeAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  return {
    value: (result & 1) !== 0 ? ~(result >> 1) : result >> 1,
    nextIndex: index,
  };
}
