import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/components.dart';
import '../../auth/data/account_controller.dart';
import '../data/team_providers.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(accountProvider).local) {
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          PageHeading(context.t('team'), context.t('city')),
          EmptyState(
            context.t(AppConfig.offlineOnly ? 'offlineSocial' : 'localTeam'),
            icon: Icons.groups_outlined,
          ),
        ],
      );
    }
    final summary = ref.watch(teamSummaryProvider),
        members = ref.watch(teamMembersProvider),
        demo = ref.watch(accountProvider).demo;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        PageHeading(context.t('team'), context.t('city')),
        SurfaceCard(
          color: const Color(0xFF211713),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandMark(size: 64),
                  const Spacer(),
                  Tag(context.t('city'), icon: Icons.location_on_outlined),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Берік Тұлға',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.t('teamBody'),
                style: const TextStyle(color: AppColors.muted, height: 1.7),
              ),
              const SizedBox(height: 24),
              summary.when(
                data: (s) => Wrap(
                  spacing: 28,
                  runSpacing: 20,
                  children: [
                    Metric(
                      value: grouped(s.members),
                      label: context.t('members'),
                    ),
                    Metric(
                      value: (s.area / 1000000).toStringAsFixed(1),
                      label: '${context.t('area')} · км²',
                      color: AppColors.flame,
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(context.t('loadError')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        summary.when(
          data: (s) => SurfaceCard(
            child: Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                Metric(
                  value: grouped(s.steps),
                  label: context.t('steps'),
                  icon: Icons.directions_walk_rounded,
                ),
                Metric(
                  value: grouped(s.distance / 1000),
                  label: context.t('km'),
                  icon: Icons.route_outlined,
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(teamSummaryProvider),
            child: Text(context.t('retry')),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          context.t('teamMembers'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        members.when(
          data: (rows) => SurfaceCard(
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 30),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.raised,
                        child: Text(
                          (rows[i]['full_name'] as String).substring(0, 1),
                          style: const TextStyle(
                            color: AppColors.flame,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rows[i]['full_name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (demo)
                        Text(
                          '${grouped(rows[i]['score'] as num)} м²',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.flame,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => EmptyState(
            context.t('loadError'),
            action: TextButton(
              onPressed: () => ref.invalidate(teamMembersProvider),
              child: Text(context.t('retry')),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
