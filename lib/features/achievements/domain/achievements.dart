import '../../activity/domain/activity.dart';

int activityStreak(List<Activity> activities, DateTime now) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final dates = activities
      .where((a) => !a.active && a.distance >= 300)
      .map((a) => day(a.startedAt))
      .toSet();
  var cursor = day(now);
  if (!dates.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (dates.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
