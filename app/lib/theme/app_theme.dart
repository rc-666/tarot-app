// Tarot app theme, from the design handoff v2 tokens (2026-11-22). Change values in tokens, then here.
// Requires Flutter 3.27+ (uses ColorScheme.surfaceContainer*, WidgetStateProperty, DialogThemeData).
// Fonts: bundle the TTFs from fonts-flutter/ (see pubspec_fonts.yaml).
import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF161B26);
  static const surface = Color(0xFF1F2633);
  static const surfaceRaised = Color(0xFF2A3140);
  static const divider = Color(0xFF323B4D);
  static const textPrimary = Color(0xFFEDE8DF);
  static const textSecondary = Color(0xFFA9B0BD);
  static const primary = Color(0xFFC9A96E);
  static const onPrimary = Color(0xFF161B26);
  static const error = Color(0xFFE59C8E);
  static const disabledText = Color(0xFF8B93A1);
  static const scrim = Color(0xB3080A0F); // rgba(8,10,15,0.70)
}

class AppSpace {
  static const xxs = 4.0, xs = 8.0, sm = 12.0, md = 16.0, screen = 20.0, lg = 24.0, xl = 32.0, xxl = 48.0;
}

class AppSize {
  /// Card height / width. Decision 2026-11-22: Rider–Waite art, ~1:1.72 (design token update pending; was 1.68).
  static const cardAspect = 1.72;
  static Size card(double width) => Size(width, (width * cardAspect).roundToDouble());
  static const cardReveal = 100.0, cardRevealMin = 88.0, cardHome = 92.0, cardThumb = 64.0, cardSection = 44.0, cardReward = 150.0;
  static const button = 56.0, topBar = 56.0, minTap = 48.0;
}

class AppRadius {
  static const small = 4.0, card = 6.0, medium = 8.0, dialog = 16.0, sheet = 20.0;
}

class AppMotion {
  static const cardLift = Duration(milliseconds: 120);
  static const cardFlip = Duration(milliseconds: 500);
  static const frameHairline = Duration(milliseconds: 300);
  static const cardNameFade = Duration(milliseconds: 150);
  static const readScroll = Duration(milliseconds: 400);
  static const panelUpdate = Duration(milliseconds: 200);
  static const readButtonFade = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 250);
  static const cardLiftDistance = 4.0;
  static const flipCurve = Curves.easeInOut;
  static const liftCurve = Curves.easeOut;
  static const fadeCurve = Curves.easeOut;
  static const sheetCurve = Curves.easeOutCubic; // M3 emphasized decelerate


  /// Use instead of the constants above so "Remove animations" gives an instant reveal.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : d;
}

class AppText {
  static const _headline = 'Playfair Display';
  static const _reading = 'Noto Serif';
  static const _ui = 'Noto Sans';

  static const display = TextStyle(fontFamily: _headline, fontSize: 30, fontWeight: FontWeight.w500, height: 1.25, color: AppColors.textPrimary);
  static const heading = TextStyle(fontFamily: _headline, fontSize: 28, fontWeight: FontWeight.w500, height: 1.25, color: AppColors.textPrimary);
  static const title = TextStyle(fontFamily: _headline, fontSize: 22, fontWeight: FontWeight.w500, height: 1.3, color: AppColors.textPrimary);
  static const opening = TextStyle(fontFamily: _headline, fontSize: 24, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, height: 1.4, color: AppColors.textPrimary);
  static const readingBody = TextStyle(fontFamily: _reading, fontSize: 18, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.textPrimary);
  static const body = TextStyle(fontFamily: _ui, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.textSecondary);
  static const bodyLarge = TextStyle(fontFamily: _ui, fontSize: 17, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.textPrimary);
  static const button = TextStyle(fontFamily: _ui, fontSize: 17, fontWeight: FontWeight.w600, height: 1.2);
  static const label = TextStyle(fontFamily: _ui, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.textSecondary); // render uppercase
  static const caption = TextStyle(fontFamily: _ui, fontSize: 15, fontWeight: FontWeight.w400, height: 1.45, color: AppColors.textSecondary);
  static const cardLabel = TextStyle(fontFamily: _ui, fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    surface: AppColors.background,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceRaised,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.divider,
    outlineVariant: AppColors.divider,
    error: AppColors.error,
    onError: AppColors.onPrimary,
    scrim: AppColors.scrim,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium));
  const minSize = Size.fromHeight(56);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Noto Sans',
    dividerColor: AppColors.divider,
    textTheme: const TextTheme(
      displaySmall: AppText.display,
      headlineMedium: AppText.heading,
      titleLarge: AppText.title,
      bodyLarge: AppText.bodyLarge,
      bodyMedium: AppText.body,
      labelLarge: AppText.button,
      labelMedium: AppText.label,
      bodySmall: AppText.caption,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.surfaceRaised,
        disabledForegroundColor: AppColors.disabledText,
        minimumSize: minSize,
        shape: shape,
        textStyle: AppText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.divider),
        minimumSize: minSize,
        shape: shape,
        textStyle: AppText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 48),
        textStyle: AppText.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: AppText.bodyLarge.copyWith(color: AppColors.textSecondary),
      labelStyle: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      errorStyle: AppText.caption.copyWith(color: AppColors.error),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.error, width: 2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.error, width: 2)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBarrierColor: AppColors.scrim,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.scrim,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
      side: const BorderSide(color: AppColors.textSecondary, width: 2),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
  );
}
