/// Inject public credentials with --dart-define-from-file=.env.
/// Supabase service-role credentials must never be included in this app.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const authRedirectUrl = 'beriktulga://auth-callback';
  static const offlineOnly = bool.fromEnvironment(
    'OFFLINE_ONLY',
    defaultValue: true,
  );
  static bool get hasBackend =>
      !offlineOnly && supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  static const cityLatitude = 44.8488;
  static const cityLongitude = 65.4823;
}

class GameConfig {
  const GameConfig({
    this.maxAccuracy = 50,
    this.maxSpeed = 20,
    this.minimumDistance = 100,
    this.closureDistance = 25,
    this.minimumArea = 1000,
    this.privacyRadius = 200,
  });
  final double maxAccuracy,
      maxSpeed,
      minimumDistance,
      closureDistance,
      minimumArea,
      privacyRadius;
  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
    maxAccuracy: (json['max_gps_accuracy'] as num?)?.toDouble() ?? 50,
    maxSpeed: (json['max_capture_speed'] as num?)?.toDouble() ?? 20,
    minimumDistance:
        (json['minimum_route_distance'] as num?)?.toDouble() ?? 100,
    closureDistance: (json['closure_distance'] as num?)?.toDouble() ?? 25,
    minimumArea: (json['minimum_capture_area'] as num?)?.toDouble() ?? 1000,
    privacyRadius: (json['privacy_radius'] as num?)?.toDouble() ?? 200,
  );
}
