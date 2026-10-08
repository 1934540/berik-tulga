import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:berik_tulga/core/config/app_config.dart';
import 'package:berik_tulga/features/activity/domain/activity.dart';
import 'package:berik_tulga/features/activity/data/demo_data.dart';
import 'package:berik_tulga/features/activity/data/local_activity_repository.dart';
import 'package:berik_tulga/features/territory/domain/demo_capture.dart';
import 'package:berik_tulga/features/territory/domain/territory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = GameConfig();
  List<RoutePoint> trail(List<List<double>> vertices) {
    const meters = 6371008.8 * math.pi / 180;
    final longitudeMeters =
        meters * math.cos(AppConfig.cityLatitude * math.pi / 180);
    return [
      for (var i = 0; i < vertices.length; i++)
        RoutePoint(
          latitude: AppConfig.cityLatitude + vertices[i][1] / meters,
          longitude: AppConfig.cityLongitude + vertices[i][0] / longitudeMeters,
          timestamp: DateTime(2026, 10, 8).add(Duration(seconds: i * 30)),
        ),
    ];
  }

  test('the reported short contour closes despite GPS jitter near its start', () {
    // Relative metre offsets preserve the shape without storing a GPS location.
    final points = trail([
      [0.16, 0.02],
      [1.66, 6.04],
      [4.77, 12.46],
      [5.9, 18.57],
      [7.11, 25.98],
      [13.51, 32.82],
      [19.15, 39.9],
      [23.15, 43.58],
      [23.13, 49.79],
      [16.25, 54.55],
      [8.94, 58.07],
      [1.59, 60.23],
      [-6.66, 60.87],
      [-13.48, 62.81],
      [-19.42, 63.99],
      [-24.87, 64.05],
      [-31.02, 64.73],
      [-35.69, 62.14],
      [-35.81, 55.36],
      [-33.14, 49.99],
      [-36.77, 45.07],
      [-41.34, 40.59],
      [-44.28, 35.18],
      [-42.46, 29.51],
      [-39.34, 23.33],
      [-35.36, 17.34],
      [-30.22, 14.83],
      [-25.54, 10.59],
      [-20.9, 7.68],
      [-15.54, 6.19],
      [-9.32, 3.75],
      [-1.76, 2.49],
    ]);
    final loop = closedLoop(points, config);
    expect(loop, isNotNull);
    final walk = Activity(
      id: 'reported',
      userId: 'demo',
      startedAt: points.first.timestamp,
      points: points,
    );
    expect(captureDemo(walk, [], config).area, greaterThan(0));
  });

  test('a 210 m closed walk captures territory', () {
    final points = trail([
      [-26.25, -26.25],
      [26.25, -26.25],
      [26.25, 26.25],
      [-26.25, 26.25],
      [-26.25, -26.25],
    ]);
    final walk = Activity(
      id: 'short',
      userId: 'demo',
      startedAt: points.first.timestamp,
      points: points,
    );
    expect(closedLoop(points, config), isNotNull);
    expect(closedLoop(points, const GameConfig(minimumDistance: 300)), isNull);
    expect(captureDemo(walk, [], config).area, greaterThan(0));
    expect(GameConfig.fromJson({}).minimumDistance, 100);
  });

  test('closure can land in the middle of an earlier segment after a tail', () {
    final points = trail([
      [-120, 0],
      [-60, 0],
      [60, 0],
      [60, 60],
      [0, 60],
      [0, 0],
    ]);
    expect(
      points
          .take(points.length - 1)
          .every((p) => metersBetween(p, points.last) > 25),
      isTrue,
    );
    final loop = closedLoop(points, config)!;
    expect(metersBetween(loop.first, points.last), lessThan(.1));
    expect(loop.length, 4);
  });

  test('crossing the trail between GPS samples trims the overshoot', () {
    final points = trail([
      [-120, 0],
      [-60, 0],
      [60, 0],
      [60, 60],
      [0, 60],
      [0, -35],
    ]);
    final loop = closedLoop(points, config)!;
    expect(loop.first.latitude, closeTo(AppConfig.cityLatitude, 1e-9));
    expect(loop.first.longitude, closeTo(AppConfig.cityLongitude, 1e-9));
    expect(loop.length, 4);
    expect(loop.every((p) => p.latitude >= AppConfig.cityLatitude), isTrue);
    expect(closedLoop(points.sublist(0, points.length - 1), config), isNull);
    final split = [...points];
    split[3] = split[3].validated(accepted: true, segmentStart: true);
    expect(closedLoop(split, config), isNull);
  });

  test(
    'proximity and retracing without enough enclosed area cannot capture',
    () {
      expect(
        closedLoop(
          trail([
            [0, 0],
            [80, 0],
            [80, 8],
            [0, 8],
            [0, 0],
          ]),
          config,
        ),
        isNull,
      );
      expect(
        closedLoop(
          trail([
            [0, 0],
            [60, 0],
            [120, 0],
            [60, 0],
            [0, 0],
          ]),
          config,
        ),
        isNull,
      );
    },
  );
  test('only continuous, closed, simple loops can capture', () {
    final start = DateTime(2026, 10, 7, 6), points = demoRoute(start);
    expect(closedLoop(points, config), isNotNull);
    expect(closedLoop(points.sublist(0, 65), config), isNull);
    final rejected = [...points];
    rejected[35] = rejected[35].validated(accepted: false, segmentStart: false);
    expect(closedLoop(rejected, config), isNull);
    final gap = [...points];
    gap[35] = gap[35].validated(accepted: true, segmentStart: true);
    expect(closedLoop(gap, config), isNull);
    RoutePoint point(double lat, double lng, int i) => RoutePoint(
      latitude: lat,
      longitude: lng,
      timestamp: start.add(Duration(seconds: i * 100)),
    );
    final crossing = [
      point(44.849, 65.481, 0),
      point(44.852, 65.486, 1),
      point(44.852, 65.481, 2),
      point(44.849, 65.486, 3),
      point(44.849, 65.481, 4),
    ];
    expect(closedLoop(crossing, config), isNull);
    final outside = Activity(
      id: 'outside',
      userId: 'demo',
      startedAt: start,
      demo: true,
      points: [
        for (final p in points)
          RoutePoint(
            latitude: p.latitude + 1,
            longitude: p.longitude,
            timestamp: p.timestamp,
          ),
      ],
    );
    expect(captureDemo(outside, [], config).area, 0);
  });
  test(
    'captured cells and area round-trip; each cell is counted only once',
    () {
      final start = DateTime(2026, 10, 7, 6);
      final walk = Activity(
        id: 'walk',
        userId: 'demo',
        startedAt: start,
        demo: true,
        points: demoRoute(start),
      );
      final capture = captureDemo(walk, [], config);
      expect(capture.cells.length, 99);
      expect(capture.area, closeTo(99 * 3 * math.sqrt(3) / 2 * 25 * 25, .01));
      final saved = Activity.fromJson(
        jsonDecode(jsonEncode(walk.copyWith(capture: capture).toJson()))
            as Map<String, dynamic>,
      );
      expect(saved.capture.area, capture.area);
      expect(saved.capture.cells.length, capture.cells.length);
      final again = captureDemo(saved, capture.cells, config);
      expect(again.area, capture.area);
      expect(again.defended, 0);
      expect(again.cells.every((c) => c.hp == 100), isTrue);
    },
  );
  test(
    'online sync accepts server capture and never sends client area',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(),
          requests = <String>[];
      final server = CaptureResult(
        area: 43210,
        status: 'captured',
        processedPoints: 72,
      );
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-public-key',
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('captured_area'), isFalse);
          expect(body.containsKey('capture'), isFalse);
          if (body['p_points'] is List) {
            expect(
              (body['p_points'] as List).every(
                (p) => !(p as Map).containsKey('captured_area'),
              ),
              isTrue,
            );
          }
          return http.Response(
            request.url.path.endsWith('start_activity')
                ? 'null'
                : jsonEncode(server.toJson()),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final start = DateTime(2026, 10, 7, 6),
          repo = LocalActivityRepository(prefs, 'online', client);
      final walk = Activity(
        id: 'walk',
        userId: 'online',
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 24)),
        points: demoRoute(start),
      );
      await repo.save(walk);
      final uploaded = await repo.sync(walk);
      await repo.acknowledge(uploaded);
      expect(uploaded.capture.area, 43210);
      expect(repo.load().single.capture.area, 43210);
      expect(repo.load().single.synced, isTrue);
      expect(requests.length, 3);
    },
  );
  test('stale acknowledgements cannot replace a newer captured area', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance(),
        repo = LocalActivityRepository(prefs, 'online', null);
    final walk = Activity(
      id: 'walk',
      userId: 'online',
      startedAt: DateTime(2026),
      capture: const CaptureResult(area: 2000, processedPoints: 100),
    );
    await repo.save(walk);
    await repo.acknowledge(
      walk.copyWith(
        capture: const CaptureResult(area: 1000, processedPoints: 50),
      ),
    );
    expect(repo.load().single.capture.area, 2000);
  });

  test('a saved completed walk refreshes a recovered server capture without uploading GPS', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final server = const CaptureResult(
      area: 1624,
      status: 'captured',
      processedPoints: 35,
    );
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/get_activity_capture');
        expect(jsonDecode(request.body), {'p_id': 'recovered'});
        return http.Response(
          jsonEncode(server.toJson()),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = LocalActivityRepository(prefs, 'online', client);
    final walk = Activity(
      id: 'recovered',
      userId: 'online',
      startedAt: DateTime(2026),
      endedAt: DateTime(2026, 1, 1, 0, 3),
      synced: true,
      capture: const CaptureResult(processedPoints: 35),
    );
    await repo.save(walk);
    final refreshed = await repo.sync(walk);
    await repo.acknowledge(refreshed);
    expect(repo.load().single.capture.area, 1624);
    expect(repo.load().single.synced, isTrue);
  });
}
