import 'dart:async';

import 'package:berik_tulga/core/services/providers.dart';
import 'package:berik_tulga/features/activity/data/tracking_services.dart';
import 'package:berik_tulga/features/activity/domain/activity.dart';
import 'package:berik_tulga/features/activity/presentation/activity_controller.dart';
import 'package:berik_tulga/features/auth/data/account_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLocation extends LocationService {
  final fixes = StreamController<RoutePoint>();
  final initial = Completer<RoutePoint>();
  bool stopped = false;
  FakeLocation() {
    fixes.onCancel = () {
      stopped = true;
    };
  }
  @override
  Future<void> requestTracking() async {}
  @override
  Future<RoutePoint> current() => initial.future;
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
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'local GPS mode records service fixes without a cloud account',
    () async {
      SharedPreferences.setMockInitialValues({'local_mode': true});
      final prefs = await SharedPreferences.getInstance();
      final location = FakeLocation();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          locationServiceProvider.overrideWithValue(location),
          stepsServiceProvider.overrideWithValue(NoSteps()),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(accountProvider).local, isTrue);
      final controller = container.read(activityProvider.notifier);
      await controller.start(
        notificationTitle: 'test',
        notificationBody: 'test',
      );
      final started = container.read(activityProvider).current!.startedAt;
      location.initial.complete(
        RoutePoint(
          latitude: 44.85,
          longitude: 65.48,
          timestamp: started.add(const Duration(seconds: 1)),
          accuracy: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      location.fixes.add(
        RoutePoint(
          latitude: 44.85,
          longitude: 65.4801,
          timestamp: started.add(const Duration(seconds: 11)),
          accuracy: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(activityProvider).current!.distance,
        inInclusiveRange(7, 9),
      );
      final result = await controller.finish();
      expect(result!.demo, isFalse);
      expect(result.steps, isNull);
      expect(result.userId, 'local');
      expect(result.synced, isTrue);
      expect(location.stopped, isTrue);
      expect(prefs.getString('activities_v1_local'), contains(result.id));
      expect(prefs.getString('activities_v1_demo'), isNull);
      expect(container.read(accountProvider.notifier).client, isNull);
      await location.fixes.close();
    },
  );
}
