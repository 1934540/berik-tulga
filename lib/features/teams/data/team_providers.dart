import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/data/account_controller.dart';
import '../domain/team.dart';
import '../../activity/presentation/activity_controller.dart';

final teamSummaryProvider = FutureProvider<TeamSummary>((ref) async {
  final account = ref.watch(accountProvider);
  if (account.demo) {
    return TeamSummary(
      name: 'Берік Тұлға',
      members: 245,
      area: ref
          .watch(activityProvider)
          .territoryCells
          .fold<double>(0, (n, c) => n + c.area),
      steps: 3248291,
      distance: 2358000,
    );
  }
  final data = await ref.watch(backendProvider)!.rpc('my_team_summary');
  return TeamSummary.fromJson(
    Map<String, dynamic>.from((data as List).first as Map),
  );
});
final teamMembersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final account = ref.watch(accountProvider);
  if (account.demo) {
    return [
      {'full_name': 'Бағлан', 'username': 'baglan', 'score': 42130},
      {'full_name': 'Айдар', 'username': 'aidar.moves', 'score': 38200},
      {'full_name': 'Диас', 'username': 'dias', 'score': 31400},
      {'full_name': 'Әсел', 'username': 'assel', 'score': 29640},
    ];
  }
  final data = await ref.watch(backendProvider)!.rpc('my_team_members');
  return (data as List)
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();
});
