import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/components.dart';
import '../../auth/data/account_controller.dart';

class JoinTeamScreen extends ConsumerStatefulWidget {
  const JoinTeamScreen({super.key});
  @override
  ConsumerState<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends ConsumerState<JoinTeamScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 60),
          const Center(child: BrandMark(size: 100)),
          const SizedBox(height: 40),
          Text(
            context.t('joinTitle'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 20),
          Text(
            context.t('joinBody'),
            style: const TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 32),
          SurfaceCard(
            child: Row(
              children: [
                const BrandMark(size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Берік Тұлға',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.t('city'),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await ref.read(accountProvider.notifier).joinTeam();
                    } catch (_) {
                      if (context.mounted) showNotice(context, 'loadError');
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(context.t('join')),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => ref.read(accountProvider.notifier).signOut(),
            child: Text(context.t('signOut')),
          ),
        ],
      ),
    ),
  );
}
