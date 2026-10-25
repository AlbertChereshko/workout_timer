import 'package:flutter/material.dart';
import '../../data/models/workout.dart';

/// Цветовые и визуальные параметры для систем тренировок (ТАБАТА / EMOM)
class WorkoutTypeTheme {
  // ТАБАТА: сочные оранжевые оттенки (Cyber Flame Orange)
  static const Color tabataDark = Color(0xFFFF6B00);
  static const Color tabataLight = Color(0xFFEA580C);

  // EMOM: сочные изумрудно-зеленые оттенки (Emerald Mint Green)
  static const Color emomDark = Color(0xFF10B981);
  static const Color emomLight = Color(0xFF059669);

  // AMRAP: сочные неоново-фиолетовые оттенки (Electric Violet / Purple)
  static const Color amrapDark = Color(0xFF8B5CF6);
  static const Color amrapLight = Color(0xFF7C3AED);

  /// Основной акцентный цвет в зависимости от типа и темы (темная/светлая)
  static Color primary(WorkoutType type, {bool isLight = false}) {
    switch (type) {
      case WorkoutType.tabata:
        return isLight ? tabataLight : tabataDark;
      case WorkoutType.emom:
        return isLight ? emomLight : emomDark;
      case WorkoutType.amrap:
        return isLight ? amrapLight : amrapDark;
    }
  }

  /// Полупрозрачный фоновый оттенок для плашек и бейджей
  static Color backgroundTint(
    WorkoutType type, {
    bool isLight = false,
    bool isRecentlyCompleted = false,
  }) {
    final c = primary(type, isLight: isLight);
    if (isRecentlyCompleted) {
      return isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    }
    return c.withValues(alpha: isLight ? 0.12 : 0.16);
  }

  /// Цвет окантовки карточки или бейджа
  static Color border(
    WorkoutType type, {
    bool isLight = false,
    bool isRecentlyCompleted = false,
  }) {
    final c = primary(type, isLight: isLight);
    if (isRecentlyCompleted) {
      return isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08);
    }
    return c.withValues(alpha: isLight ? 0.38 : 0.30);
  }

  /// Цвет свечения / тени для карточки
  static Color glow(WorkoutType type, {bool isLight = false}) {
    final c = primary(type, isLight: isLight);
    return c.withValues(alpha: isLight ? 0.07 : 0.16);
  }

  /// Иконка системы тренировок
  static IconData icon(WorkoutType type) {
    switch (type) {
      case WorkoutType.tabata:
        return Icons.local_fire_department_rounded; // Пламя / Табата
      case WorkoutType.emom:
        return Icons.timer_outlined; // Таймер / EMOM
      case WorkoutType.amrap:
        return Icons.bolt_rounded; // Молния / AMRAP
    }
  }

  /// Название системы
  static String label(WorkoutType type) {
    switch (type) {
      case WorkoutType.tabata:
        return 'TABATA';
      case WorkoutType.emom:
        return 'EMOM';
      case WorkoutType.amrap:
        return 'AMRAP';
    }
  }
}
