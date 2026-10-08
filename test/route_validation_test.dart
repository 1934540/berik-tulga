import 'package:flutter_test/flutter_test.dart';
import 'package:berik_tulga/core/config/app_config.dart';
import 'package:berik_tulga/features/activity/domain/activity.dart';
import 'package:berik_tulga/features/achievements/domain/achievements.dart';

void main() {
  final start = DateTime.utc(2026, 10, 4, 1);
  RoutePoint point(
    double lng,
    int seconds, {
    double accuracy = 5,
    bool mocked = false,
  }) => RoutePoint(
    latitude: 44.8488,
    longitude: lng,
    timestamp: start.add(Duration(seconds: seconds)),
    accuracy: accuracy,
    mocked: mocked,
  );
  const validator = RouteValidator(GameConfig());
  test(
    'walking points are accepted and a known metric distance is plausible',
    () {
      final a = validator.validate(point(65.4823, 0), null);
      final b = validator.validate(point(65.4824, 10), a);
      expect(a.segmentStart, true);
      expect(b.accepted, true);
      expect(b.segmentStart, false);
      expect(metersBetween(a, b), inInclusiveRange(7, 9));
    },
  );
  test(
    'teleport and following discontinuity never become a connecting segment',
    () {
      final a = validator.validate(point(65.4823, 0), null);
      final teleport = validator.validate(point(65.50, 5), a);
      final resumed = validator.validate(point(65.5001, 15), teleport);
      expect(teleport.accepted, false);
      expect(resumed.accepted, true);
      expect(resumed.segmentStart, true);
      final activity = Activity(
        id: 'a',
        userId: 'u',
        startedAt: start,
        points: [a, teleport, resumed],
      );
      expect(activity.segments.length, 2);
    },
  );
  test(
    'poor accuracy, mock coordinates and reversed timestamps are rejected',
    () {
      final a = validator.validate(point(65.4823, 10), null);
      expect(
        validator.validate(point(65.4823, 15, accuracy: 51), a).accepted,
        false,
      );
      expect(
        validator.validate(point(65.4823, 15, mocked: true), a).accepted,
        false,
      );
      expect(validator.validate(point(65.4823, 9), a).accepted, false);
    },
  );
  test('a GPS gap creates a separate segment without invented distance', () {
    final a = validator.validate(point(65.4823, 0), null);
    final b = validator.validate(point(65.51, 120), a);
    expect(b.accepted, true);
    expect(b.segmentStart, true);
  });
  test('a missed day resets streak and multiple same-day walks count once', () {
    Activity walk(int day) => Activity(
      id: '$day',
      userId: 'u',
      startedAt: DateTime(2026, 10, day, 6),
      endedAt: DateTime(2026, 10, day, 7),
      distance: 500,
    );
    expect(
      activityStreak([
        walk(2),
        walk(3),
        walk(3),
        walk(4),
      ], DateTime(2026, 10, 4)),
      3,
    );
    expect(activityStreak([walk(1), walk(2)], DateTime(2026, 10, 4)), 0);
    expect(activityStreak([walk(2), walk(3)], DateTime(2026, 10, 4)), 2);
  });
}
