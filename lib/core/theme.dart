import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_typography.dart';

enum TimerStyle {
  neon,
  cosmic,
  satellites,
  circular,
}

enum AppThemeId {
  neonDark,
  neonLight,
  cosmicDark,
  cosmicLight,
  satellitesDark,
  satellitesLight,
  circleDark,
  circleLight,

  // Legacy IDs for backward compatibility
  orangeBlack,
  greenBlack,
  neonCyber,
  gradientSunset,
  crimsonRed,
  goldenBeast,
  cosmicPlum,
  lightTitaniumOrange,
  lightVoltLime,
  lightArcticCyan,
}

class AppThemeConfig {
  final AppThemeId id;
  final String name;
  final String subtitle;
  final TimerStyle timerStyle;
  final Color background;
  final Color surface;
  final Color accent;
  final Color workPhase;
  final Color restPhase;
  final Color countdownPhase;
  final LinearGradient? gradient;
  final bool isLight;
  final Color textPrimary;
  final Color textSecondary;

  const AppThemeConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    this.timerStyle = TimerStyle.circular,
    required this.background,
    required this.surface,
    required this.accent,
    required this.workPhase,
    required this.restPhase,
    this.countdownPhase = const Color(0xFF9E9E9E),
    this.gradient,
    this.isLight = false,
    this.textPrimary = const Color(0xFFFFFFFF),
    this.textSecondary = const Color(0xFF9E9E9E),
  });

  Color get cardBorder => isLight ? const Color(0xFFCBD5E1) : const Color(0x1AFFFFFF);
  Color get surfaceSubtle => isLight ? const Color(0xFFF1F5F9) : const Color(0x14FFFFFF);
}

class AppThemes {
  // ===========================================================================
  // 1. НЕОН (Neon)
  // ===========================================================================
  static const neonDark = AppThemeConfig(
    id: AppThemeId.neonDark,
    name: 'Неон',
    subtitle: 'Тёмная • Cyber Neon & Cyan',
    timerStyle: TimerStyle.neon,
    background: Color(0xFF060911),
    surface: Color(0xFF0F1424),
    accent: Color(0xFF00E676),
    workPhase: Color(0xFF00E676),
    restPhase: Color(0xFF00D4FF),
    countdownPhase: Color(0xFF00D4FF),
    isLight: false,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF94A3B8),
  );

  static const neonLight = AppThemeConfig(
    id: AppThemeId.neonLight,
    name: 'Неон',
    subtitle: 'Светлая • Неоновый титан',
    timerStyle: TimerStyle.neon,
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF059669),
    workPhase: Color(0xFF059669),
    restPhase: Color(0xFF0284C7),
    countdownPhase: Color(0xFF0284C7),
    isLight: true,
    textPrimary: Color(0xFF0A0F1D),
    textSecondary: Color(0xFF334155),
  );

  // ===========================================================================
  // 2. КОСМОС (Cosmos)
  // ===========================================================================
  static const cosmicDark = AppThemeConfig(
    id: AppThemeId.cosmicDark,
    name: 'Космос',
    subtitle: 'Тёмная • Орбитальный сливовый',
    timerStyle: TimerStyle.cosmic,
    background: Color(0xFF130924),
    surface: Color(0xFF1E1038),
    accent: Color(0xFF10B981),
    workPhase: Color(0xFFFF9E0B),
    restPhase: Color(0xFF8B5CF6),
    countdownPhase: Color(0xFFA78BFA),
    isLight: false,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA78BFA),
  );

  static const cosmicLight = AppThemeConfig(
    id: AppThemeId.cosmicLight,
    name: 'Космос',
    subtitle: 'Светлая • Лавандовая туманность',
    timerStyle: TimerStyle.cosmic,
    background: Color(0xFFFAF5FF),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF7C3AED),
    workPhase: Color(0xFFD97706),
    restPhase: Color(0xFF7C3AED),
    countdownPhase: Color(0xFF6B21A8),
    isLight: true,
    textPrimary: Color(0xFF1E1B4B),
    textSecondary: Color(0xFF581C87),
  );

  // ===========================================================================
  // 3. СПУТНИКИ (Satellites)
  // ===========================================================================
  static const satellitesDark = AppThemeConfig(
    id: AppThemeId.satellitesDark,
    name: 'Спутники',
    subtitle: 'Тёмная • Спутниковый дашборд',
    timerStyle: TimerStyle.satellites,
    background: Color(0xFF0B1120),
    surface: Color(0xFF162035),
    accent: Color(0xFF38BDF8),
    workPhase: Color(0xFFF59E0B),
    restPhase: Color(0xFF38BDF8),
    countdownPhase: Color(0xFF94A3B8),
    isLight: false,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF94A3B8),
  );

  static const satellitesLight = AppThemeConfig(
    id: AppThemeId.satellitesLight,
    name: 'Спутники',
    subtitle: 'Светлая • Небесный дашборд',
    timerStyle: TimerStyle.satellites,
    background: Color(0xFFF0F9FF),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF0284C7),
    workPhase: Color(0xFFD97706),
    restPhase: Color(0xFF0284C7),
    countdownPhase: Color(0xFF475569),
    isLight: true,
    textPrimary: Color(0xFF0A0F1D),
    textSecondary: Color(0xFF334155),
  );

  // ===========================================================================
  // 4. КРУГ (Circle)
  // ===========================================================================
  static const circleDark = AppThemeConfig(
    id: AppThemeId.circleDark,
    name: 'Круг',
    subtitle: 'Тёмная • Cyber Orange & Black',
    timerStyle: TimerStyle.circular,
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF1A1A1A),
    accent: Color(0xFFFF6B00),
    workPhase: Color(0xFFFF4500),
    restPhase: Color(0xFF00C853),
    countdownPhase: Color(0xFF9E9E9E),
    isLight: false,
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9E9E9E),
  );

  static const circleLight = AppThemeConfig(
    id: AppThemeId.circleLight,
    name: 'Круг',
    subtitle: 'Светлая • Titanium White & Orange',
    timerStyle: TimerStyle.circular,
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFFFF5722),
    workPhase: Color(0xFFFF4500),
    restPhase: Color(0xFF00C853),
    countdownPhase: Color(0xFF475569),
    isLight: true,
    textPrimary: Color(0xFF0A0F1D),
    textSecondary: Color(0xFF334155),
  );

  // --- Совместимость с предыдущими темами ---
  static const orangeBlack = circleDark;
  static const greenBlack = neonDark;
  static const neonCyber = neonDark;
  static const crimsonRed = circleDark;
  static const goldenBeast = circleDark;
  static const cosmicPlum = cosmicDark;
  static const lightTitaniumOrange = circleLight;
  static const lightVoltLime = satellitesLight;
  static const lightArcticCyan = neonLight;

  static const List<AppThemeConfig> all = [
    satellitesDark,
    satellitesLight,
    neonDark,
    neonLight,
    circleDark,
    circleLight,
  ];

  /// Получить тему того же стиля с заданной яркостью (тёмная / светлая)
  static AppThemeConfig getMatchingMode(AppThemeConfig current, {required bool isDark}) {
    switch (current.timerStyle) {
      case TimerStyle.satellites:
      case TimerStyle.cosmic:
        return isDark ? satellitesDark : satellitesLight;
      case TimerStyle.neon:
        return isDark ? neonDark : neonLight;
      case TimerStyle.circular:
        return isDark ? circleDark : circleLight;
    }
  }

  static AppThemeConfig fromId(String idStr, {bool? preferDark}) {
    AppThemeConfig base;
    switch (idStr) {
      case 'satellitesDark':
        base = satellitesDark;
        break;
      case 'satellitesLight':
      case 'lightVoltLime':
        base = satellitesLight;
        break;
      case 'neonDark':
      case 'neonCyber':
      case 'greenBlack':
        base = neonDark;
        break;
      case 'neonLight':
      case 'lightArcticCyan':
        base = neonLight;
        break;
      case 'circleDark':
      case 'orangeBlack':
      case 'crimsonRed':
      case 'goldenBeast':
        base = circleDark;
        break;
      case 'circleLight':
      case 'lightTitaniumOrange':
        base = circleLight;
        break;
      case 'cosmicDark':
      case 'cosmicPlum':
        base = satellitesDark;
        break;
      case 'cosmicLight':
        base = satellitesLight;
        break;
      default:
        base = neonDark;
    }

    if (preferDark != null) {
      return getMatchingMode(base, isDark: preferDark);
    }
    return base;
  }
}

class AppThemeNotifier extends StateNotifier<AppThemeConfig> {
  AppThemeNotifier() : super(_loadInitialTheme()) {
    AppTheme.currentConfig = state;
  }

  static AppThemeConfig _loadInitialTheme() {
    try {
      final isSystemDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final savedId = box.get('theme_id', defaultValue: 'satellitesDark') as String;
        return AppThemes.fromId(savedId, preferDark: isSystemDark);
      }
      return isSystemDark ? AppThemes.satellitesDark : AppThemes.satellitesLight;
    } catch (_) {}
    return AppThemes.satellitesDark;
  }

  void updateForSystemBrightness(Brightness brightness) {
    final shouldBeDark = brightness == Brightness.dark;
    if (state.isLight == shouldBeDark) {
      final updated = AppThemes.getMatchingMode(state, isDark: shouldBeDark);
      setTheme(updated);
    }
  }

  void setTheme(AppThemeConfig theme) {
    state = theme;
    AppTheme.currentConfig = theme;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('theme_id', theme.id.name);
      }
    } catch (_) {}
  }
}

final appThemeProvider = StateNotifierProvider<AppThemeNotifier, AppThemeConfig>((ref) {
  return AppThemeNotifier();
});

class AppTheme {
  static AppThemeConfig currentConfig = AppThemes.orangeBlack;

  static Color get background => currentConfig.background;
  static Color get surface => currentConfig.surface;
  static Color get accent => currentConfig.accent;
  static Color get textPrimary => currentConfig.textPrimary;
  static Color get textSecondary => currentConfig.textSecondary;
  static Color get cardBorder => currentConfig.cardBorder;
  static Color get surfaceSubtle => currentConfig.surfaceSubtle;
  static bool get isLight => currentConfig.isLight;
  static Color get workPhase => currentConfig.workPhase;
  static Color get restPhase => currentConfig.restPhase;
  static Color get countdownPhase => currentConfig.countdownPhase;
  static LinearGradient? get gradient => currentConfig.gradient;

  static ThemeData getThemeData(AppThemeConfig config, {String? fontFamily}) {
    final brightness = config.isLight ? Brightness.light : Brightness.dark;
    final textTheme = AppTypography.createTextTheme(config.textPrimary, config.textSecondary);
    final baseTheme = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: config.background,
      fontFamily: fontFamily == 'System' ? null : fontFamily,
      textTheme: textTheme,
      primaryColor: config.accent,
      colorScheme: config.isLight
          ? ColorScheme.light(
              primary: config.accent,
              surface: config.surface,
              onSurface: config.textPrimary,
            )
          : ColorScheme.dark(
              primary: config.accent,
              surface: config.surface,
              onSurface: config.textPrimary,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: config.background,
        elevation: 0,
        centerTitle: true,
        foregroundColor: config.textPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: config.accent,
        foregroundColor: Colors.white,
      ),
      useMaterial3: true,
    );
    return baseTheme;
  }

  static ThemeData get darkTheme => getThemeData(currentConfig);
}
