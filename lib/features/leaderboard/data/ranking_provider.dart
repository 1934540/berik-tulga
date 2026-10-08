import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/data/account_controller.dart';
import '../domain/ranking_entry.dart';

typedef RankingFilter = ({String period, String metric, bool teams});
final rankingProvider =
    FutureProvider.family<List<RankingEntry>, RankingFilter>((
      ref,
      filter,
    ) async {
      final account = ref.watch(accountProvider);
      if (account.local) return [];
      if (account.demo) {
        final names = filter.teams
            ? ['Берік Тұлға', 'Nomad', 'Qadam', 'Jiger']
            : ['Бағлан', 'Диас', 'Әсел', 'Айдар', 'Алихан', 'Мадина'];
        const colors = [0xFFFF673B, 0xFF9C83F6, 0xFFB2EE87, 0xFF6CB8F4];
        final base = switch (filter.metric) {
          'steps' => 9218.0,
          'distance' => 7.2,
          'xp' => 420.0,
          _ => 42130.0,
        };
        final multiplier = switch (filter.period) {
          'week' => 5.7,
          'month' => 19.0,
          _ => 1.0,
        };
        return List.generate(
          names.length,
          (i) => RankingEntry(
            names[i],
            base * multiplier * (1 - i * .13) * (filter.teams ? 12 : 1),
            colors[i % 4],
            self: filter.teams ? i == 0 : i == 3,
          ),
        );
      }
      final rows = await ref
          .watch(backendProvider)!
          .from('leaderboards')
          .select('display_name,score,color,subject_id')
          .eq('period', filter.period)
          .eq('metric', filter.metric)
          .eq('kind', filter.teams ? 'team' : 'user')
          .order('score', ascending: false)
          .limit(50);
      return rows
          .map(
            (r) => RankingEntry(
              r['display_name'] as String,
              (r['score'] as num).toDouble(),
              r['color'] as int,
              self:
                  r['subject_id'] ==
                  (filter.teams
                      ? account.profile?.teamId
                      : account.profile?.id),
            ),
          )
          .toList();
    });
