import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/strings.dart';
import 'core/theme/app_theme.dart';
import 'features/activity/presentation/activity_controller.dart';
import 'features/activity/presentation/activity_screen.dart';
import 'features/auth/data/account_controller.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/leaderboard/presentation/leaderboard_screen.dart';
import 'features/map/presentation/map_screen.dart';
import 'features/profile/presentation/profile_form.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/profile/presentation/privacy_screen.dart';
import 'features/teams/presentation/join_team_screen.dart';
import 'features/teams/presentation/team_screen.dart';
import 'shared/widgets/components.dart';

class BerikTulgaApp extends ConsumerWidget {
  const BerikTulgaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Берік Тұлға',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: Locale(ref.watch(localeProvider)),
    supportedLocales: const [Locale('kk'), Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      StringsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => ColoredBox(
      color: AppColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child!,
        ),
      ),
    ),
    routes: {'/privacy': (_) => const PrivacyScreen()},
    home: const _AccountGate(),
  );
}

class _AccountGate extends ConsumerWidget {
  const _AccountGate();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountProvider);
    if (state.loading) {
      return const Scaffold(body: Center(child: BrandMark(size: 64)));
    }
    if (!state.authenticated) return const WelcomeScreen();
    if (state.error) {
      return Scaffold(
        body: Center(
          child: EmptyState(
            context.t('loadError'),
            action: TextButton(
              onPressed: () => ref.read(accountProvider.notifier).load(),
              child: Text(context.t('retry')),
            ),
          ),
        ),
      );
    }
    if (state.profile == null) return const ProfileForm();
    if (!state.local && state.profile!.teamId == null) {
      return const JoinTeamScreen();
    }
    return const _AppShell();
  }
}

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell();
  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell>
    with WidgetsBindingObserver {
  int selected = 0;
  Timer? _syncTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(activityProvider.notifier).sync());
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(ref.read(activityProvider.notifier).sync()),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      unawaited(ref.read(activityProvider.notifier).sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(accountProvider.select((s) => s.demo));
    final local = ref.watch(accountProvider.select((s) => s.local));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (demo) const DemoBanner(),
            if (local)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  context.t('localMode'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: selected,
                children: const [
                  MapScreen(),
                  ActivityScreen(),
                  TeamScreen(),
                  LeaderboardScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
        height: 72,
        destinations: [
          for (final tab in [
            ('map', Icons.map_outlined),
            ('activity', Icons.route_outlined),
            ('team', Icons.groups_outlined),
            ('ranking', Icons.emoji_events_outlined),
            ('profile', Icons.person_outline_rounded),
          ])
            NavigationDestination(
              icon: Icon(tab.$2, size: 22),
              selectedIcon: Icon(tab.$2, size: 22, color: AppColors.flame),
              label: context.t(tab.$1),
            ),
        ],
      ),
    );
  }
}
