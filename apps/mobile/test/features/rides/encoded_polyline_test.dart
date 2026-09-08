import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/rides/domain/encoded_polyline.dart';

void main() {
  test('decodes the standard Google route polyline for native maps', () {
    final points = decodeEncodedPolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 0.00001));
    expect(points[0].longitude, closeTo(-120.2, 0.00001));
    expect(points[2].latitude, closeTo(43.252, 0.00001));
    expect(points[2].longitude, closeTo(-126.453, 0.00001));
  });

  test('rejects a truncated route polyline', () {
    expect(() => decodeEncodedPolyline('_p~iF'), throwsFormatException);
  });
}
