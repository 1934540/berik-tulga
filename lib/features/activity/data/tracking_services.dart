import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
final stepsServiceProvider = Provider<StepsService>((ref) => StepsService());

class LocationService {
  Future<void> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('locationDenied');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('locationDenied');
    }
  }

  Future<void> requestTracking() async {
    await request();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }
  }

  Future<RoutePoint> current() async {
    await request();
    final settings = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 20),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          );
    return convert(
      await Geolocator.getCurrentPosition(locationSettings: settings),
    );
  }

  Stream<RoutePoint> track({
    required String notificationTitle,
    required String notificationBody,
  }) {
    LocationSettings settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        // Adapted from RootStep (MIT): use Android's LocationManager directly,
        // including devices without Google Play Services. See THIRD_PARTY_NOTICES.
        forceLocationManager: true,
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationBody,
          enableWakeLock: true,
        ),
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(convert);
  }

  static RoutePoint convert(Position p) => RoutePoint(
    latitude: p.latitude,
    longitude: p.longitude,
    timestamp: p.timestamp,
    accuracy: p.accuracy,
    speed: p.speed < 0 ? 0 : p.speed,
    altitude: p.altitude,
    mocked: p.isMocked,
  );
}

class StepsService {
  Future<bool> request() async {
    if (kIsWeb) return false;
    try {
      return switch (defaultTargetPlatform) {
        TargetPlatform.android =>
          await Permission.activityRecognition.request().isGranted,
        TargetPlatform.iOS => await Permission.sensors.request().isGranted,
        _ => false,
      };
    } catch (_) {
      return false;
    }
  }

  /// Each subscription owns a walk baseline. The plugin reports a cumulative
  /// count since boot on both platforms, not the steps in the current walk.
  Stream<int> track() {
    final counter = WalkStepCounter();
    return Pedometer.stepCountStream
        .where((event) => event.steps >= 0)
        .map((event) => counter.update(event.steps))
        .distinct();
  }
}

/// Count cumulative sensor deltas, retaining delayed batches and ignoring
/// duplicates or regressive readings. A new walk always gets a fresh baseline.
class WalkStepCounter {
  int? _baseline;
  int _steps = 0;

  int update(int cumulative) {
    if (cumulative < 0) return _steps;
    _baseline ??= cumulative;
    final next = cumulative - _baseline!;
    if (next > _steps) _steps = next;
    return _steps;
  }
}
