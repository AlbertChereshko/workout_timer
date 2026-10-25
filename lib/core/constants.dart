import 'package:flutter/material.dart';

/// App-wide color constants.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0D0D0D);
  static const Color accent = Color(0xFFFF6B00);
  static const Color workPhase = Color(0xFFFF4500);
  static const Color restPhase = Color(0xFF00C853);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color countdown = Color(0xFF9E9E9E);
  static const Color cardBorder = Color(0xFF2A2A2A);
}

/// Default EMOM configuration.
class EmomDefaults {
  EmomDefaults._();

  static const int rounds = 10;
  static const int roundDurationSeconds = 60;
}

/// Default Tabata configuration.
class TabataDefaults {
  TabataDefaults._();

  static const int workSeconds = 20;
  static const int restSeconds = 10;
  static const int rounds = 8;
  static const int cycles = 1;
}

/// Countdown duration before a workout begins.
const int kCountdownSeconds = 3;
