import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/core/theme.dart';
import 'package:workout_timer/core/theme/app_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Light Theme High Contrast Tests', () {
    final lightThemes = AppThemes.all.where((t) => t.isLight).toList();

    test('All 3 light themes are present', () {
      expect(lightThemes.length, 3);
      expect(lightThemes.map((t) => t.id), containsAll([
        AppThemeId.neonLight,
        AppThemeId.satellitesLight,
        AppThemeId.circleLight,
      ]));
    });

    test('textPrimary in all light themes has deep dark contrast (< 0.05 luminance)', () {
      for (final theme in lightThemes) {
        expect(
          theme.textPrimary.computeLuminance(),
          lessThan(0.05),
          reason: '${theme.name} textPrimary should be deep obsidian black for razor-sharp legibility',
        );
      }
    });

    test('textSecondary in all light themes has high-contrast Slate-700 (< 0.15 luminance)', () {
      for (final theme in lightThemes) {
        expect(
          theme.textSecondary.computeLuminance(),
          lessThan(0.15),
          reason: '${theme.name} textSecondary should be Slate-700 for clear legibility on light backgrounds',
        );
      }
    });

    test('timerDisplay omits blurry shadow for dark text in light themes', () {
      final darkTextStyle = AppTypography.timerDisplay(color: const Color(0xFF0A0F1D));
      expect(darkTextStyle.shadows, isNull, reason: 'Dark numbers in light theme should not have blurry drop shadow');

      final lightTextStyle = AppTypography.timerDisplay(color: Colors.white);
      expect(lightTextStyle.shadows, isNotNull, reason: 'White numbers in dark theme should have glow shadow');
    });
  });
}
