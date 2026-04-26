import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bold, intentional theme following the 5 Pillars of Intentional UI.
///
/// Typography: Poppins (headings) + Inter (body) for distinctive character.
/// Color: Deep navy + amber/gold palette, committed and bold.
/// Depth: Subtle gradients and layered shadows throughout.
class AppTheme {
  const AppTheme._();

  // ── Light Palette ──
  static const Color _primaryLight = Color(0xFF1E3A5F);
  static const Color _onPrimaryLight = Color(0xFFFFFFFF);
  static const Color _primaryContainerLight = Color(0xFFD4E4FF);
  static const Color _onPrimaryContainerLight = Color(0xFF001D36);

  static const Color _secondaryLight = Color(0xFFB8860B);
  static const Color _onSecondaryLight = Color(0xFFFFFFFF);
  static const Color _secondaryContainerLight = Color(0xFFFFDE9A);
  static const Color _onSecondaryContainerLight = Color(0xFF2A1F00);

  static const Color _tertiaryLight = Color(0xFF006B5E);
  static const Color _surfaceLight = Color(0xFFF8F9FF);
  static const Color _surfaceVariantLight = Color(0xFFE0E2EC);
  static const Color _errorLight = Color(0xFFBA1A1A);

  // ── Dark Palette ──
  static const Color _primaryDark = Color(0xFF9ECAFF);
  static const Color _onPrimaryDark = Color(0xFF003258);
  static const Color _primaryContainerDark = Color(0xFF004A7C);
  static const Color _onPrimaryContainerDark = Color(0xFFD4E4FF);

  static const Color _secondaryDark = Color(0xFFF5C542);
  static const Color _onSecondaryDark = Color(0xFF3A2E00);
  static const Color _secondaryContainerDark = Color(0xFF544300);
  static const Color _onSecondaryContainerDark = Color(0xFFFFDE9A);

  static const Color _tertiaryDark = Color(0xFF5BD9C6);
  static const Color _surfaceDark = Color(0xFF111318);
  static const Color _surfaceVariantDark = Color(0xFF42474E);
  static const Color _errorDark = Color(0xFFFFB4AB);

  // ── Surface Gradients (for depth) ──
  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
    ],
  );

  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F0C29),
      Color(0xFF1E3A5F),
      Color(0xFF2C1654),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFB8860B),
      Color(0xFFD4A017),
    ],
  );

  static LinearGradient surfaceGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              const Color(0xFF15171E),
              const Color(0xFF111318),
            ]
          : [
              const Color(0xFFFCFDFF),
              const Color(0xFFF8F9FF),
            ],
    );
  }

  // ── Theme Data ──

  /// Light theme variant.
  static ThemeData get light => _buildTheme(Brightness.light);

  /// Dark theme variant.
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? _primaryDark : _primaryLight,
      onPrimary: isDark ? _onPrimaryDark : _onPrimaryLight,
      primaryContainer: isDark ? _primaryContainerDark : _primaryContainerLight,
      onPrimaryContainer:
          isDark ? _onPrimaryContainerDark : _onPrimaryContainerLight,
      secondary: isDark ? _secondaryDark : _secondaryLight,
      onSecondary: isDark ? _onSecondaryDark : _onSecondaryLight,
      secondaryContainer:
          isDark ? _secondaryContainerDark : _secondaryContainerLight,
      onSecondaryContainer:
          isDark ? _onSecondaryContainerDark : _onSecondaryContainerLight,
      tertiary: isDark ? _tertiaryDark : _tertiaryLight,
      error: isDark ? _errorDark : _errorLight,
      onError: isDark ? const Color(0xFF601410) : const Color(0xFFFFFFFF),
      surface: isDark ? _surfaceDark : _surfaceLight,
      onSurface: isDark ? const Color(0xFFE2E2E9) : const Color(0xFF1A1C21),
      surfaceContainerHighest:
          isDark ? _surfaceVariantDark : _surfaceVariantLight,
      onSurfaceVariant:
          isDark ? const Color(0xFFC4C6D0) : const Color(0xFF44474F),
      outline: isDark ? const Color(0xFF8E9099) : const Color(0xFF74777F),
    );

    // Typography: Distinctive fonts (Pillar 1)
    final TextTheme interTextTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final TextTheme poppinsTextTheme = GoogleFonts.poppinsTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final TextTheme mergedTextTheme = interTextTheme.copyWith(
      displayLarge: poppinsTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      displayMedium: poppinsTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      displaySmall: poppinsTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: poppinsTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: poppinsTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: poppinsTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: poppinsTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleMedium: poppinsTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: poppinsTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: poppinsTextTheme.labelLarge,
      labelMedium: poppinsTextTheme.labelMedium,
      labelSmall: poppinsTextTheme.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: mergedTextTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      brightness: brightness,

      // AppBar: clean, elevated only when scrolled
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),

      // Card: rounded, subtle depth
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Input Fields: rounded, filled with bold focus
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),

      // Elevated Button: bold, with depth
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Navigation Bar (Mobile bottom nav)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              );
            }
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
            );
          },
        ),
      ),

      // Drawer: rounded right edge for depth
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),

      // Dialog: rounded with atmospheric depth
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Divider: subtle
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.2),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
