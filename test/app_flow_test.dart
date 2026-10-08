import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:berik_tulga/app.dart';
import 'package:berik_tulga/core/services/providers.dart';
import 'package:berik_tulga/features/activity/presentation/activity_controller.dart';
import 'package:berik_tulga/features/auth/data/account_controller.dart';
import 'package:berik_tulga/features/map/presentation/map_surface.dart';
import 'package:berik_tulga/features/map/data/offline_map.dart';
import 'package:berik_tulga/core/config/app_config.dart';
import 'package:berik_tulga/features/activity/data/demo_data.dart';
import 'package:berik_tulga/features/activity/domain/activity.dart';
import 'package:berik_tulga/features/activity/presentation/activity_result.dart';
import 'package:berik_tulga/core/utils/format.dart';

Future<void> launch(
  WidgetTester tester, {
  Size size = const Size(375, 812),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({'demo': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        offlineMapProvider.overrideWith(
          (ref) async => const OfflineMap('{}', {}),
        ),
        mapSurfaceProvider.overrideWithValue((options) {
          Future.microtask(options.idle);
          return const ColoredBox(color: Color(0xFF11151A));
        }),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: const BerikTulgaApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fresh install enters offline mode without an account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'locale': 'ru'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          offlineMapProvider.overrideWith(
            (ref) async => const OfflineMap('{}', {}),
          ),
          mapSurfaceProvider.overrideWithValue((options) {
            Future.microtask(options.idle);
            return const ColoredBox(color: Color(0xFF11151A));
          }),
        ],
        child: const BerikTulgaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Присоединиться'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Прогулка офлайн'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Прогулка офлайн'));
    await tester.pumpAndSettle();
    expect(find.text('Офлайн · Карта и маршрут на устройстве'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BerikTulgaApp)),
    );
    expect(container.read(accountProvider).local, isTrue);
    expect(prefs.getBool('local_mode'), isTrue);
    await tester.tap(find.text('Команда').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Эта версия работает офлайн'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('large text and reduced motion keep navigation usable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);
    for (final label in [
      'Карта',
      'Белсенділік',
      'Команда',
      'Рейтинг',
      'Профиль',
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'large text: $label');
    }
  });
  testWidgets('cancelling countdown does not start GPS tracking', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester);
    await tester.tap(find.text('БАСТАУ'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Болдырмау'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BerikTulgaApp)),
    );
    expect(container.read(activityProvider).current, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('all five screens work at small phone and landscape sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(375, 812), const Size(812, 375)]) {
      await launch(tester, size: size);
      for (final label in [
        'Карта',
        'Белсенділік',
        'Команда',
        'Рейтинг',
        'Профиль',
      ]) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label at $size');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets('a demo walk starts, draws a route, finishes and is persisted', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester);
    final element = tester.element(find.byType(BerikTulgaApp));
    final container = ProviderScope.containerOf(element);
    final controller = container.read(activityProvider.notifier);
    await controller.start(notificationTitle: 'test', notificationBody: 'test');
    await tester.pump(const Duration(seconds: 5));
    expect(container.read(activityProvider).current!.points, isNotEmpty);
    final result = await controller.finish();
    await tester.pumpAndSettle();
    expect(result!.steps, greaterThan(0));
    expect(result.distance, greaterThan(0));
    expect(container.read(activityProvider).current, isNull);
    expect(
      container.read(preferencesProvider).getString('activities_v1_demo'),
      contains(result.id),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('editing a profile cannot reset an active activity', (
    tester,
  ) async {
    await launch(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BerikTulgaApp)),
    );
    final controller = container.read(activityProvider.notifier);
    await controller.start(notificationTitle: 'test', notificationBody: 'test');
    final id = container.read(activityProvider).current!.id;
    await container
        .read(accountProvider.notifier)
        .saveProfile(container.read(accountProvider).profile!);
    await tester.pump();
    expect(container.read(activityProvider).current!.id, id);
    await controller.finish();
    await tester.pumpAndSettle();
  });
  testWidgets('a full demo loop captures territory and persists its cells', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BerikTulgaApp)),
    );
    final controller = container.read(activityProvider.notifier);
    expect(find.text('12 400'), findsNothing);
    await controller.start(notificationTitle: 'test', notificationBody: 'test');
    final expected = demoRoute(
      container.read(activityProvider).current!.startedAt,
    );
    for (var i = 0; i < expected.length; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final walk = container.read(activityProvider).current!;
    expect(walk.points.length, expected.length);
    expect(walk.points.every((p) => p.accepted), isTrue);
    expect(walk.segments.length, 1);
    expect(walk.distance, greaterThan(const GameConfig().minimumDistance));
    final closure = metersBetween(walk.points.first, walk.points.last);
    expect(closure, lessThanOrEqualTo(const GameConfig().closureDistance));
    expect(walk.steps, expected.length * 26);
    expect(walk.capture.area, greaterThan(1000));
    expect(walk.capture.cells, isNotEmpty);
    expect(walk.capture.cells.every((c) => c.hp == 100), isTrue);
    expect(find.text('12 400'), findsNothing);
    await tester.tap(find.text('АЯҚТАУ'));
    await tester.pumpAndSettle();
    final result = tester
        .widget<ActivityResult>(find.byType(ActivityResult))
        .activity;
    expect(result.duration.inSeconds, expected.length * 20);
    expect(result.points.length, expected.length);
    await tester.scrollUntilVisible(
      find.text('АУМАҚ АЛЫНДЫ'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('АУМАҚ АЛЫНДЫ'), findsOneWidget);
    final prefs = container.read(preferencesProvider);
    expect(prefs.getString('activities_v1_demo'), contains(result.id));
    expect(result.capture.area, walk.capture.area);
    final returnMap = find.text('Картаға оралу');
    await tester.scrollUntilVisible(
      returnMap,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(returnMap);
    await tester.pumpAndSettle();
    await tester.tap(returnMap);
    await tester.pumpAndSettle();
    expect(find.text(grouped(walk.capture.area)), findsOneWidget);
    debugPrint(
      'DEMO LOOP: ${walk.points.length} accepted points, '
      '${walk.distance.toStringAsFixed(2)} m, '
      '${closure.toStringAsFixed(2)} m closure gap, '
      '${walk.steps} steps; ${walk.capture.area.toStringAsFixed(2)} m² captured '
      'in ${walk.capture.cells.length} cells.',
    );
    expect(tester.takeException(), isNull);
    // Reopen the application with the same checkpoint, then repeat the loop.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // Reusing the same preferences preserves the simulated ownership.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          offlineMapProvider.overrideWith(
            (ref) async => const OfflineMap('{}', {}),
          ),
          mapSurfaceProvider.overrideWithValue((options) {
            Future.microtask(options.idle);
            return const ColoredBox(color: Color(0xFF11151A));
          }),
        ],
        child: const BerikTulgaApp(),
      ),
    );
    await tester.pumpAndSettle();
    final reopened = ProviderScope.containerOf(
      tester.element(find.byType(BerikTulgaApp)),
    );
    expect(
      reopened.read(activityProvider).territoryCells.length,
      walk.capture.cells.length,
    );
    final second = reopened.read(activityProvider.notifier);
    await second.start(notificationTitle: 'test', notificationBody: 'test');
    for (var i = 0; i < expected.length; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final repeat = await second.finish();
    await tester.pumpAndSettle();
    expect(repeat!.capture.area, 0);
    expect(repeat.capture.defended, walk.capture.cells.length);
    expect(repeat.capture.cells.every((c) => c.hp == 120), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
