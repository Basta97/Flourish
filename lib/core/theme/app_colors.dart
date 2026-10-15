import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand (Jade) ───
  // `primary` is the mode-neutral brand tint used for icons and accents.
  // Themes pick `primaryLight` (dark mode) or `primaryDeep` (light mode) for
  // filled controls so text on top keeps contrast.
  static const Color primary = Color(0xFF22C58B);
  static const Color primaryLight = Color(0xFF3DDC97);
  static const Color primaryDeep = Color(0xFF077352);
  static const Color secondary = Color(0xFF6366F1);
  static const Color secondaryLight = Color(0xFFA5B4FC);
  static const Color aurora = Color(0xFF0B0D12);
  static const Color peach = Color(0xFFF4A261);

  // ─── Semantic Colors ───
  static const Color income = Color(0xFF4FD1A1);
  static const Color expense = Color(0xFFFF7A6B);
  static const Color danger = Color(0xFFF2545B);
  static const Color accent = Color(0xFF6366F1);
  static const Color warning = Color(0xFFF5B547);

  static const Color aiInsight = Color(0xFF8B7CF6);

  // ─── Surfaces ───
  // Dark mode is layered in three steps: background → surface → raised.
  static const Color backgroundDark = Color(0xFF0B0D12);
  static const Color surfaceLight = Color(0xFFF4F5F7);
  static const Color surfaceDark = Color(0xFF0B0D12);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF12151C);
  static const Color raisedLight = Color(0xFFFFFFFF);
  static const Color raisedDark = Color(0xFF1A1E27);
  static const Color glassStrongLight = Color(0xFFFFFFFF);
  static const Color glassStrongDark = Color(0xFF12151C);
  static const Color textPrimaryLight = Color(0xFF0E1116);
  static const Color textSecondaryLight = Color(0xFF5F6B7A);
  static const Color textPrimaryDark = Color(0xFFF2F4F7);
  static const Color textSecondaryDark = Color(0xFF9AA3B2);
  static const Color dividerLight = Color(0xFFE4E7EC);
  static const Color dividerDark = Color(0xFF222733);

  // ─── Gradients ───
  static const List<Color> gradientNetWorth = [
    Color(0xFF141A22),
    Color(0xFF0E1218),
  ];
  static const List<Color> gradientAI = [Color(0xFF8B7CF6), Color(0xFF6366F1)];
  static const List<Color> gradientBackdropLight = [
    Color(0xFFF4F5F7),
    Color(0xFFFAFAFB),
  ];
  static const List<Color> gradientBackdropDark = [
    Color(0xFF0B0D12),
    Color(0xFF0E1117),
  ];

  // ─── Account Gradients (desaturated for calm) ───
  static List<List<Color>> accountGradients = [
    [const Color(0xFF1F7A5C), const Color(0xFF3DDC97)],
    [const Color(0xFF3F46B8), const Color(0xFF8B93F0)],
    [const Color(0xFF1D6A80), const Color(0xFF5FC4DB)],
    [const Color(0xFF8A6A2A), const Color(0xFFE8C46E)],
    [const Color(0xFF8C4A35), const Color(0xFFF0A07E)],
    [const Color(0xFF5B3F9E), const Color(0xFFB7A3F2)],
    [const Color(0xFF8E3846), const Color(0xFFF08D9A)],
    [const Color(0xFF3A4352), const Color(0xFF9AA6B8)],
  ];

  static int accountGradientIndex(String iconName) {
    return iconName.length % accountGradients.length;
  }

  // ─── Health Score ───
  static const List<Color> healthScoreColors = [
    Color(0xFFF2545B),
    Color(0xFFF5B547),
    Color(0xFF4FD1A1),
  ];

  static Color healthScoreColor(double score) {
    if (score < 33) return healthScoreColors[0];
    if (score < 66) return healthScoreColors[1];
    return healthScoreColors[2];
  }

  // ─── Category Palette ───
  static const List<int> categoryPalette = [
    0xFFFF7A6B,
    0xFFF5B547,
    0xFF4FD1A1,
    0xFF5B9DF5,
    0xFF8B7CF6,
    0xFFF07AB8,
    0xFF3CC8C0,
    0xFFF4A261,
    0xFF7C83F2,
    0xFF4FB8E8,
    0xFFF2545B,
    0xFF8A94A6,
  ];

  // ─── Fallbacks ───
  static const int fallbackColor = 0xFF8A94A6;

  static Color hex(int hex) => Color(hex);

  // ─── Context-aware helpers ───
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? textSecondaryDark : textSecondaryLight;
  static Color surface(BuildContext context) =>
      _isDark(context) ? surfaceDark : surfaceLight;
  static Color card(BuildContext context) =>
      _isDark(context) ? cardDark : cardLight;
  static Color divider(BuildContext context) =>
      _isDark(context) ? dividerDark : dividerLight;
  static Color glass(BuildContext context) =>
      _isDark(context) ? cardDark : cardLight;
  static Color glassStrong(BuildContext context) =>
      _isDark(context) ? glassStrongDark : glassStrongLight;
  static Color glassStroke(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE4E7EC);
  static Color softStroke(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.05);
  static Color mutedSurface(BuildContext context) =>
      mutedSurfaceForBrightness(_isDark(context));
  static Color mutedSurfaceForBrightness(bool isDark) =>
      isDark ? const Color(0xFF1A1E27) : const Color(0xFFECEEF2);
  static Color elevatedSurface(BuildContext context) =>
      _isDark(context) ? raisedDark : raisedLight;
  static Color heroSurface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF12151C) : const Color(0xFF0E1116);
  static Color shadow(BuildContext context) =>
      Colors.black.withValues(alpha: _isDark(context) ? 0.35 : 0.06);
  static Color brand(BuildContext context) =>
      _isDark(context) ? primaryLight : primaryDeep;
}

/// Theme-scoped design tokens. Read with `FlourishPalette.of(context)`.
@immutable
class FlourishPalette extends ThemeExtension<FlourishPalette> {
  const FlourishPalette({
    required this.background,
    required this.surface,
    required this.raised,
    required this.stroke,
    required this.highlight,
    required this.accent,
    required this.accentSoft,
    required this.income,
    required this.expense,
    required this.warning,
    required this.textHigh,
    required this.textLow,
    required this.navBar,
  });

  final Color background;
  final Color surface;
  final Color raised;
  final Color stroke;

  /// Thin top-edge sheen used on layered cards.
  final Color highlight;
  final Color accent;
  final Color accentSoft;
  final Color income;
  final Color expense;
  final Color warning;
  final Color textHigh;
  final Color textLow;
  final Color navBar;

  static const dark = FlourishPalette(
    background: AppColors.backgroundDark,
    surface: AppColors.cardDark,
    raised: AppColors.raisedDark,
    stroke: Color(0x14FFFFFF),
    highlight: Color(0x1AFFFFFF),
    accent: AppColors.primaryLight,
    accentSoft: Color(0x263DDC97),
    income: AppColors.income,
    expense: AppColors.expense,
    warning: AppColors.warning,
    textHigh: AppColors.textPrimaryDark,
    textLow: AppColors.textSecondaryDark,
    navBar: Color(0xE0151922),
  );

  static const light = FlourishPalette(
    background: AppColors.surfaceLight,
    surface: AppColors.cardLight,
    raised: AppColors.raisedLight,
    stroke: Color(0x0F000000),
    highlight: Color(0xFFFFFFFF),
    accent: AppColors.primaryDeep,
    // Light values are darkened to keep text at ≥ 4.5:1 on every surface.
    accentSoft: Color(0x1F077352),
    income: Color(0xFF0A7350),
    expense: Color(0xFFC23B28),
    warning: Color(0xFF92600F),
    textHigh: AppColors.textPrimaryLight,
    textLow: AppColors.textSecondaryLight,
    navBar: Color(0xE6151922),
  );

  static FlourishPalette of(BuildContext context) =>
      Theme.of(context).extension<FlourishPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  FlourishPalette copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? stroke,
    Color? highlight,
    Color? accent,
    Color? accentSoft,
    Color? income,
    Color? expense,
    Color? warning,
    Color? textHigh,
    Color? textLow,
    Color? navBar,
  }) {
    return FlourishPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      stroke: stroke ?? this.stroke,
      highlight: highlight ?? this.highlight,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      textHigh: textHigh ?? this.textHigh,
      textLow: textLow ?? this.textLow,
      navBar: navBar ?? this.navBar,
    );
  }

  @override
  FlourishPalette lerp(FlourishPalette? other, double t) {
    if (other == null) return this;
    return FlourishPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textHigh: Color.lerp(textHigh, other.textHigh, t)!,
      textLow: Color.lerp(textLow, other.textLow, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
    );
  }
}
