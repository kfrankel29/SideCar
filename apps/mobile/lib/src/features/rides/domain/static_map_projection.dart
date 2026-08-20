import 'dart:math' as math;

class RideMapCoordinate {
  const RideMapCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

RideMapCoordinate coordinateForStaticMapTap({
  required double tapX,
  required double tapY,
  required double viewWidth,
  required double viewHeight,
  required double mapWidth,
  required double mapHeight,
  required double centerLatitude,
  required double centerLongitude,
  required int zoom,
}) {
  if (viewWidth <= 0 || viewHeight <= 0 || mapWidth <= 0 || mapHeight <= 0) {
    return RideMapCoordinate(
      latitude: centerLatitude,
      longitude: centerLongitude,
    );
  }
  final center = _project(centerLatitude, centerLongitude);
  final worldSize = 256.0 * math.pow(2, zoom).toDouble();
  final mapX = (tapX / viewWidth - 0.5) * mapWidth;
  final mapY = (tapY / viewHeight - 0.5) * mapHeight;
  return _unproject(center.$1 + mapX / worldSize, center.$2 + mapY / worldSize);
}

(double, double) _project(double latitude, double longitude) {
  final safeLatitude = latitude.clamp(-85.0, 85.0);
  final sinLatitude = math.sin(safeLatitude * math.pi / 180);
  return (
    (longitude + 180) / 360,
    0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi),
  );
}

RideMapCoordinate _unproject(double x, double y) {
  final longitude = ((x * 360 - 180 + 540) % 360) - 180;
  final mercator = math.pi * (1 - 2 * y);
  final sinh = (math.exp(mercator) - math.exp(-mercator)) / 2;
  final latitude = math.atan(sinh) * 180 / math.pi;
  return RideMapCoordinate(latitude: latitude, longitude: longitude);
}
