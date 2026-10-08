import '../../activity/domain/activity.dart';

Map<String, dynamic> featureCollection(List<Map<String, dynamic>> features) => {
  'type': 'FeatureCollection',
  'features': features,
};

/// One feature per continuous segment: never join rejected GPS fixes or gaps.
Map<String, dynamic> routeGeoJson(List<RoutePoint> points) {
  final segments = <List<RoutePoint>>[];
  for (final point in points) {
    if (!point.accepted) continue;
    if (point.segmentStart || segments.isEmpty) segments.add([]);
    segments.last.add(point);
  }
  return featureCollection([
    for (final segment in segments.where((s) => s.length > 1))
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final point in segment) [point.longitude, point.latitude],
          ],
        },
      },
  ]);
}

Map<String, dynamic> markerGeoJson(
  List<RoutePoint> points,
  RoutePoint? position,
) {
  final first = points.where((p) => p.accepted).firstOrNull;
  Map<String, dynamic> marker(RoutePoint point, String color) => {
    'type': 'Feature',
    'properties': {'color': color},
    'geometry': {
      'type': 'Point',
      'coordinates': [point.longitude, point.latitude],
    },
  };
  return featureCollection([
    if (first != null) marker(first, '#B2EE87'),
    if (position != null) marker(position, '#FF673B'),
  ]);
}
