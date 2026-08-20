import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/rides/domain/static_map_projection.dart';

void main() {
  test(
    'the center of the route map resolves to the server viewport center',
    () {
      final coordinate = coordinateForStaticMapTap(
        tapX: 160,
        tapY: 88,
        viewWidth: 320,
        viewHeight: 176,
        mapWidth: 640,
        mapHeight: 352,
        centerLatitude: 34.4133,
        centerLongitude: -119.861,
        zoom: 12,
      );
      expect(coordinate.latitude, closeTo(34.4133, 0.000001));
      expect(coordinate.longitude, closeTo(-119.861, 0.000001));
    },
  );

  test('a tap to the right resolves east of the viewport center', () {
    final coordinate = coordinateForStaticMapTap(
      tapX: 240,
      tapY: 88,
      viewWidth: 320,
      viewHeight: 176,
      mapWidth: 640,
      mapHeight: 352,
      centerLatitude: 34.4133,
      centerLongitude: -119.861,
      zoom: 12,
    );
    expect(coordinate.latitude, closeTo(34.4133, 0.000001));
    expect(coordinate.longitude, greaterThan(-119.861));
  });
}
