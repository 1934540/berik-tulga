import 'activity.dart';

abstract interface class ActivityRepository {
  List<Activity> load();
  Future<void> save(Activity activity);
  Future<Activity> sync(Activity activity);
}
