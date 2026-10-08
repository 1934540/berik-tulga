import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/components.dart';
import '../../activity/presentation/activity_controller.dart';
import '../../auth/data/account_controller.dart';

class MapStats extends ConsumerWidget {
  const MapStats({super.key, required this.onAction});
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider),
        state = ref.watch(activityProvider);
    final active = state.current, now = DateTime.now();
    final daily = state.history.where(
      (a) =>
          a.startedAt.year == now.year &&
          a.startedAt.month == now.month &&
          a.startedAt.day == now.day,
    );
    final steps =
        active?.steps ?? daily.fold<int>(0, (n, a) => n + (a.steps ?? 0));
    final distance =
        active?.distance ?? daily.fold<double>(0, (n, a) => n + a.distance);
    final area =
        active?.capture.area ??
        daily.fold<double>(0, (n, a) => n + a.capture.area);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t(active == null ? 'today' : 'live'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (active != null)
                Text(
                  durationLabel(active.duration),
                  style: const TextStyle(
                    color: AppColors.flame,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Tag(
                  account.demo ? '×2 XP' : 'GPS',
                  color: AppColors.green,
                  icon: Icons.bolt_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: (c.maxWidth - 32) / 3,
                  child: Metric(
                    value: active != null && active.steps == null
                        ? '—'
                        : grouped(steps),
                    label: context.t('steps'),
                  ),
                ),
                SizedBox(
                  width: (c.maxWidth - 32) / 3,
                  child: Metric(
                    value: (distance / 1000).toStringAsFixed(2),
                    label: context.t('km'),
                  ),
                ),
                SizedBox(
                  width: (c.maxWidth - 32) / 3,
                  child: Metric(
                    value: grouped(area),
                    label: '${context.t('area')} · м²',
                    color: AppColors.flame,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (active != null && active.capture.cells.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '${context.t(active.capture.area > 0
                      ? 'territoryCaptured'
                      : active.capture.defended > 0
                      ? 'territoryDefended'
                      : 'territoryAttacked')} · '
                  '${active.capture.cells.length} ${context.t('cells')}',
                  style: const TextStyle(
                    color: AppColors.flame,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          PrimaryAction(
            title: context.t(active == null ? 'start' : 'finish'),
            subtitle: context.t(active == null ? 'startHint' : 'finishHint'),
            active: active != null,
            busy: state.busy,
            onPressed: onAction,
          ),
          if (account.demo && active == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(accountProvider.notifier).enterLocal(),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(context.t('localWalk')),
                ),
              ),
            ),
          if (state.recovered || state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.t(state.recovered ? 'recover' : state.error!),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
