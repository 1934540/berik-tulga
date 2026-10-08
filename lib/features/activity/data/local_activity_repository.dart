import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity.dart';
import '../domain/activity_repository.dart';
import '../../territory/domain/territory.dart';

/// Serialized writes prevent a slow checkpoint overwriting a newer final result.
/// The durable queue is user-scoped; demo data can never enter the real backend.
class LocalActivityRepository implements ActivityRepository {
  LocalActivityRepository(this.preferences, this.userId, this.client);
  final SharedPreferences preferences;
  final String userId;
  final SupabaseClient? client;
  Future<void> _writes = Future.value();
  String get key => 'activities_v1_$userId';
  @override
  List<Activity> load() {
    final raw = preferences.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((j) => Activity.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<void> save(Activity activity) {
    final write = _writes.then((_) async {
      final all = load();
      final index = all.indexWhere((a) => a.id == activity.id);
      if (index < 0) {
        all.insert(0, activity);
      } else {
        all[index] = activity;
      }
      final ok = await preferences.setString(
        key,
        jsonEncode(all.map((a) => a.toJson()).toList()),
      );
      if (!ok) throw StateError('Local checkpoint failed');
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  /// Merge after outstanding GPS writes, preserving the latest route and end time.
  Future<Activity> acknowledge(Activity uploaded) {
    final result = Completer<Activity>();
    final write = _writes.then((_) async {
      final all = load();
      final index = all.indexWhere((a) => a.id == uploaded.id);
      final latest = all[index];
      final next = latest.copyWith(
        syncedPoints: uploaded.syncedPoints,
        synced:
            uploaded.synced && latest.points.length == uploaded.points.length,
        capture:
            uploaded.capture.processedPoints >= latest.capture.processedPoints
            ? uploaded.capture
            : latest.capture,
      );
      all[index] = next;
      final ok = await preferences.setString(
        key,
        jsonEncode(all.map((a) => a.toJson()).toList()),
      );
      if (!ok) throw StateError('Local acknowledgement failed');
      result.complete(next);
    });
    _writes = write.catchError((Object error, StackTrace stack) {
      result.completeError(error, stack);
    });
    return result.future;
  }

  @override
  Future<Activity> sync(Activity activity) async {
    if (client == null || activity.demo) return activity;
    if (activity.synced) {
      final response = await client!.rpc(
        'get_activity_capture',
        params: {'p_id': activity.id},
      );
      return response is Map
          ? activity.copyWith(
              capture: CaptureResult.fromJson(
                Map<String, dynamic>.from(response),
              ),
            )
          : activity;
    }
    await client!.rpc(
      'start_activity',
      params: {
        'p_id': activity.id,
        'p_started_at': activity.startedAt.toUtc().toIso8601String(),
      },
    );
    var cursor = activity.syncedPoints;
    var capture = activity.capture;
    while (cursor < activity.points.length) {
      final end = math.min(cursor + 100, activity.points.length);
      final response = await client!.rpc(
        'append_activity_points',
        params: {
          'p_id': activity.id,
          'p_offset': cursor,
          'p_points': activity.points
              .sublist(cursor, end)
              .map((p) => p.toJson())
              .toList(),
        },
      );
      if (response is Map) {
        capture = CaptureResult.fromJson(Map<String, dynamic>.from(response));
      }
      cursor = end;
    }
    if (activity.endedAt != null) {
      final response = await client!.rpc(
        'finish_activity',
        params: {
          'p_id': activity.id,
          'p_ended_at': activity.endedAt!.toUtc().toIso8601String(),
          'p_reported_steps': activity.steps,
        },
      );
      if (response is Map) {
        capture = CaptureResult.fromJson(Map<String, dynamic>.from(response));
      }
    }
    return activity.copyWith(
      syncedPoints: cursor,
      synced: activity.endedAt != null,
      capture: capture,
    );
  }
}
