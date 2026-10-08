import '../../../core/config/app_config.dart';
import '../domain/activity.dart';

List<RoutePoint> demoRoute(DateTime start) {
  const corners = [
    (44.8491, 65.4804),
    (44.8506, 65.4812),
    (44.8515, 65.4854),
    (44.8496, 65.4865),
    (44.8474, 65.4855),
    (44.8471, 65.4826),
    (44.8491, 65.4804),
  ];
  final result = <RoutePoint>[];
  for (var i = 0; i < corners.length - 1; i++) {
    for (var j = 0; j < 12; j++) {
      final t = j / 12;
      result.add(
        RoutePoint(
          latitude: corners[i].$1 + (corners[i + 1].$1 - corners[i].$1) * t,
          longitude: corners[i].$2 + (corners[i + 1].$2 - corners[i].$2) * t,
          timestamp: start.add(Duration(seconds: result.length * 20)),
          accuracy: 5,
          speed: 1.3,
          segmentStart: result.isEmpty,
        ),
      );
    }
  }
  return result;
}

List<Activity> demoHistory() {
  final today = DateTime.now();
  return List.generate(5, (i) {
    final start = DateTime(
      today.year,
      today.month,
      today.day - i,
      6,
      14 + i * 3,
    );
    return Activity(
      id: 'demo-history-$i',
      userId: 'demo',
      startedAt: start,
      endedAt: start.add(Duration(minutes: 32 + i * 2)),
      points: demoRoute(start),
      distance: 3100 + i * 220,
      steps: 4283 + i * 310,
      demo: true,
      healthAvailable: true,
    );
  });
}

RoutePoint get demoLocation => RoutePoint(
  latitude: AppConfig.cityLatitude,
  longitude: AppConfig.cityLongitude,
  timestamp: DateTime.now(),
);
