/// Environment-based application configuration.
///
/// Centralizes configurable values that may differ between development,
/// staging, and production environments. The [apiBaseUrl] can be overridden
/// at build time using `--dart-define=API_BASE_URL=...`.
///
/// All values are static getters for convenient access throughout the app.
class AppConfig {
  const AppConfig._();

  /// Base URL for the Cloudflare Workers API.
  ///
  /// Defaults to a placeholder. Override by passing
  /// `--dart-define=API_BASE_URL=https://your-domain.workers.dev` during
  /// `flutter build` or `flutter run`.
  static String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue:
            'https://beyondi-trading-api.kuhj7593.workers.dev',
      );

  /// Whether the app should use demo/local authentication.
  ///
  /// When `true`, [DemoAuthRepository] is used (accepts any non-empty
  /// credentials). When `false`, the live Cloudflare Workers API is
  /// used via [WorkersAuthRepository] (requires a running API server).
  ///
  /// Set to `true` for offline development without a live API.
  /// Override via `--dart-define=USE_DEMO_AUTH=true`.
  ///
  /// Default is `false` (live API) for production, but set to `true`
  /// during development if no API server is available.
  static bool get useDemoAuth => const bool.fromEnvironment(
        'USE_DEMO_AUTH',
        defaultValue: false,
      );

  /// Convenience getter that returns `true` when using the live
  /// Workers API (non-demo mode).
  static bool get useLiveApi => !useDemoAuth;
}
