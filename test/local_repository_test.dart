import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:berik_tulga/features/activity/data/local_activity_repository.dart';
import 'package:berik_tulga/features/activity/domain/activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'active checkpoints survive a new repository and stay user scoped',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalActivityRepository(prefs, 'a', null);
      final activity = Activity(
        id: 'walk',
        userId: 'a',
        startedAt: DateTime.now(),
        distance: 300,
        steps: 400,
      );
      await repo.save(activity);
      expect(
        LocalActivityRepository(prefs, 'a', null).load().single.distance,
        300,
      );
      expect(
        LocalActivityRepository(prefs, 'a', null).load().single.active,
        true,
      );
      expect(LocalActivityRepository(prefs, 'b', null).load(), isEmpty);
    },
  );
  test('queued checkpoints and an upload acknowledgement preserve a later final route', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalActivityRepository(prefs, 'a', null),
        start = DateTime.now();
    final old = Activity(
      id: 'walk',
      userId: 'a',
      startedAt: start,
      points: [RoutePoint(latitude: 44.8, longitude: 65.4, timestamp: start)],
    );
    final latest = old.copyWith(
      points: [
        ...old.points,
        RoutePoint(
          latitude: 44.81,
          longitude: 65.4,
          timestamp: start.add(const Duration(seconds: 10)),
        ),
      ],
      endedAt: start.add(const Duration(seconds: 20)),
      distance: 1200,
    );
    final saving = repo.save(old);
    final finishing = repo.save(latest);
    final acknowledgement = repo.acknowledge(old.copyWith(syncedPoints: 1));
    await Future.wait([saving, finishing, acknowledgement]);
    final restored = repo.load().single;
    expect(restored.points.length, 2);
    expect(restored.active, false);
    expect(restored.distance, 1200);
    expect(restored.syncedPoints, 1);
    expect(restored.synced, false);
  });
  test(
    'an offline final activity stays pending and sync does not discard it',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalActivityRepository(prefs, 'a', null);
      final activity = Activity(
        id: 'walk',
        userId: 'a',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
      );
      await repo.save(activity);
      expect((await repo.sync(activity)).synced, false);
      expect(repo.load().single.id, 'walk');
    },
  );
}
