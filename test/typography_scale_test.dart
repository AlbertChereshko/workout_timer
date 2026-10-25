import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/core/typography_scale_provider.dart';
import 'package:workout_timer/core/theme/app_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TypographyScaleConfig Unit Tests', () {
    test('default configuration has scale 1.0 for all elements', () {
      const config = TypographyScaleConfig();
      expect(config.timerScale, 1.0);
      expect(config.activeDigitsScale, 1.0);
      expect(config.headingScale, 1.0);
      expect(config.bodyScale, 1.0);
    });

    test('copyWith updates individual scales properly', () {
      const config = TypographyScaleConfig();
      final updated = config.copyWith(
        timerScale: 1.25,
        headingScale: 1.10,
      );

      expect(updated.timerScale, 1.25);
      expect(updated.headingScale, 1.10);
      expect(updated.activeDigitsScale, 1.0);
      expect(updated.bodyScale, 1.0);
    });

    test('presets have correct predefined scales', () {
      expect(TypographyPreset.compact.scale, 0.85);
      expect(TypographyPreset.standard.scale, 1.0);
      expect(TypographyPreset.large.scale, 1.15);
      expect(TypographyPreset.maximum.scale, 1.30);
    });
  });

  group('AppTypography Scaling Integration Tests', () {
    setUp(() {
      AppTypography.enableDesktopMultiplier = false;
    });

    tearDown(() {
      AppTypography.enableDesktopMultiplier = true;
      AppTypography.currentScale = const TypographyScaleConfig();
    });

    test('timerDisplay applies timerScale factor', () {
      AppTypography.currentScale = const TypographyScaleConfig(timerScale: 1.2);
      final style = AppTypography.timerDisplay(fontSize: 90.0);
      expect(style.fontSize, closeTo(108.0, 0.01));
    });

    test('phaseHeader applies headingScale factor', () {
      AppTypography.currentScale = const TypographyScaleConfig(headingScale: 1.15);
      final style = AppTypography.phaseHeader(fontSize: 20.0);
      expect(style.fontSize, closeTo(23.0, 0.01));
    });

    test('roundCounter applies activeDigitsScale factor', () {
      AppTypography.currentScale = const TypographyScaleConfig(activeDigitsScale: 0.9);
      final style = AppTypography.roundCounter(fontSize: 20.0);
      expect(style.fontSize, closeTo(18.0, 0.01));
    });

    test('bodyText applies bodyScale factor', () {
      AppTypography.currentScale = const TypographyScaleConfig(bodyScale: 1.25);
      final style = AppTypography.bodyText(fontSize: 16.0);
      expect(style.fontSize, closeTo(20.0, 0.01));
    });

    test('desktopMultiplier applies 1.25 factor when enabled on desktop/web', () {
      AppTypography.enableDesktopMultiplier = true;
      AppTypography.currentScale = const TypographyScaleConfig();
      final expected = AppTypography.isDesktopOrWeb ? 20.0 : 16.0;
      final style = AppTypography.bodyText(fontSize: 16.0);
      expect(style.fontSize, closeTo(expected, 0.01));
    });
  });
}
