import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/components.dart';
import '../../achievements/domain/achievements.dart';
import '../../activity/presentation/activity_controller.dart';
import '../../auth/data/account_controller.dart';
import 'profile_form.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider),
        activity = ref.watch(activityProvider),
        profile = account.profile!;
    final steps = activity.history.fold<int>(0, (v, a) => v + (a.steps ?? 0));
    final distance = activity.history.fold<double>(0, (v, a) => v + a.distance);
    final streak = account.demo
        ? 12
        : activityStreak(activity.history, DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        PageHeading(
          context.t('profile'),
          context.t('city'),
          trailing: IconButton(
            tooltip: context.t('editProfile'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ProfileForm(edit: true),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
        SurfaceCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.flame.withValues(alpha: .15),
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        profile.name.substring(0, 1),
                        style: const TextStyle(
                          fontSize: 32,
                          color: AppColors.flame,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                profile.name,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '@${profile.username}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              const Tag(
                'Берік Тұлға',
                icon: Icons.local_fire_department_outlined,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 20,
                runSpacing: 8,
                children: [
                  Text(
                    '${context.t('level')} ${account.demo ? 4 : 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    account.demo ? '1 840 / 2 500 XP' : '0 XP',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: account.demo ? 0.736 : 0,
                  minHeight: 6,
                  backgroundColor: AppColors.raised,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                color: AppColors.flame,
                size: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('streak'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$streak ${context.t('days')}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.trending_up_rounded, color: AppColors.green),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Wrap(
            spacing: 28,
            runSpacing: 24,
            children: [
              Metric(
                value: grouped(steps),
                label: context.t('totalSteps'),
                icon: Icons.directions_walk_rounded,
              ),
              Metric(
                value:
                    '${(distance / 1000).toStringAsFixed(1)} ${context.t('km')}',
                label: context.t('distance'),
                icon: Icons.route_outlined,
              ),
              Metric(
                value:
                    '${grouped(account.demo || account.local ? activity.history.fold<double>(0, (n, a) => n + a.capture.area) : profile.territoryArea)} м²',
                label: context.t('captured'),
                color: AppColors.flame,
              ),
              Metric(
                value: '${activity.history.length}',
                label: context.t('activity'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          context.t('achievements'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in [
              (
                'firstWalk',
                Icons.directions_walk_rounded,
                activity.history.isNotEmpty,
              ),
              ('first5k', Icons.route_outlined, distance >= 5000),
              ('sevenDays', Icons.local_fire_department_outlined, streak >= 7),
              ('firstCapture', Icons.hexagon_outlined, account.demo),
            ])
              SizedBox(
                width: 145,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        entry.$2,
                        size: 30,
                        color: entry.$3 ? AppColors.flame : AppColors.muted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.t(entry.$1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.$3 ? AppColors.text : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        entry.$3
                            ? Icons.check_circle_outline_rounded
                            : Icons.lock_outline_rounded,
                        size: 14,
                        color: entry.$3 ? AppColors.green : AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('language'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final lang in [
                    ('kk', 'Қазақша'),
                    ('ru', 'Русский'),
                    ('en', 'English'),
                  ])
                    ChoiceChip(
                      label: Text(lang.$2),
                      selected: ref.watch(localeProvider) == lang.$1,
                      onSelected: (_) =>
                          ref.read(localeProvider.notifier).set(lang.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            if (activity.current != null) {
              showNotice(context, 'activeSignOut');
              return;
            }
            await ref.read(accountProvider.notifier).signOut();
          },
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text(context.t('signOut')),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
