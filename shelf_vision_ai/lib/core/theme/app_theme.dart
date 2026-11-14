import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mode-independent colours: detection semantics (same on any background,
/// they are drawn over the photo / camera) + the dark camera chrome.
class AppColors {
  AppColors._();

  // Brand accent (from the logo's viewfinder) — used on dark camera chrome.
  static const Color accent = Color(0xFF2FC9A4);
  static const Color onAccent = Color(0xFF04140F);

  // Semantic — detection classes (also used as the on-camera legend)
  static const Color product = Color(0xFF3CCB7F);
  static const Color empty = Color(0xFFF2585C);
  static const Color row = Color(0xFF5B9BFF);
  static const Color shelf = Color(0xFFF4B740);

  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFE5A21A);

  // Camera chrome (camera screens are always dark, like the system camera)
  static const Color surface = Color(0xFF15181F);
  static const Color hairline = Color(0xFF262B35);
  static const Color textPrimary = Color(0xFFECEEF2);
  static const Color textSecondary = Color(0xFF9BA3B1);
  static const Color textTertiary = Color(0xFF656D7C);
}

/// Theme-aware neutrals + accent. Read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color onAccent;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
  });

  static const dark = AppPalette(
    background: Color(0xFF0E1015),
    surface: Color(0xFF15181F),
    surfaceRaised: Color(0xFF1C2029),
    hairline: Color(0xFF262B35),
    textPrimary: Color(0xFFECEEF2),
    textSecondary: Color(0xFF9BA3B1),
    textTertiary: Color(0xFF656D7C),
    accent: Color(0xFF2FC9A4),
    onAccent: Color(0xFF04140F),
  );

  static const light = AppPalette(
    background: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEEF0F3),
    hairline: Color(0xFFE2E5EA),
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF5A6371),
    textTertiary: Color(0xFF8A929F),
    // Deeper teal so accent text/buttons keep contrast on white.
    accent: Color(0xFF0E9C7C),
    onAccent: Color(0xFFFFFFFF),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    hairline: hairline ?? this.hairline,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 20; // page side padding
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

/// Type scale. Colourless on purpose: text inherits the theme's on-surface
/// colour, and muted styles get `context.palette.textSecondary/Tertiary`.
class AppText {
  AppText._();
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );
  static const TextStyle headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45);
  static const TextStyle bodyMuted = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45);
  static const TextStyle caption = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.35);
  static const TextStyle overline = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.8);
  static const TextStyle metric = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: tabular,
  );
}

/// The type scale resolved against the current theme's palette.
class AppTextStyles {
  final AppPalette p;
  const AppTextStyles(this.p);
  TextStyle get title => AppText.title.copyWith(color: p.textPrimary);
  TextStyle get headline => AppText.headline.copyWith(color: p.textPrimary);
  TextStyle get body => AppText.body.copyWith(color: p.textPrimary);
  TextStyle get bodyMuted => AppText.bodyMuted.copyWith(color: p.textSecondary);
  TextStyle get caption => AppText.caption.copyWith(color: p.textTertiary);
  TextStyle get overline => AppText.overline.copyWith(color: p.textTertiary);
  TextStyle get metric => AppText.metric.copyWith(color: p.textPrimary);
}

extension AppTextContext on BuildContext {
  AppTextStyles get text => AppTextStyles(palette);
}

class AppTheme {
  AppTheme._();

  /// Status/navigation bar style for the always-dark camera screens.
  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);
  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness b) {
    final isDark = b == Brightness.dark;
    final scheme = ColorScheme(
      brightness: b,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.surfaceRaised,
      primaryContainer: p.surfaceRaised,
      onPrimaryContainer: p.textPrimary,
      outline: p.hairline,
      outlineVariant: p.hairline,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final systemStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: b,
      systemNavigationBarColor: p.background,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemStyle,
        titleTextStyle: AppText.headline.copyWith(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.surfaceRaised,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: p.hairline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? p.surfaceRaised : const Color(0xFF1F232B),
        contentTextStyle: AppText.body.copyWith(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? p.surfaceRaised : const Color(0xFF1F232B),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
