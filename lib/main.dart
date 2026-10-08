import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    MapLibreMap.webLibrarySource = MapLibreJsSource.urls(
      scriptUrl: Uri.base.resolve('vendor/maplibre/maplibre-gl.mjs').toString(),
      styleUrl: Uri.base.resolve('vendor/maplibre/maplibre-gl.css').toString(),
    );
  }
  final preferences = await SharedPreferences.getInstance();
  if (AppConfig.hasBackend) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
  }
  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(preferences)],
      child: const BerikTulgaApp(),
    ),
  );
}
