import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/providers.dart';
import '../../auth/data/account_controller.dart';
import '../../territory/domain/demo_capture.dart';
import '../../territory/domain/territory.dart';
import '../../teams/data/team_providers.dart';
import '../data/demo_data.dart';
import '../data/local_activity_repository.dart';
import '../data/tracking_services.dart';
import '../domain/activity.dart';

class ActivityState {
  const ActivityState({
    this.current,
    this.history = const [],
    this.busy = false,
    this.recovered = false,
    this.error,
    this.position,
    this.tick = 0,
  });
  final Activity? current;
  final List<Activity> history;
  final bool busy, recovered;
  final String? error;
  final RoutePoint? position;
  final int tick;
  List<TerritoryCell> get territoryCells => {
    for (final a in history.reversed)
      for (final c in a.capture.cells) c.id: c,
    if (current != null)
      for (final c in current!.capture.cells) c.id: c,
  }.values.toList();
  ActivityState copy({
    Activity? current,
    List<Activity>? history,
    bool? busy,
    bool? recovered,
    String? error,
    RoutePoint? position,
    bool clearCurrent = false,
  }) => ActivityState(
    current: clearCurrent ? null : current ?? this.current,
    history: history ?? this.history,
    busy: busy ?? this.busy,
    recovered: recovered ?? this.recovered,
    error: error,
    position: position ?? this.position,
    tick: tick + 1,
  );
}

final activityProvider = NotifierProvider<ActivityController, ActivityState>(
  ActivityController.new,
);

class ActivityController extends Notifier<ActivityState> {
  LocationService get _location => ref.read(locationServiceProvider);
  StepsService get _steps => ref.read(stepsServiceProvider);
  StreamSubscription<RoutePoint>? _stream;
  StreamSubscription<int>? _stepStream;
  Timer? _timer;
  late LocalActivityRepository _repository;
  bool _syncing = false;
  @override
  ActivityState build() {
    final identity = ref.watch(
      accountProvider.select(
        (s) => (id: s.profile?.id ?? 'anonymous', demo: s.demo, local: s.local),
      ),
    );
    final user = identity.id;
    _repository = LocalActivityRepository(
      ref.read(preferencesProvider),
      user,
      identity.demo || identity.local ? null : ref.read(backendProvider),
    );
    ref.onDispose(() {
      _stream?.cancel();
      _stepStream?.cancel();
      _timer?.cancel();
    });
    final stored = _repository.load();
    final active = stored.where((a) => a.active).firstOrNull;
    return ActivityState(
      current: active,
      recovered: active != null,
      history: stored.where((a) => !a.active).toList().isNotEmpty
          ? stored.where((a) => !a.active).toList()
          : identity.demo
          ? demoHistory()
          : [],
      position: identity.demo ? demoLocation : null,
    );
  }

  Future<void> locate() async {
    if (ref.read(accountProvider).demo) {
      state = state.copy(position: demoLocation);
      return;
    }
    try {
      state = state.copy(position: await _location.current());
    } catch (_) {
      state = state.copy(error: 'locationDenied');
    }
  }

  Future<void> start({
    required String notificationTitle,
    required String notificationBody,
  }) async {
    if (state.busy || state.current != null) return;
    state = state.copy(busy: true);
    final demo = ref.read(accountProvider).demo;
    try {
      if (!demo) await _location.requestTracking();
      final stepsAllowed = demo || await _steps.request();
      final activity = Activity(
        id: const Uuid().v4(),
        userId: ref.read(accountProvider.notifier).userId,
        startedAt: DateTime.now(),
        demo: demo,
        healthAvailable: demo,
        steps: demo ? 0 : null,
        synced: ref.read(accountProvider).local,
      );
      await _repository.save(activity);
      state = state.copy(
        current: activity,
        busy: false,
        error: stepsAllowed ? null : 'stepsUnavailable',
      );
      if (!demo) {
        if (stepsAllowed) {
          _stepStream = _steps.track().listen(
            (steps) => _stepCount(activity.id, steps),
            onError: (Object error) {
              if (state.current?.id != activity.id) return;
              state = state.copy(
                current: state.current!.copyWith(healthAvailable: false),
                error: 'stepsUnavailable',
              );
            },
          );
        }
        _stream = _location
            .track(
              notificationTitle: notificationTitle,
              notificationBody: notificationBody,
            )
            .listen(
              _point,
              onError: (Object e) => state = state.copy(error: 'gpsError'),
            );
        unawaited(_firstFix(activity.id));
      }
      final demoPoints = demoRoute(activity.startedAt);
      var index = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (demo && index < demoPoints.length) {
          final p = demoPoints[index++];
          _point(
            RoutePoint(
              latitude: p.latitude,
              longitude: p.longitude,
              timestamp: activity.startedAt.add(Duration(seconds: index * 20)),
              accuracy: 5,
              speed: 1.3,
            ),
          );
          state = state.copy(
            current: state.current?.copyWith(steps: index * 26),
          );
        }
        state = state.copy(error: state.error);
        if (timer.tick % 30 == 0) unawaited(sync());
      });
    } catch (_) {
      state = state.copy(busy: false, error: 'locationDenied');
    }
  }

  Future<void> _firstFix(String id) async {
    try {
      final point = await _location.current();
      final active = state.current;
      // A delayed fix must not resurrect a finished walk or duplicate the stream.
      if (active?.id == id &&
          active!.points.isEmpty &&
          !point.timestamp.isBefore(active.startedAt)) {
        _point(point);
      }
    } catch (_) {
      // The continuous stream remains active while GPS acquires a fix.
    }
  }

  void _point(RoutePoint raw) {
    final current = state.current;
    if (current == null || state.busy) return;
    final config =
        ref.read(gameConfigProvider).asData?.value ?? const GameConfig();
    final p = RouteValidator(config).validate(raw, current.points.lastOrNull);
    final previous = current.points.lastOrNull;
    final distance =
        current.distance +
        (p.accepted && !p.segmentStart && previous != null
            ? metersBetween(previous, p)
            : 0);
    var next = current.copyWith(
      points: [...current.points, p],
      distance: distance,
    );
    if (current.demo) {
      next = next.copyWith(
        capture: captureDemo(next, state.territoryCells, config),
      );
    }
    state = state.copy(
      current: next,
      position: p.accepted ? p : null,
      error: state.error,
    );
    unawaited(
      _repository
          .save(next)
          .then((_) {
            if (!next.demo && closedLoop(next.points, config) != null) {
              unawaited(sync());
            }
          })
          .catchError((Object _) {
            state = state.copy(error: 'saveError');
          }),
    );
  }

  void _stepCount(String id, int steps) {
    final current = state.current;
    if (current?.id != id || steps < 0) return;
    if (current!.steps != null &&
        (steps < current.steps! ||
            (steps == current.steps && current.healthAvailable))) {
      return;
    }
    final next = current.copyWith(steps: steps, healthAvailable: true);
    state = state.copy(
      current: next,
      error: state.error == 'stepsUnavailable' ? null : state.error,
    );
    // Also checkpoint when walking indoors without any new GPS fixes.
    unawaited(
      _repository.save(next).catchError((Object _) {
        if (state.current?.id == id) state = state.copy(error: 'saveError');
      }),
    );
  }

  Future<Activity?> finish() async {
    if (state.current == null || state.busy) return null;
    final finishedAt = DateTime.now();
    state = state.copy(busy: true);
    _timer?.cancel();
    await _stepStream?.cancel();
    _stepStream = null;
    await _stream?.cancel();
    _stream = null;
    final current = state.current!;
    // Demo points advance at an accelerated pace; preserve their simulated time.
    final end = current.demo && current.points.isNotEmpty
        ? current.points.last.timestamp
        : finishedAt;
    final result = current.copyWith(endedAt: end);
    try {
      await _repository.save(result);
    } catch (_) {
      state = state.copy(busy: false, error: 'saveError');
      return null;
    }
    state = state.copy(
      clearCurrent: true,
      busy: false,
      recovered: false,
      history: [result, ...state.history.where((a) => a.id != result.id)],
    );
    unawaited(sync());
    return result;
  }

  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      var uploadedAny = false;
      final stored = _repository.load();
      for (final a in stored.where((a) => !a.synced && !a.demo)) {
        final uploaded = await _repository.sync(a);
        uploadedAny = uploadedAny || uploaded.capture.cells.isNotEmpty;
        // Merge acknowledgements into the latest checkpoint, never stale GPS data.
        final next = await _repository.acknowledge(uploaded);
        if (state.current?.id == next.id) {
          state = state.copy(
            current: state.current!.copyWith(
              syncedPoints: next.syncedPoints,
              capture: next.capture,
            ),
          );
        }
      }
      // Pick up server repairs to recent finished walks without uploading them again.
      for (final a
          in stored
              .where(
                (a) =>
                    a.synced &&
                    !a.demo &&
                    a.capture.status == 'open' &&
                    a.distance >= 100,
              )
              .take(20)) {
        try {
          final refreshed = await _repository.sync(a);
          uploadedAny = uploadedAny || refreshed.capture.cells.isNotEmpty;
          await _repository.acknowledge(refreshed);
        } catch (_) {
          // Retry on resume; failure to refresh never blocks the upload queue.
        }
      }
      final all = _repository.load();
      if (all.isNotEmpty) {
        state = state.copy(history: all.where((a) => !a.active).toList());
      }
      ref.invalidate(teamSummaryProvider);
      if (uploadedAny && !ref.read(accountProvider).local) {
        unawaited(ref.read(accountProvider.notifier).load());
      }
    } catch (_) {
      /* Durable checkpoints remain pending; timer, resume or user retries. */
    } finally {
      _syncing = false;
    }
  }
}
