import 'dart:math' as math;

import '../../../core/config/app_config.dart';
import '../../territory/domain/territory.dart';

class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy = 0,
    this.speed = 0,
    this.altitude = 0,
    this.mocked = false,
    this.accepted = true,
    this.segmentStart = false,
  });
  final double latitude, longitude, accuracy, speed, altitude;
  final DateTime timestamp;
  final bool mocked, accepted, segmentStart;
  RoutePoint validated({required bool accepted, required bool segmentStart}) =>
      RoutePoint(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        accuracy: accuracy,
        speed: speed,
        altitude: altitude,
        mocked: mocked,
        accepted: accepted,
        segmentStart: segmentStart,
      );
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'accuracy': accuracy,
    'speed': speed,
    'altitude': altitude,
    'mocked': mocked,
    'accepted': accepted,
    'segment_start': segmentStart,
  };
  factory RoutePoint.fromJson(Map<String, dynamic> j) => RoutePoint(
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    timestamp: DateTime.parse(j['timestamp'] as String),
    accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
    speed: (j['speed'] as num?)?.toDouble() ?? 0,
    altitude: (j['altitude'] as num?)?.toDouble() ?? 0,
    mocked: j['mocked'] == true,
    accepted: j['accepted'] != false,
    segmentStart: j['segment_start'] == true,
  );
}

double metersBetween(RoutePoint a, RoutePoint b) {
  const r = 6371008.8, radians = math.pi / 180;
  final dLat = (b.latitude - a.latitude) * radians,
      dLng = (b.longitude - a.longitude) * radians;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.latitude * radians) *
          math.cos(b.latitude * radians) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h.toDouble().clamp(0, 1)));
}

class RouteValidator {
  const RouteValidator(this.config);
  final GameConfig config;
  RoutePoint validate(RoutePoint point, RoutePoint? previous) {
    final finite = [
      point.latitude,
      point.longitude,
      point.accuracy,
      point.speed,
    ].every((v) => v.isFinite);
    var valid =
        finite &&
        point.latitude.abs() <= 90 &&
        point.longitude.abs() <= 180 &&
        point.accuracy >= 0 &&
        point.accuracy <= config.maxAccuracy &&
        !point.mocked &&
        point.speed * 3.6 <= config.maxSpeed;
    var split = previous == null || !previous.accepted;
    if (previous != null) {
      final dt =
          point.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
      if (dt <= 0) {
        valid = false;
      } else if (dt > 60) {
        split = true;
      } else if (metersBetween(previous, point) / dt * 3.6 > config.maxSpeed) {
        valid = false;
      }
    }
    return point.validated(accepted: valid, segmentStart: split);
  }
}

class Activity {
  const Activity({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.points = const [],
    this.distance = 0,
    this.steps,
    this.syncedPoints = 0,
    this.synced = false,
    this.demo = false,
    this.healthAvailable = false,
    this.capture = const CaptureResult(),
  });
  final String id, userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<RoutePoint> points;
  final double distance;
  final int? steps;
  final int syncedPoints;
  final bool synced, demo, healthAvailable;
  final CaptureResult capture;
  bool get active => endedAt == null;
  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);
  List<List<RoutePoint>> get segments {
    final result = <List<RoutePoint>>[];
    for (final p in points) {
      if (!p.accepted) continue;
      if (p.segmentStart || result.isEmpty) result.add([]);
      result.last.add(p);
    }
    return result;
  }

  Activity copyWith({
    DateTime? endedAt,
    List<RoutePoint>? points,
    double? distance,
    int? steps,
    int? syncedPoints,
    bool? synced,
    bool? healthAvailable,
    CaptureResult? capture,
  }) => Activity(
    id: id,
    userId: userId,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    points: points ?? this.points,
    distance: distance ?? this.distance,
    steps: steps ?? this.steps,
    syncedPoints: syncedPoints ?? this.syncedPoints,
    synced: synced ?? this.synced,
    demo: demo,
    healthAvailable: healthAvailable ?? this.healthAvailable,
    capture: capture ?? this.capture,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt?.toUtc().toIso8601String(),
    'points': points.map((p) => p.toJson()).toList(),
    'distance': distance,
    'steps': steps,
    'synced_points': syncedPoints,
    'synced': synced,
    'demo': demo,
    'health_available': healthAvailable,
    'capture': capture.toJson(),
  };
  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
    endedAt: j['ended_at'] == null
        ? null
        : DateTime.parse(j['ended_at'] as String).toLocal(),
    points: (j['points'] as List)
        .map((p) => RoutePoint.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
    distance: (j['distance'] as num).toDouble(),
    steps: j['steps'] as int?,
    syncedPoints: j['synced_points'] as int? ?? 0,
    synced: j['synced'] == true,
    demo: j['demo'] == true,
    healthAvailable: j['health_available'] == true,
    capture: j['capture'] is Map
        ? CaptureResult.fromJson(Map<String, dynamic>.from(j['capture'] as Map))
        : const CaptureResult(),
  );
}
