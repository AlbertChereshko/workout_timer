import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../typography_scale_provider.dart';

/// Centralized Typography Theme for Workout Timer.
///
/// Fonts:
/// - Display, Timer, Rounds & Phase status: **Chakra Petch** (accented digital style with tabular figures).
/// - UI, Settings, Lists, Labels & Inputs: **Inter** (clean modern sans-serif).
class AppTypography {
  AppTypography._();

  /// Текущая активная конфигурация масштабирования шрифтов
  static TypographyScaleConfig currentScale = const TypographyScaleConfig();

  /// Флаг десктопной платформы или браузера
  static bool get isDesktopOrWeb =>
      kIsWeb || (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS));

  /// Флаг включения автоматического масштабирования под десктоп/веб
  static bool enableDesktopMultiplier = true;

  /// Множитель шрифтов для десктопа и веба для удобного чтения с расстояния экрана ноутбука
  static double get desktopMultiplier => (enableDesktopMultiplier && isDesktopOrWeb) ? 1.25 : 1.0;

  // ---------------------------------------------------------------------------
  // Digital & Accented Presets (Chakra Petch)
  // ---------------------------------------------------------------------------

  /// Giant timer countdown display (92–110pt, Bold, tabular mono figures, glow/shadow).
  static TextStyle timerDisplay({
    Color color = Colors.white,
    double fontSize = 92.0,
    double letterSpacing = 10.0,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.timerScale) * desktopMultiplier;
    final isDarkText = color.computeLuminance() < 0.45;
    return GoogleFonts.chakraPetch(
      fontSize: effectiveSize,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: isDarkText
          ? null
          : [
              Shadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  /// Large accented workout phase header ("РАБОТА", "ОТДЫХ", "ПОДГОТОВКА" / "WORK", "REST").
  static TextStyle phaseHeader({
    Color color = Colors.white,
    double fontSize = 26.0,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.headingScale) * desktopMultiplier;
    return GoogleFonts.chakraPetch(
      fontSize: effectiveSize,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 2.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Medium status counters ("РАУНД 3/8", "МИНУТА 5/10", "КРУГ 1/3").
  static TextStyle roundCounter({
    Color color = Colors.white,
    double fontSize = 20.0,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.activeDigitsScale) * desktopMultiplier;
    return GoogleFonts.chakraPetch(
      fontSize: effectiveSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Exercise titles in workout / timer screen (Inter, 24pt, bold/italic support).
  static TextStyle exerciseTitle({
    Color color = Colors.white,
    double fontSize = 24.0,
    FontWeight fontWeight = FontWeight.w800,
    FontStyle fontStyle = FontStyle.normal,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.headingScale) * desktopMultiplier;
    return GoogleFonts.inter(
      fontSize: effectiveSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: 0.2,
    );
  }

  /// Digital numerical badges (e.g. interval numbers, quick stats).
  static TextStyle numericValue({
    Color color = Colors.white,
    double fontSize = 24.0,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.activeDigitsScale) * desktopMultiplier;
    return GoogleFonts.chakraPetch(
      fontSize: effectiveSize,
      fontWeight: FontWeight.w700,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // ---------------------------------------------------------------------------
  // Clean System UI Presets (Inter)
  // ---------------------------------------------------------------------------

  /// Clean medium button label (16–18pt, SemiBold, Inter).
  static TextStyle buttonLabel({
    Color color = Colors.white,
    double fontSize = 16.0,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.bodyScale) * desktopMultiplier;
    return GoogleFonts.inter(
      fontSize: effectiveSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.2,
    );
  }

  /// Standard UI body text for settings, explanations, and list titles (14–16pt, Regular/Medium, Inter).
  static TextStyle bodyText({
    Color color = Colors.white,
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.w400,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.bodyScale) * desktopMultiplier;
    return GoogleFonts.inter(
      fontSize: effectiveSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.35,
    );
  }

  /// Field captions, hints, secondary labels, interval sliders descriptions (12–13pt, Regular/Medium, Inter).
  static TextStyle caption({
    Color color = const Color(0x99FFFFFF),
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.w500,
    double? scale,
  }) {
    final effectiveSize = fontSize * (scale ?? currentScale.bodyScale) * desktopMultiplier;
    return GoogleFonts.inter(
      fontSize: effectiveSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.1,
    );
  }

  /// Build standard TextTheme based on Inter for global application widgets.
  static TextTheme createTextTheme(
    Color primaryText,
    Color secondaryText, {
    TypographyScaleConfig? scaleConfig,
  }) {
    final cfg = scaleConfig ?? currentScale;
    final dMult = desktopMultiplier;
    final baseInter = GoogleFonts.interTextTheme();
    return baseInter.copyWith(
      displayLarge: GoogleFonts.chakraPetch(
        fontSize: 96 * cfg.timerScale * dMult,
        fontWeight: FontWeight.w700,
        color: primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: GoogleFonts.chakraPetch(
        fontSize: 48 * cfg.timerScale * dMult,
        fontWeight: FontWeight.w700,
        color: primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displaySmall: GoogleFonts.chakraPetch(
        fontSize: 32 * cfg.headingScale * dMult,
        fontWeight: FontWeight.w700,
        color: primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineMedium: GoogleFonts.chakraPetch(
        fontSize: 26 * cfg.headingScale * dMult,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: 2.0,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20 * cfg.headingScale * dMult,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16 * cfg.headingScale * dMult,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16 * cfg.bodyScale * dMult,
        fontWeight: FontWeight.w400,
        color: primaryText,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14 * cfg.bodyScale * dMult,
        fontWeight: FontWeight.w400,
        color: primaryText,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12 * cfg.bodyScale * dMult,
        fontWeight: FontWeight.w500,
        color: secondaryText,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 16 * cfg.bodyScale * dMult,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
    );
  }
}
