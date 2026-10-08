import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:berik_tulga/app.dart';
import 'package:berik_tulga/core/services/providers.dart';
import 'package:berik_tulga/features/activity/data/tracking_services.dart';
import 'package:berik_tulga/features/activity/domain/activity.dart';
import 'package:berik_tulga/features/activity/presentation/activity_controller.dart';
import 'package:berik_tulga/features/activity/presentation/activity_result.dart';
import 'package:berik_tulga/features/map/data/offline_map.dart';
import 'package:berik_tulga/features/map/presentation/map_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('Offline integration test blocks Dart HTTP');
}

class TestGps extends LocationService {
  final fixes = StreamController<RoutePoint>();
  @override
  Future<void> requestTracking() async {}
  @override
  Future<RoutePoint> current() async =>
      throw StateError('Stream supplies fixes');
  @override
  Stream<RoutePoint> track({
    required String notificationTitle,
    required String notificationBody,
  }) => fixes.stream;
}

class NoSteps extends StepsService {
  @override
  Future<bool> request() async => false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'cold local map and GPS history work without Dart network access',
    (tester) async {
      final oldNetwork = HttpOverrides.current;
      HttpOverrides.global = NoNetwork();
      addTearDown(() => HttpOverrides.global = oldNetwork);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('demo', false);
      await prefs.setBool('local_mode', false);
      await prefs.setString('locale', 'ru');
      await prefs.remove('activities_v1_local');
      // Remove only this test app's map copy to exercise installation from APK assets.
      final support = await getApplicationSupportDirectory();
      final copiedMaps = Directory('${support.path}/offline_maps');
      if (await copiedMaps.exists()) await copiedMaps.delete(recursive: true);
      final gps = TestGps();
      MapLibreMapController? renderedMap;
      final surfaceReady = Completer<void>();
      Future<void> mount() => tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            locationServiceProvider.overrideWithValue(gps),
            stepsServiceProvider.overrideWithValue(NoSteps()),
            mapSurfaceProvider.overrideWithValue(
              (options) => MapLibreMap(
                key: options.key,
                styleString: options.style,
                initialCameraPosition: options.camera,
                myLocationEnabled: false,
                onMapCreated: (map) {
                  renderedMap = map;
                  options.created(map);
                },
                onStyleLoadedCallback: options.styleLoaded,
                onMapIdle: () {
                  options.idle();
                  if (!surfaceReady.isCompleted) surfaceReady.complete();
                },
              ),
            ),
          ],
          child: const BerikTulgaApp(),
        ),
      );
      await mount();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Прогулка офлайн'));
      await tester.tap(find.text('Прогулка офлайн'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 60 && !surfaceReady.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        surfaceReady.isCompleted,
        isTrue,
        reason: 'Bundled map must reach native idle',
      );
      final mapStyle =
          jsonDecode((await renderedMap!.getStyle())!) as Map<String, dynamic>;
      expect(mapStyle['glyphs'], startsWith('file://'));
      expect(mapStyle['sources']['city']['data'], startsWith('file://'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BerikTulgaApp)),
      );
      expect(
        container.read(offlineMapProvider).requireValue.style,
        startsWith(support.path),
      );
      final streets = await renderedMap!.queryRenderedFeaturesInRect(
        const Rect.fromLTWH(0, 0, 520, 1000),
        ['roads', 'buildings'],
        null,
      );
      expect(
        streets,
        isNotEmpty,
        reason: 'Native map must render the bundled geometry',
      );
      final labels = await renderedMap!.queryRenderedFeaturesInRect(
        const Rect.fromLTWH(0, 0, 520, 1000),
        ['road-labels'],
        null,
      );
      expect(
        labels,
        isNotEmpty,
        reason: 'Street names must render from local glyphs',
      );
      final controller = container.read(activityProvider.notifier);
      await controller.start(
        notificationTitle: 'Offline test',
        notificationBody: 'Synthetic fixes',
      );
      final start = container.read(activityProvider).current!.startedAt;
      for (var i = 0; i < 3; i++) {
        gps.fixes.add(
          RoutePoint(
            latitude: 44.8488,
            longitude: 65.4823 + i * .00015,
            timestamp: start.add(Duration(seconds: i * 10)),
            accuracy: 5,
            speed: 1,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      final result = await controller.finish();
      expect(result!.demo, isFalse);
      expect(result.distance, greaterThan(15));
      expect(result.userId, 'local');
      expect(result.steps, isNull);
      await prefs.reload();
      expect(prefs.getString('activities_v1_local'), contains(result.id));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await mount();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Активность').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Утренняя прогулка').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ActivityResult>(find.byType(ActivityResult)).activity.id,
        result.id,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await gps.fixes.close();
    },
  );
}
