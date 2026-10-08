import 'dart:async';
import 'dart:convert';

import 'package:berik_tulga/core/services/providers.dart';
import 'package:berik_tulga/features/activity/data/tracking_services.dart';
import 'package:berik_tulga/features/activity/domain/activity.dart';
import 'package:berik_tulga/features/activity/presentation/activity_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuietGps extends LocationService {
  final fixes = StreamController<RoutePoint>.broadcast();
  @override
  Future<void> requestTracking() async {}
  @override
  Future<RoutePoint> current() async => throw StateError('No fix yet');
  @override
  Stream<RoutePoint> track({
    required String notificationTitle,
    required String notificationBody,
  }) => fixes.stream;
}

class AllowedSteps extends StepsService {
  AllowedSteps({this.allowed = true});
  final bool allowed;
  @override
  Future<bool> request() async => allowed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('step_count');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var listens = 0;
  var cancels = 0;

  setUp(() {
    listens = 0;
    cancels = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listen') listens++;
      if (call.method == 'cancel') cancels++;
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> sensor(int cumulative) async {
    await messenger.handlePlatformMessage(
      'step_count',
      codec.encodeSuccessEnvelope(cumulative),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> sensorError() async {
    await messenger.handlePlatformMessage(
      'step_count',
      codec.encodeErrorEnvelope(code: '1', message: 'StepCount not available'),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<({ProviderContainer container, SharedPreferences prefs})> localWalk({
    bool allowed = true,
    bool reset = true,
  }) async {
    if (reset) SharedPreferences.setMockInitialValues({'local_mode': true});
    final prefs = await SharedPreferences.getInstance();
    final gps = QuietGps();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(gps),
        stepsServiceProvider.overrideWithValue(AllowedSteps(allowed: allowed)),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(gps.fixes.close);
    return (container: container, prefs: prefs);
  }

  test(
    'walk count excludes earlier steps and preserves batched increments',
    () {
      final counter = WalkStepCounter();
      expect(counter.update(12000), 0);
      expect(counter.update(12001), 1);
      expect(counter.update(12008), 8);
      expect(counter.update(12008), 8);
      expect(counter.update(12005), 8);
      expect(counter.update(-1), 8);
      expect(counter.update(12010), 10);
      expect(WalkStepCounter().update(12010), 0);
    },
  );

  test(
    'plugin stream counts live steps once and releases the sensor',
    () async {
      final values = <int>[];
      final subscription = StepsService().track().listen(values.add);
      await Future<void>.delayed(Duration.zero);
      await sensor(5000);
      await sensor(5001);
      await sensor(5006);
      await sensor(5006);
      await sensor(5004);
      await sensor(-10);
      expect(values, [0, 1, 6]);
      await subscription.cancel();
      expect(listens, 1);
      expect(cancels, 1);
    },
  );

  test('live steps persist without GPS and each walk starts at zero', () async {
    final walk = await localWalk();
    final container = walk.container;
    final controller = container.read(activityProvider.notifier);
    await controller.start(notificationTitle: 'test', notificationBody: 'test');
    expect(container.read(activityProvider).current!.steps, isNull);
    await sensor(8000);
    await sensor(8024);
    expect(container.read(activityProvider).current!.steps, 24);
    final stored =
        jsonDecode(walk.prefs.getString('activities_v1_local')!) as List;
    expect(stored.single['steps'], 24);
    expect(stored.single['points'], isEmpty);

    final first = await controller.finish();
    expect(first!.steps, 24);
    expect(cancels, 1);
    await controller.start(notificationTitle: 'test', notificationBody: 'test');
    await sensor(8030); // The six steps between walks are excluded.
    expect(container.read(activityProvider).current!.steps, 0);
    await sensor(8037);
    final second = await controller.finish();
    expect(second!.steps, 7);
    expect(listens, 2);
    expect(cancels, 2);
    expect(container.read(activityProvider).history.map((a) => a.steps), [
      7,
      24,
    ]);
  });

  test(
    'missing sensor leaves steps unavailable and still saves the walk',
    () async {
      final walk = await localWalk();
      final controller = walk.container.read(activityProvider.notifier);
      await controller.start(
        notificationTitle: 'test',
        notificationBody: 'test',
      );
      await sensorError();
      final state = walk.container.read(activityProvider);
      expect(state.error, 'stepsUnavailable');
      expect(state.current!.steps, isNull);
      expect(state.current!.healthAvailable, isFalse);
      expect((await controller.finish())!.steps, isNull);
    },
  );

  test('permission denial never starts a sensor subscription', () async {
    final walk = await localWalk(allowed: false);
    final controller = walk.container.read(activityProvider.notifier);
    await controller.start(notificationTitle: 'test', notificationBody: 'test');
    expect(walk.container.read(activityProvider).error, 'stepsUnavailable');
    expect((await controller.finish())!.steps, isNull);
    expect(listens, 0);
  });

  test(
    'a recovered walk retains its checkpoint without restarting sensors',
    () async {
      final walk = await localWalk();
      await walk.container
          .read(activityProvider.notifier)
          .start(notificationTitle: 'test', notificationBody: 'test');
      await sensor(1000);
      await sensor(1013);
      walk.container.dispose();
      await Future<void>.delayed(Duration.zero);
      final recovered = await localWalk(reset: false);
      expect(recovered.container.read(activityProvider).recovered, isTrue);
      expect(recovered.container.read(activityProvider).current!.steps, 13);
      final result = await recovered.container
          .read(activityProvider.notifier)
          .finish();
      expect(result!.steps, 13);
      expect(listens, 1);
    },
  );
}
