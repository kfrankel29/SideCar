import 'package:sidecar/src/features/rides/domain/ride_models.dart';

List<RideCoordinate> decodeEncodedPolyline(String value) {
  if (value.isEmpty) return const [];
  final points = <RideCoordinate>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  while (index < value.length) {
    final latitudeResult = _decodeComponent(value, index);
    index = latitudeResult.nextIndex;
    latitude += latitudeResult.delta;
    final longitudeResult = _decodeComponent(value, index);
    index = longitudeResult.nextIndex;
    longitude += longitudeResult.delta;
    points.add(
      RideCoordinate(
        latitude: latitude / 100000,
        longitude: longitude / 100000,
      ),
    );
  }
  return points;
}

({int delta, int nextIndex}) _decodeComponent(String value, int startIndex) {
  var result = 0;
  var shift = 0;
  var index = startIndex;
  int byte;
  do {
    if (index >= value.length) {
      throw const FormatException('Invalid encoded polyline.');
    }
    byte = value.codeUnitAt(index++) - 63;
    if (byte < 0 || byte > 63) {
      throw const FormatException('Invalid encoded polyline.');
    }
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  final delta = result.isOdd ? ~(result >> 1) : result >> 1;
  return (delta: delta, nextIndex: index);
}
