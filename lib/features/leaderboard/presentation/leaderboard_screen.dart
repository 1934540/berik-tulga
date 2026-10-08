import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/components.dart';
import '../../auth/data/account_controller.dart';
import '../data/ranking_provider.dart';
import '../domain/ranking_entry.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String period = 'week', metric = 'area';
  bool teams = false;
  String score(BuildContext context, double n) => switch (metric) {
    'distance' => '${n.toStringAsFixed(1)} ${context.t('km')}',
    'area' => '${grouped(n)} м²',
    'xp' => '${grouped(n)} XP',
    _ => grouped(n),
  };
  @override
  Widget build(BuildContext context) {
    if (AppConfig.offlineOnly && ref.watch(accountProvider).local) {
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          PageHeading(context.t('ranking'), context.t('city')),
          EmptyState(
            context.t('offlineSocial'),
            icon: Icons.emoji_events_outlined,
          ),
        ],
      );
    }
    final filter = (period: period, metric: metric, teams: teams);
    final data = ref.watch(rankingProvider(filter));
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        PageHeading(
          context.t('ranking'),
          context.t('rankingBody'),
          trailing: const Icon(
            Icons.emoji_events_outlined,
            color: AppColors.flame,
            size: 32,
          ),
        ),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(context.t('players'))),
            ButtonSegment(value: true, label: Text(context.t('teams'))),
          ],
          selected: {teams},
          onSelectionChanged: (v) => setState(() => teams = v.first),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in ['today', 'week', 'month'])
              ChoiceChip(
                label: Text(context.t(p)),
                selected: period == p,
                onSelected: (_) => setState(() => period = p),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in ['area', 'steps', 'distance', 'xp'])
              ChoiceChip(
                label: Text(m == 'xp' ? 'XP' : context.t(m)),
                selected: metric == m,
                onSelected: (_) => setState(() => metric = m),
                selectedColor: AppColors.flame.withValues(alpha: .2),
              ),
          ],
        ),
        const SizedBox(height: 24),
        data.when(
          data: (rows) {
            if (rows.isEmpty) {
              return EmptyState(
                context.t('noRanking'),
                icon: Icons.emoji_events_outlined,
              );
            }
            return Column(
              children: [
                SurfaceCard(
                  color: const Color(0xFF211713),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 50,
                        color: AppColors.flame,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        rows.first.name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        score(context, rows.first.score),
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: AppColors.flame,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Tag('#1 · ${context.t(period)}', color: AppColors.muted),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RankingRow(
                      entry: rows[i],
                      place: i + 1,
                      score: score(context, rows[i].score),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => EmptyState(
            context.t('loadError'),
            action: TextButton(
              onPressed: () => ref.invalidate(rankingProvider(filter)),
              child: Text(context.t('retry')),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.entry,
    required this.place,
    required this.score,
  });
  final RankingEntry entry;
  final int place;
  final String score;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(16),
    color: entry.self ? const Color(0xFF211713) : null,
    child: Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            '$place',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        CircleAvatar(
          radius: 18,
          backgroundColor: Color(entry.color).withValues(alpha: .15),
          child: Text(
            entry.name.substring(0, 1),
            style: TextStyle(
              color: Color(entry.color),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (entry.self)
                Text(
                  context.t('you'),
                  style: const TextStyle(fontSize: 11, color: AppColors.flame),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          score,
          style: TextStyle(
            fontSize: 12,
            color: entry.self ? AppColors.flame : AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
