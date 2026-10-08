import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/components.dart';
import '../../map/presentation/route_map.dart';
import '../domain/activity.dart';
import 'activity_controller.dart';
import '../../auth/data/account_controller.dart';
import '../../territory/presentation/capture_summary.dart';

class ActivityResult extends ConsumerWidget {
  const ActivityResult({
    super.key,
    required this.activity,
    this.history = false,
  });
  final Activity activity;
  final bool history;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest =
        ref
            .watch(activityProvider)
            .history
            .where((a) => a.id == activity.id)
            .firstOrNull ??
        activity;
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t(history ? 'walk' : 'wellDone'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (activity.demo) const DemoBanner(),
            const SizedBox(height: 8),
            if (!history) ...[
              const Center(child: BrandMark(size: 68)),
              const SizedBox(height: 24),
              Text(
                context.t('wellDone'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.t('resultBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
            ],
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: RouteMap(
                  points: latest.points,
                  position: latest.points.where((p) => p.accepted).lastOrNull,
                  demo: latest.demo,
                  cells: latest.capture.cells,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SurfaceCard(
              child: Wrap(
                spacing: 28,
                runSpacing: 24,
                children: [
                  Metric(
                    value: activity.steps == null
                        ? '—'
                        : grouped(activity.steps!),
                    label: context.t('steps'),
                  ),
                  Metric(
                    value:
                        '${(activity.distance / 1000).toStringAsFixed(2)} ${context.t('km')}',
                    label: context.t('distance'),
                  ),
                  Metric(
                    value: durationLabel(activity.duration),
                    label: context.t('time'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('privacyNote'),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CaptureSummary(
              capture: latest.capture,
              pending: !latest.demo && !account.local && !latest.synced,
              local: account.local,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t(history ? 'history' : 'returnMap')),
            ),
          ],
        ),
      ),
    );
  }
}
