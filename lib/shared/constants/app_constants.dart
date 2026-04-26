/// Application-wide constants.
///
/// Centralizes magic numbers and string literals to avoid duplication
/// and ensure consistency across the codebase.
class AppConstants {
  const AppConstants._();

  /// Application display name.
  static const String appName = 'Beyondi Trading';

  /// Default animation duration for UI transitions.
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  /// Duration for sidebar slide animation.
  static const Duration sidebarAnimationDuration = Duration(milliseconds: 350);

  // ── Responsive Breakpoints ──

  /// Below this width, the layout switches to mobile mode.
  static const double mobileBreakpoint = 768;

  // ── Sidebar Dimensions ──

  /// Width of the desktop sidebar.
  static const double sidebarWidth = 260;

  /// Width of the collapsed sidebar on desktop.
  static const double sidebarCollapsedWidth = 0;

  // ── Login Card ──

  /// Maximum width of the login card.
  static const double loginCardMaxWidth = 420;

  /// Minimum width of the login card.
  static const double loginCardMinWidth = 320;

  // ── Spacing Scale ──

  static const double spacingXxs = 4;
  static const double spacingXs = 8;
  static const double spacingSm = 12;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;
  static const double spacingXxxl = 64;

  // ── Border Radius ──

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;
}
