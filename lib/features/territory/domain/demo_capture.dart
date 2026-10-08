import 'dart:math' as math;

import '../../../core/config/app_config.dart';
import '../../activity/domain/activity.dart';
import 'territory.dart';

typedef _XY = ({double x, double y});
const _radius = 25.0;
const _meters = 6371008.8 * math.pi / 180;
final _longitudeMeters =
    _meters * math.cos(AppConfig.cityLatitude * math.pi / 180);
_XY _project(RoutePoint p) => (
  x: (p.longitude - AppConfig.cityLongitude) * _longitudeMeters,
  y: (p.latitude - AppConfig.cityLatitude) * _meters,
);
double _cross(_XY a, _XY b, _XY c) =>
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
bool _on(_XY a, _XY b, _XY p) =>
    _cross(a, b, p).abs() < 1e-7 &&
    p.x >= math.min(a.x, b.x) - 1e-7 &&
    p.x <= math.max(a.x, b.x) + 1e-7 &&
    p.y >= math.min(a.y, b.y) - 1e-7 &&
    p.y <= math.max(a.y, b.y) + 1e-7;
bool _intersects(_XY a, _XY b, _XY c, _XY d) =>
    (_cross(a, b, c) * _cross(a, b, d) < 0 &&
        _cross(c, d, a) * _cross(c, d, b) < 0) ||
    _on(a, b, c) ||
    _on(a, b, d) ||
    _on(c, d, a) ||
    _on(c, d, b);
bool _inside(_XY p, List<_XY> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i], b = polygon[j];
    if (_on(a, b, p)) return true;
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

bool _simple(List<_XY> polygon) {
  for (var i = 0; i < polygon.length; i++) {
    for (var j = i + 1; j < polygon.length; j++) {
      if (j == i + 1 || (i == 0 && j == polygon.length - 1)) continue;
      if (_intersects(
        polygon[i],
        polygon[(i + 1) % polygon.length],
        polygon[j],
        polygon[(j + 1) % polygon.length],
      )) {
        return false;
      }
    }
  }
  return true;
}

/// The client uses this only for demo captures and to request a server check.
/// Online ownership and area always come from the validated server RPC.
List<RoutePoint>? closedLoop(List<RoutePoint> points, GameConfig config) {
  if (points.length < 4 || !points.last.accepted) return null;
  var start = points.length - 1;
  while (start > 0 &&
      !points[start].segmentStart &&
      points[start - 1].accepted) {
    start--;
  }
  final end = points.length - 1;
  final current = _project(points[end]), previous = _project(points[end - 1]);
  for (var i = start; i <= end - 2; i++) {
    final a = _project(points[i]), b = _project(points[i + 1]);
    final dx = b.x - a.x, dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < .01) continue;
    // Closing onto a segment works even when neither GPS sample is nearby.
    final fraction =
        (((current.x - a.x) * dx + (current.y - a.y) * dy) / lengthSquared)
            .clamp(0.0, 1.0);
    var anchor = (x: a.x + dx * fraction, y: a.y + dy * fraction);
    var finish = points[end];
    final moveX = current.x - previous.x, moveY = current.y - previous.y;
    final denominator = dx * moveY - dy * moveX;
    if (denominator.abs() > 1e-7) {
      final offsetX = previous.x - a.x, offsetY = previous.y - a.y;
      final alongOld = (offsetX * moveY - offsetY * moveX) / denominator;
      final alongNew = (offsetX * dy - offsetY * dx) / denominator;
      if (alongOld >= 0 && alongOld <= 1 && alongNew > 0 && alongNew <= 1) {
        anchor = (x: a.x + dx * alongOld, y: a.y + dy * alongOld);
        // Trim an overshoot at the actual crossing, before building the ring.
        finish = _at(anchor, points[end]);
      }
    }
    final first = _at(anchor, points[i]);
    if (metersBetween(first, finish) > config.closureDistance) continue;
    final loop = <RoutePoint>[];
    for (final point in [first, ...points.sublist(i + 1, end), finish]) {
      if (loop.isEmpty || metersBetween(loop.last, point) > .1) loop.add(point);
    }
    var distance = 0.0;
    for (var j = 1; j < loop.length; j++) {
      distance += metersBetween(loop[j - 1], loop[j]);
    }
    if (distance < config.minimumDistance) continue;
    if (loop.length > 1 && metersBetween(loop.first, loop.last) < .1) {
      loop.removeLast();
    }
    if (loop.length < 3) continue;
    final polygon = loop.map(_project).toList();
    if (!_simple(polygon)) continue;
    var area = 0.0;
    for (var j = 0; j < polygon.length; j++) {
      final a = polygon[j], b = polygon[(j + 1) % polygon.length];
      area += a.x * b.y - b.x * a.y;
    }
    if (area.abs() / 2 >= config.minimumArea && area.abs() / 2 <= 2000000) {
      return loop;
    }
  }
  return null;
}

RoutePoint _at(_XY p, RoutePoint source) => RoutePoint(
  latitude: AppConfig.cityLatitude + p.y / _meters,
  longitude: AppConfig.cityLongitude + p.x / _longitudeMeters,
  timestamp: source.timestamp,
);

CaptureResult captureDemo(
  Activity walk,
  Iterable<TerritoryCell> existing,
  GameConfig config,
) {
  final loop = closedLoop(walk.points, config);
  if (loop == null) return walk.capture;
  final polygon = loop.map(_project).toList();
  if (loop.any(
    (p) =>
        p.latitude < 44.72 ||
        p.latitude > 44.98 ||
        p.longitude < 65.34 ||
        p.longitude > 65.70,
  )) {
    return walk.capture;
  }
  final known = {for (final c in existing) c.id: c};
  final processed = {for (final c in walk.capture.cells) c.id: c};
  var area = walk.capture.area, defended = walk.capture.defended;
  final minX = polygon.map((p) => p.x).reduce(math.min),
      maxX = polygon.map((p) => p.x).reduce(math.max),
      minY = polygon.map((p) => p.y).reduce(math.min),
      maxY = polygon.map((p) => p.y).reduce(math.max);
  final height = math.sqrt(3) * _radius;
  for (
    var q = (minX / (1.5 * _radius)).floor() - 1;
    q <= (maxX / (1.5 * _radius)).ceil() + 1;
    q++
  ) {
    for (
      var r = (minY / height - q / 2).floor() - 1;
      r <= (maxY / height - q / 2).ceil() + 1;
      r++
    ) {
      final id = 'demo-25-$q-$r';
      if (processed.containsKey(id)) continue;
      final x = q * 1.5 * _radius, y = height * (r + q / 2);
      final vertices = <_XY>[
        for (var k = 0; k < 6; k++)
          (
            x: x + _radius * math.cos(k * math.pi / 3),
            y: y + _radius * math.sin(k * math.pi / 3),
          ),
      ];
      if (!_inside((x: x, y: y), polygon)) continue;
      const cellArea = 3 * 1.7320508075688772 / 2 * _radius * _radius;
      final old = known[id];
      if (old == null) {
        area += cellArea;
      } else {
        defended++;
      }
      final ring = [
        for (final v in [...vertices, vertices.first])
          [
            AppConfig.cityLongitude + v.x / _longitudeMeters,
            AppConfig.cityLatitude + v.y / _meters,
          ],
      ];
      processed[id] = TerritoryCell(
        id: id,
        ring: ring,
        area: cellArea,
        hp: old == null ? 100 : math.min(300, old.hp + 20),
        ownerTeam: 'demo',
      );
    }
  }
  return CaptureResult(
    area: area,
    cells: processed.values.toList(),
    status: area > 0
        ? 'captured'
        : defended > 0
        ? 'defended'
        : 'no_playable',
    defended: defended,
    processedPoints: walk.points.length,
  );
}
