import 'package:berik_tulga/features/activity/domain/activity.dart';
import 'package:berik_tulga/features/map/domain/route_geojson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RoutePoint point(double lng, {bool split = false, bool accepted = true}) =>
      RoutePoint(
        latitude: 44.85,
        longitude: lng,
        timestamp: DateTime.utc(2026),
        accepted: accepted,
        segmentStart: split,
      );

  test('GeoJSON preserves longitude order and disconnected GPS segments', () {
    final result = routeGeoJson([
      point(65.48, split: true),
      point(65.481),
      point(66, accepted: false),
      point(65.482, split: true),
      point(65.483),
    ]);
    final features = result['features'] as List;
    expect(features, hasLength(2));
    expect(features[0]['geometry']['coordinates'], [
      [65.48, 44.85],
      [65.481, 44.85],
    ]);
    expect(features[1]['geometry']['coordinates'], [
      [65.482, 44.85],
      [65.483, 44.85],
    ]);
  });

  test('a singleton route draws only markers and skips rejected starts', () {
    final start = point(65.48);
    expect(routeGeoJson([start])['features'], isEmpty);
    final features =
        markerGeoJson([point(66, accepted: false), start], start)['features']
            as List;
    expect(features.first['geometry']['coordinates'], [65.48, 44.85]);
    expect(features.first['properties']['color'], '#B2EE87');
    expect(features.last['properties']['color'], '#FF673B');
  });
}
