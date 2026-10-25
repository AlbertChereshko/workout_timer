import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_typography.dart';

/// Конфигурация масштабов шрифтов для тонкой настройки интерфейса
class TypographyScaleConfig {
  /// Масштаб цифр таймеров (обратный отсчет)
  final double timerScale;

  /// Масштаб всех активных цифр (счетчики раундов, общее время, показатели)
  final double activeDigitsScale;

  /// Масштаб заголовков (названия упражнений, фазы, заголовки экранов)
  final double headingScale;

  /// Масштаб основного текста (описания, подписи, текст кнопок)
  final double bodyScale;

  const TypographyScaleConfig({
    this.timerScale = 1.0,
    this.activeDigitsScale = 1.0,
    this.headingScale = 1.0,
    this.bodyScale = 1.0,
  });

  TypographyScaleConfig copyWith({
    double? timerScale,
    double? activeDigitsScale,
    double? headingScale,
    double? bodyScale,
  }) {
    return TypographyScaleConfig(
      timerScale: timerScale ?? this.timerScale,
      activeDigitsScale: activeDigitsScale ?? this.activeDigitsScale,
      headingScale: headingScale ?? this.headingScale,
      bodyScale: bodyScale ?? this.bodyScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyScaleConfig &&
          runtimeType == other.runtimeType &&
          timerScale == other.timerScale &&
          activeDigitsScale == other.activeDigitsScale &&
          headingScale == other.headingScale &&
          bodyScale == other.bodyScale;

  @override
  int get hashCode =>
      timerScale.hashCode ^
      activeDigitsScale.hashCode ^
      headingScale.hashCode ^
      bodyScale.hashCode;
}

enum TypographyPreset {
  compact(0.85, 'Компактный (85%)'),
  standard(1.0, 'Стандарт (100%)'),
  large(1.15, 'Крупный (115%)'),
  maximum(1.30, 'Максимум (130%)');

  final double scale;
  final String label;
  const TypographyPreset(this.scale, this.label);
}

class TypographyScaleNotifier extends StateNotifier<TypographyScaleConfig> {
  TypographyScaleNotifier() : super(_loadInitial()) {
    AppTypography.currentScale = state;
  }

  static TypographyScaleConfig _loadInitial() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final timer = (box.get('timer_scale', defaultValue: 1.0) as num).toDouble();
        final digits = (box.get('active_digits_scale', defaultValue: 1.0) as num).toDouble();
        final heading = (box.get('heading_scale', defaultValue: 1.0) as num).toDouble();
        final body = (box.get('body_scale', defaultValue: 1.0) as num).toDouble();
        return TypographyScaleConfig(
          timerScale: timer,
          activeDigitsScale: digits,
          headingScale: heading,
          bodyScale: body,
        );
      }
    } catch (_) {}
    return const TypographyScaleConfig();
  }

  void _save(TypographyScaleConfig config) {
    state = config;
    AppTypography.currentScale = config;
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        box.put('timer_scale', config.timerScale);
        box.put('active_digits_scale', config.activeDigitsScale);
        box.put('heading_scale', config.headingScale);
        box.put('body_scale', config.bodyScale);
      }
    } catch (_) {}
  }

  void setTimerScale(double scale) {
    _save(state.copyWith(timerScale: scale));
  }

  void setActiveDigitsScale(double scale) {
    _save(state.copyWith(activeDigitsScale: scale));
  }

  void setHeadingScale(double scale) {
    _save(state.copyWith(headingScale: scale));
  }

  void setBodyScale(double scale) {
    _save(state.copyWith(bodyScale: scale));
  }

  void setPreset(TypographyPreset preset) {
    _save(TypographyScaleConfig(
      timerScale: preset.scale,
      activeDigitsScale: preset.scale,
      headingScale: preset.scale,
      bodyScale: preset.scale,
    ));
  }

  void resetToDefaults() {
    _save(const TypographyScaleConfig());
  }
}

final typographyScaleProvider =
    StateNotifierProvider<TypographyScaleNotifier, TypographyScaleConfig>((ref) {
  return TypographyScaleNotifier();
});
