/// Values come from `env.json` via `--dart-define-from-file=env.json`.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const tomtomKey = String.fromEnvironment('TOMTOM_API_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const tomtomTiles =
      'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$tomtomKey';
}
