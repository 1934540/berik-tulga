import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Initialized in main'),
);
final backendProvider = Provider<SupabaseClient?>(
  (ref) => AppConfig.hasBackend ? Supabase.instance.client : null,
);
final gameConfigProvider = FutureProvider<GameConfig>((ref) async {
  final client = ref.watch(backendProvider);
  if (client == null) return const GameConfig();
  final row = await client
      .from('app_config')
      .select('value')
      .eq('key', 'game')
      .single();
  return GameConfig.fromJson(Map<String, dynamic>.from(row['value'] as Map));
});
