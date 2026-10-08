import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/providers.dart';
import '../../profile/domain/user_profile.dart';

const defaultTeamId = '00000000-0000-4000-8000-000000000001';

class AccountState {
  const AccountState({
    this.demo = false,
    this.local = false,
    this.authenticated = false,
    this.loading = true,
    this.profile,
    this.error = false,
  });
  final bool demo, local, authenticated, loading, error;
  final UserProfile? profile;
}

final accountProvider = NotifierProvider<AccountController, AccountState>(
  AccountController.new,
);

class AccountController extends Notifier<AccountState> {
  @override
  AccountState build() {
    final prefs = ref.read(preferencesProvider);
    final client = ref.read(backendProvider);
    final subscription = client?.auth.onAuthStateChange.listen(
      (_) => unawaited(load()),
      onError: (Object error) => unawaited(load()),
    );
    ref.onDispose(() => subscription?.cancel());
    if (prefs.getBool('local_mode') ?? false) {
      final saved = prefs.getString('local_profile');
      return AccountState(
        local: true,
        authenticated: true,
        loading: false,
        profile: saved == null
            ? const UserProfile(
                id: 'local',
                name: 'Серуенші',
                username: 'walker',
              )
            : UserProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>),
      );
    }
    if (prefs.getBool('demo') ?? false) {
      final saved = prefs.getString('demo_profile');
      return AccountState(
        demo: true,
        authenticated: true,
        loading: false,
        profile: saved == null
            ? const UserProfile(
                id: 'demo',
                name: 'Айдар',
                username: 'aidar.moves',
                teamId: defaultTeamId,
              )
            : UserProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>),
      );
    }
    Future.microtask(load);
    return AccountState(authenticated: client?.auth.currentUser != null);
  }

  Future<void> load() async {
    if (state.demo || state.local) return;
    final client = ref.read(backendProvider);
    final user = client?.auth.currentUser;
    if (user == null) {
      state = const AccountState(loading: false);
      return;
    }
    try {
      final data = await client!
          .from('users')
          .select()
          .eq('id', user.id)
          .single();
      if (client.auth.currentUser?.id != user.id || state.demo || state.local) {
        return;
      }
      final profile = UserProfile.fromJson(data);
      state = AccountState(
        authenticated: true,
        loading: false,
        profile: profile.name.isEmpty ? null : profile,
      );
    } catch (_) {
      state = const AccountState(
        authenticated: true,
        loading: false,
        error: true,
      );
    }
  }

  Future<void> enterDemo() async {
    await ref.read(preferencesProvider).setBool('local_mode', false);
    await ref.read(preferencesProvider).setBool('demo', true);
    state = const AccountState(
      demo: true,
      authenticated: true,
      loading: false,
      profile: UserProfile(
        id: 'demo',
        name: 'Айдар',
        username: 'aidar.moves',
        teamId: defaultTeamId,
      ),
    );
  }

  Future<void> enterLocal() async {
    final prefs = ref.read(preferencesProvider);
    await prefs.setBool('demo', false);
    await prefs.setBool('local_mode', true);
    final saved = prefs.getString('local_profile');
    state = AccountState(
      local: true,
      authenticated: true,
      loading: false,
      profile: saved == null
          ? const UserProfile(id: 'local', name: 'Серуенші', username: 'walker')
          : UserProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>),
    );
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (state.demo || state.local) {
      await ref
          .read(preferencesProvider)
          .setString(
            state.local ? 'local_profile' : 'demo_profile',
            jsonEncode(profile.toJson()),
          );
    } else {
      await ref
          .read(backendProvider)!
          .from('users')
          .update({
            'full_name': profile.name,
            'username': profile.username,
            'avatar_url': profile.avatarUrl,
            'gender': profile.gender,
            'birth_date': profile.birthDate,
            'city': 'Қызылорда',
          })
          .eq('id', profile.id);
    }
    state = AccountState(
      demo: state.demo,
      local: state.local,
      authenticated: true,
      loading: false,
      profile: profile,
    );
  }

  Future<void> joinTeam() async {
    await ref.read(backendProvider)!.rpc('join_default_team');
    await load();
  }

  Future<void> signOut() async {
    await ref.read(preferencesProvider).setBool('demo', false);
    await ref.read(preferencesProvider).setBool('local_mode', false);
    final deviceOnly = state.demo || state.local;
    state = const AccountState(loading: false);
    if (!deviceOnly) await ref.read(backendProvider)?.auth.signOut();
  }

  String get userId =>
      state.profile?.id ??
      ref.read(backendProvider)?.auth.currentUser?.id ??
      'anonymous';
  SupabaseClient? get client =>
      state.demo || state.local ? null : ref.read(backendProvider);
}
