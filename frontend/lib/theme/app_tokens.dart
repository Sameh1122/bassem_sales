import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Supported visual theme modes, including high-contrast Outdoor Field mode
/// for direct-sunlight legibility.
enum AppThemeMode {
  dark,
  light,
  outdoor;

  String get storageKey => name;

  String get label {
    switch (this) {
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.outdoor:
        return 'Outdoor Contrast';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.outdoor:
        return Icons.wb_sunny_outlined;
    }
  }

  static AppThemeMode fromString(String? raw) {
    switch (raw) {
      case 'light':
        return AppThemeMode.light;
      case 'outdoor':
        return AppThemeMode.outdoor;
      case 'dark':
      default:
        return AppThemeMode.dark;
    }
  }
}

/// Unified design tokens exposed via `Theme.of(context).extension<AppTokens>()`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Spacing scale
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;

  // Radius scale
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusPill;

  // Semantic colors
  final Color canvasBg;
  final Color surfaceElevated;
  final Color surfaceHeader;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color accentPrimary;
  final Color success;
  final Color warning;
  final Color caution;
  final Color danger;
  final Color achievement;
  final bool isHighContrast;

  const AppTokens({
    this.spaceXs = 4.0,
    this.spaceSm = 8.0,
    this.spaceMd = 12.0,
    this.spaceLg = 16.0,
    this.spaceXl = 24.0,
    this.radiusSm = 8.0,
    this.radiusMd = 12.0,
    this.radiusLg = 16.0,
    this.radiusPill = 20.0,
    required this.canvasBg,
    required this.surfaceElevated,
    required this.surfaceHeader,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.accentPrimary,
    required this.success,
    required this.warning,
    required this.caution,
    required this.danger,
    required this.achievement,
    required this.isHighContrast,
  });

  static const AppTokens dark = AppTokens(
    canvasBg: Color(0xFF0F172A),
    surfaceElevated: Color(0xFF1E293B),
    surfaceHeader: Color(0xFF0B132B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF), // white70
    textMuted: Color(0x61FFFFFF), // white38
    borderSubtle: Color(0x1FFFFFFF), // white12
    accentPrimary: Color(0xFF06B6D4),
    success: Color(0xFF10B981),
    warning: Color(0xFFF97316),
    caution: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    achievement: Color(0xFFA78BFA),
    isHighContrast: false,
  );

  static const AppTokens light = AppTokens(
    canvasBg: Color(0xFFF8FAFC),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceHeader: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    borderSubtle: Color(0xFFCBD5E1),
    accentPrimary: Color(0xFF0891B2),
    success: Color(0xFF059669),
    warning: Color(0xFFEA580C),
    caution: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    achievement: Color(0xFF7C3AED),
    isHighContrast: false,
  );

  static const AppTokens outdoor = AppTokens(
    canvasBg: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    surfaceHeader: Color(0xFF0F172A),
    textPrimary: Color(0xFF020617),
    textSecondary: Color(0xFF1E293B),
    textMuted: Color(0xFF475569),
    borderSubtle: Color(0xFF64748B),
    accentPrimary: Color(0xFF0369A1),
    success: Color(0xFF047857),
    warning: Color(0xFFC2410C),
    caution: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    achievement: Color(0xFF6D28D9),
    isHighContrast: true,
  );

  // Typography helpers
  TextStyle get displayTitle => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: textPrimary,
      );

  TextStyle get sectionTitle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      );

  TextStyle get cardTitle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  TextStyle get bodyDefault => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: textPrimary,
      );

  TextStyle get caption => TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  TextStyle get eyebrow => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: accentPrimary,
      );

  TextStyle get metricNum => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: textPrimary,
      );

  double get borderWidth => isHighContrast ? 1.5 : 1.0;

  static AppTokens of(BuildContext context) {
    return Theme.of(context).extension<AppTokens>() ?? AppTokens.dark;
  }

  static AppTokens forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return AppTokens.dark;
      case AppThemeMode.light:
        return AppTokens.light;
      case AppThemeMode.outdoor:
        return AppTokens.outdoor;
    }
  }

  static ThemeData buildThemeData(AppThemeMode mode) {
    final tokens = forMode(mode);
    final isDark = mode == AppThemeMode.dark;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: tokens.canvasBg,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: tokens.accentPrimary,
        secondary: tokens.success,
        surface: tokens.surfaceElevated,
        error: tokens.danger,
        onPrimary: isDark ? Colors.black : Colors.white,
        onSurface: tokens.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surfaceElevated,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
      ),
      dividerColor: tokens.borderSubtle,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surfaceElevated,
        selectedIconTheme: IconThemeData(color: tokens.accentPrimary),
        selectedLabelTextStyle: TextStyle(color: tokens.accentPrimary, fontWeight: FontWeight.bold),
        unselectedIconTheme: IconThemeData(color: tokens.textSecondary),
        unselectedLabelTextStyle: TextStyle(color: tokens.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surfaceElevated,
        indicatorColor: tokens.accentPrimary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? tokens.accentPrimary : tokens.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? tokens.accentPrimary : tokens.textSecondary,
          );
        }),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: tokens.displayTitle,
        titleMedium: tokens.sectionTitle,
        titleSmall: tokens.cardTitle,
        bodyMedium: tokens.bodyDefault,
        bodySmall: tokens.caption,
      ),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }

  @override
  AppTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusPill,
    Color? canvasBg,
    Color? surfaceElevated,
    Color? surfaceHeader,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
    Color? accentPrimary,
    Color? success,
    Color? warning,
    Color? caution,
    Color? danger,
    Color? achievement,
    bool? isHighContrast,
  }) {
    return AppTokens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusPill: radiusPill ?? this.radiusPill,
      canvasBg: canvasBg ?? this.canvasBg,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHeader: surfaceHeader ?? this.surfaceHeader,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      caution: caution ?? this.caution,
      danger: danger ?? this.danger,
      achievement: achievement ?? this.achievement,
      isHighContrast: isHighContrast ?? this.isHighContrast,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      spaceXs: spaceXs,
      spaceSm: spaceSm,
      spaceMd: spaceMd,
      spaceLg: spaceLg,
      spaceXl: spaceXl,
      radiusSm: radiusSm,
      radiusMd: radiusMd,
      radiusLg: radiusLg,
      radiusPill: radiusPill,
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t) ?? canvasBg,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      surfaceHeader: Color.lerp(surfaceHeader, other.surfaceHeader, t) ?? surfaceHeader,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t) ?? accentPrimary,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      caution: Color.lerp(caution, other.caution, t) ?? caution,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      achievement: Color.lerp(achievement, other.achievement, t) ?? achievement,
      isHighContrast: t < 0.5 ? isHighContrast : other.isHighContrast,
    );
  }
}
