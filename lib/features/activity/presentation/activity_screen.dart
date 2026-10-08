import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/components.dart';
import '../../map/presentation/route_map.dart';
import 'activity_controller.dart';
import 'activity_result.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityProvider), active = state.current;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        PageHeading(
          context.t('history'),
          context.t('historySubtitle'),
          trailing: IconButton(
            tooltip: context.t('sync'),
            onPressed: () => ref.read(activityProvider.notifier).sync(),
            icon: const Icon(Icons.sync_rounded),
          ),
        ),
        if (active != null) ...[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(
                  context.t('live'),
                  icon: Icons.radio_button_checked,
                  color: AppColors.green,
                ),
                const SizedBox(height: 18),
                Text(
                  durationLabel(active.duration),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    Metric(
                      value: active.steps == null
                          ? '—'
                          : grouped(active.steps!),
                      label: context.t('steps'),
                    ),
                    Metric(
                      value: (active.distance / 1000).toStringAsFixed(2),
                      label: context.t('km'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RouteMap(
                      points: active.points,
                      position: state.position,
                      demo: active.demo,
                      tracking: !state.recovered,
                      cells: active.capture.cells,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (state.history.isEmpty) EmptyState(context.t('emptyHistory')),
        for (final a in state.history)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityResult(activity: a, history: true),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Tag(
                            '${a.startedAt.day.toString().padLeft(2, '0')}.${a.startedAt.month.toString().padLeft(2, '0')} · ${timeLabel(a.startedAt)}',
                            color: AppColors.muted,
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_outward_rounded,
                            size: 18,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_walk_rounded,
                            color: AppColors.flame,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.t('walk'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          Text(
                            '${a.steps == null ? '—' : grouped(a.steps!)} ${context.t('steps')}',
                          ),
                          Text(
                            '${(a.distance / 1000).toStringAsFixed(2)} ${context.t('km')}',
                          ),
                          Text(durationLabel(a.duration)),
                          if (a.capture.area > 0)
                            Text(
                              '${grouped(a.capture.area)} м²',
                              style: const TextStyle(color: AppColors.flame),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.t(
                          a.demo
                              ? 'demo'
                              : a.synced
                              ? 'saved'
                              : 'pending',
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
