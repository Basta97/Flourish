import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final raised = isDark ? AppColors.raisedDark : AppColors.raisedLight;
    final primary = isDark ? AppColors.primaryLight : AppColors.primaryDeep;
    final palette = isDark ? FlourishPalette.dark : FlourishPalette.light;
    final onSurface = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final onSurfaceVariant = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final outline = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final fill = AppColors.mutedSurfaceForBrightness(isDark);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: isDark ? AppColors.surfaceDark : Colors.white,
          secondary: isDark ? AppColors.secondaryLight : AppColors.secondary,
          onSecondary: isDark ? AppColors.surfaceDark : Colors.white,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          outline: outline,
          outlineVariant: outline.withValues(alpha: isDark ? 0.75 : 0.88),
          surfaceContainerHighest: raised,
          error: AppColors.danger,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      visualDensity: VisualDensity.standard,
      extensions: [palette],
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme:
          GoogleFonts.manropeTextTheme(
            isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
          ).copyWith(
            headlineLarge: AppTextStyles.display.copyWith(color: onSurface),
            headlineMedium: AppTextStyles.headline.copyWith(color: onSurface),
            headlineSmall: AppTextStyles.title.copyWith(color: onSurface),
            titleLarge: AppTextStyles.title.copyWith(color: onSurface),
            titleMedium: AppTextStyles.subtitle.copyWith(color: onSurface),
            bodyLarge: AppTextStyles.body.copyWith(color: onSurface),
            bodyMedium: AppTextStyles.body.copyWith(color: onSurface),
            labelLarge: AppTextStyles.bodyMedium,
            labelMedium: AppTextStyles.caption,
          ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        titleTextStyle: AppTextStyles.title.copyWith(color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
        actionsIconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.lg),
          side: BorderSide(color: palette.stroke),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        tabAlignment: TabAlignment.start,
        labelColor: onSurface,
        unselectedLabelColor: onSurfaceVariant,
        labelStyle: AppTextStyles.bodyMedium,
        unselectedLabelStyle: AppTextStyles.bodyMedium,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicator: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(Rad.full),
          border: Border.all(color: palette.stroke),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: card.withValues(alpha: 0.96),
        indicatorColor: primary.withValues(alpha: isDark ? 0.18 : 0.12),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : onSurfaceVariant,
            size: selected ? 24 : 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.caption.copyWith(
            color: selected ? primary : onSurfaceVariant,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedTextStyle: AppTextStyles.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sp.lg,
          vertical: 14,
        ),
        labelStyle: AppTextStyles.body.copyWith(color: onSurfaceVariant),
        hintStyle: AppTextStyles.body.copyWith(
          color: onSurfaceVariant.withValues(alpha: 0.66),
        ),
        floatingLabelStyle: AppTextStyles.caption.copyWith(color: primary),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(primary, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.xl),
        ),
        titleTextStyle: AppTextStyles.title.copyWith(color: onSurface),
        contentTextStyle: AppTextStyles.body.copyWith(color: onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.raisedDark
            : AppColors.textPrimaryLight,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          Sp.lg,
          0,
          Sp.lg,
          Sp.bottomNavClear,
        ),
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.md),
          ),
          textStyle: AppTextStyles.bodyMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.md),
          ),
          side: BorderSide(color: outline),
          textStyle: AppTextStyles.bodyMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.md,
            vertical: Sp.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.md),
          ),
          textStyle: AppTextStyles.bodyMedium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.md),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.md),
          side: BorderSide(color: palette.stroke),
        ),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
        textStyle: AppTextStyles.body.copyWith(color: onSurface),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.mutedSurfaceForBrightness(isDark),
        disabledColor: AppColors.mutedSurfaceForBrightness(
          isDark,
        ).withValues(alpha: 0.6),
        selectedColor: primary.withValues(alpha: isDark ? 0.20 : 0.12),
        secondarySelectedColor: AppColors.secondary.withValues(alpha: 0.12),
        side: BorderSide(color: palette.stroke),
        labelStyle: AppTextStyles.caption.copyWith(color: onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.full),
        ),
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: fill,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(Rad.full),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceVariant,
        textColor: onSurface,
        titleTextStyle: AppTextStyles.bodyMedium.copyWith(color: onSurface),
        subtitleTextStyle: AppTextStyles.body.copyWith(color: onSurfaceVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return isDark ? AppColors.textSecondaryDark : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.32);
          }
          return outline.withValues(alpha: isDark ? 0.9 : 1);
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary.withValues(alpha: isDark ? 0.18 : 0.10);
            }
            return card;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return onSurfaceVariant;
          }),
          side: WidgetStateProperty.all(BorderSide(color: palette.stroke)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rad.full),
            ),
          ),
          textStyle: WidgetStateProperty.all(AppTextStyles.bodyMedium),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTextStyles.body.copyWith(color: onSurface),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(raised),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
          ),
          side: WidgetStateProperty.all(BorderSide(color: palette.stroke)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(card),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
          ),
          side: WidgetStateProperty.all(BorderSide(color: outline)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.24),
        selectionHandleColor: primary,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Rad.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
