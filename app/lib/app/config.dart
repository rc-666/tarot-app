/// Build-time settings, passed with --dart-define (see README). No secrets here except the
/// Supabase anon key, which is public by design (RLS protects the data).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep link the password-reset email opens (also in supabase/config.toml and AndroidManifest).
  static const authRedirect = 'tarotapp://auth-callback';

  /// AdMob banner unit. Defaults to Google's public TEST unit; set the real one for release.
  static const admobBannerUnit = String.fromEnvironment(
    'ADMOB_BANNER_UNIT',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741',
  );

  static const posthogKey = String.fromEnvironment('POSTHOG_KEY');
  static const posthogHost = String.fromEnvironment('POSTHOG_HOST', defaultValue: 'https://us.i.posthog.com');

  /// Landing-page site pages (decision 22 Nov: hosted there).
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://example.com/privacy');

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && !demo;

  /// Demo build (--dart-define=DEMO=true, or no Supabase settings): no backend needed.
  /// Real sky data for ~7 months is bundled in assets/demo/sky.json (made by
  /// supabase/functions/tools/demo_data.ts); the account lives on the phone.
  static bool get demo => const bool.fromEnvironment('DEMO') || supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;
}
