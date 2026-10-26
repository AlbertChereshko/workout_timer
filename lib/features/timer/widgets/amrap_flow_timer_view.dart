import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/workout.dart';
import '../../../domain/timer_state.dart';
import '../../../services/music_service.dart';
import 'neon_ambient_background.dart';
import 'real_time_clock.dart';

class AmrapFlowTimerView extends StatelessWidget {
  final Workout workout;
  final TimerState state;
  final double progress;
  final AppThemeConfig theme;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onFinishEarly;
  final VoidCallback onRecordAmrap;

  const AmrapFlowTimerView({
    super.key,
    required this.workout,
    required this.state,
    required this.progress,
    required this.theme,
    required this.onTogglePlayPause,
    required this.onFinishEarly,
    required this.onRecordAmrap,
  });

  String _formatSeconds(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final exercises = workout.exercises;
    final currentIdx = state.currentExerciseIndex;

    // Определение следующего упражнения для подписи на кнопке
    String nextLabel;
    if (exercises.isEmpty) {
      nextLabel = '+1 Раунд';
    } else if (currentIdx + 1 < exercises.length) {
      final nextEx = exercises[currentIdx + 1];
      final repsStr = nextEx.reps != null
          ? '${nextEx.reps} раз'
          : (nextEx.durationSeconds != null ? '${nextEx.durationSeconds} сек' : '');
      nextLabel = '${nextEx.name}${repsStr.isNotEmpty ? ' ($repsStr)' : ''}';
    } else {
      nextLabel = 'Завершение раунда (+1 Раунд)';
    }


    // Подход внутри текущего раунда (например: "Подход 1 из 6" или "Подход 2")
    final currentApproach = exercises.isNotEmpty ? (currentIdx + 1) : 1;
    final approachSubtitle = exercises.length > 1
        ? 'Подход $currentApproach из ${exercises.length}'
        : 'Подход $currentApproach';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final isLandscape = screenWidth > screenHeight && screenHeight < 600;
          final isDesktop = (screenWidth >= 720 || screenHeight >= 900) && !isLandscape;

          // Пропорциональный расчет диаметра кольца с учетом высоты и ширины экрана
          final double ringSize;
          if (isDesktop) {
            // На десктопе круг занимает до 38% высоты экрана (или 42% ширины)
            final targetHeight = screenHeight * 0.38;
            final targetWidth = screenWidth * 0.42;
            final target = targetHeight < targetWidth ? targetHeight : targetWidth;
            ringSize = target.clamp(280.0, 430.0);
          } else {
            // Мобильный режим
            final targetHeight = screenHeight * 0.32;
            final targetWidth = screenWidth * 0.65;
            final target = targetHeight < targetWidth ? targetHeight : targetWidth;
            ringSize = target.clamp(200.0, 270.0);
          }

          final ringScale = ringSize / 250.0;

          return Stack(
            children: [
              // 1. Космический анимированный фон
              NeonAmbientBackground(
                phase: state.phase,
                progress: progress,
                theme: theme,
                isRunning: state.isRunning,
              ),

              // 2. Основное содержимое
              SafeArea(
                child: isLandscape
                    ? Row(
                        children: [
                          // Левая половина: список упражнений и большая кнопка ВЫПОЛНЕНО
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Expanded(
                                  child: exercises.isEmpty
                                      ? Center(
                                          child: Text(
                                            'В комплексе нет упражнений',
                                            style: TextStyle(
                                              color: theme.isLight ? Colors.black54 : Colors.white.withValues(alpha: 0.5),
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          itemCount: exercises.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                                          itemBuilder: (context, idx) {
                                            final ex = exercises[idx];
                                            final isDone = idx < currentIdx;
                                            final isCurrent = idx == currentIdx;
                                            if (isCurrent) {
                                              return _buildCurrentExerciseCard(ex, isDesktop: false);
                                            } else if (isDone) {
                                              return _buildDoneExerciseRow(ex, isDesktop: false);
                                            } else {
                                              return _buildUpcomingExerciseRow(ex, idx + 1, isDesktop: false);
                                            }
                                          },
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C3AED),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                      label: Text(
                                        '✓ ВЫПОЛНЕНО ($nextLabel)',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () {
                                        HapticFeedback.heavyImpact();
                                        onRecordAmrap();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Правая половина: Верхняя панель (Часы, Музыка, Выход) и Неоновое кольцо
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          onFinishEarly();
                                        },
                                      ),
                                      const RealTimeClock(
                                        fontSize: 22,
                                        color: Colors.white,
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          MusicService.showMusicPickerSheet(context, theme);
                                        },
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          onTogglePlayPause();
                                        },
                                        child: _buildGlowingOrbitRing(
                                          context: context,
                                          remainingSec: state.remainingSeconds,
                                          currentRound: state.currentRound,
                                          approachSubtitle: approachSubtitle,
                                          isRunning: state.isRunning,
                                          progress: progress,
                                          ringSize: (screenHeight - 80).clamp(150.0, 205.0),
                                          scale: ((screenHeight - 80).clamp(150.0, 205.0)) / 250.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                  children: [
                    // ВЕРХНЯЯ СТРОКА: < Назад  |  Часы реального времени  |  Музыка 🎵
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Кнопка Назад (только стрелка в круглом стиле)
                          Material(
                            color: Colors.transparent,
                            child: Tooltip(
                              message: 'Назад',
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onFinishEarly();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: theme.isLight ? const Color(0xFF0F172A) : Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Часы текущего времени по центру
                          Expanded(
                            child: Center(
                              child: RealTimeClock(
                                textStyle: GoogleFonts.chakraPetch(
                                  fontSize: (isDesktop ? 40 : 32) * AppTypography.currentScale.activeDigitsScale,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.5,
                                  color: theme.isLight ? const Color(0xFF0F172A) : Colors.white,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  shadows: theme.isLight
                                      ? [
                                          Shadow(
                                            color: const Color(0xFF00F5D4).withValues(alpha: 0.35),
                                            blurRadius: 16,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : [
                                          Shadow(
                                            color: const Color(0xFF00F5D4).withValues(alpha: 0.75),
                                            blurRadius: 28,
                                            offset: const Offset(0, 2),
                                          ),
                                          Shadow(
                                            color: const Color(0xFFBD00FF).withValues(alpha: 0.45),
                                            blurRadius: 44,
                                          ),
                                        ],
                                ),
                              ),
                            ),
                          ),

                          // Кнопка подключения музыки
                          Material(
                            color: Colors.transparent,
                            child: Tooltip(
                              message: 'Музыка',
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  MusicService.showMusicPickerSheet(context, theme);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: theme.isLight ? const Color(0xFF0F172A) : Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isDesktop ? 10 : 6),

                    // ЦЕНТРАЛЬНОЕ СВЕТЯЩЕЕСЯ НЕОНОВОЕ КОЛЬЦО (адаптивный размер)
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTogglePlayPause();
                        },
                        child: _buildGlowingOrbitRing(
                          context: context,
                          remainingSec: state.remainingSeconds,
                          currentRound: state.currentRound,
                          approachSubtitle: approachSubtitle,
                          isRunning: state.isRunning,
                          progress: progress,
                          ringSize: ringSize,
                          scale: ringScale,
                        ),
                      ),
                    ),

                    SizedBox(height: isDesktop ? 16 : 12),

                    // СПИСОК УПРАЖНЕНИЙ РАУНДА (на десктопе центрирован с комфортной шириной)
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 760 : double.infinity),
                          child: exercises.isEmpty
                              ? Center(
                                  child: Text(
                                    'В комплексе нет упражнений',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 28 : 20,
                                    vertical: 8,
                                  ),
                                  itemCount: exercises.length,
                                  separatorBuilder: (_, __) => SizedBox(height: isDesktop ? 14 : 12),
                                  itemBuilder: (context, idx) {
                                    final ex = exercises[idx];
                                    final isDone = idx < currentIdx;
                                    final isCurrent = idx == currentIdx;

                                    if (isCurrent) {
                                      return _buildCurrentExerciseCard(ex, isDesktop: isDesktop);
                                    } else if (isDone) {
                                      return _buildDoneExerciseRow(ex, isDesktop: isDesktop);
                                    } else {
                                      return _buildUpcomingExerciseRow(ex, idx + 1, isDesktop: isDesktop);
                                    }
                                  },
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // НИЖНЯЯ ФИОЛЕТОВАЯ КНОПКА: ✓ ВЫПОЛНЕНО (Далее: ...)
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 760 : double.infinity),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 28 : 20,
                            vertical: isDesktop ? 14 : 10,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              onRecordAmrap();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: isDesktop ? 16 : 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9D4EDD),
                                    Color(0xFF7209B7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0xFF00F5D4).withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9D4EDD).withValues(alpha: 0.6),
                                    blurRadius: 22,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF00F5D4).withValues(alpha: 0.3),
                                    blurRadius: 18,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded, color: Colors.white, size: isDesktop ? 24 : 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ВЫПОЛНЕНО',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isDesktop ? 18.5 : 17,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      'Далее: $nextLabel',
                                      maxLines: 3,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: isDesktop ? 14 : 12.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Центральный светящийся круг со временем (пропорционально масштабируемый)
  Widget _buildGlowingOrbitRing({
    required BuildContext context,
    required int remainingSec,
    required int currentRound,
    required String approachSubtitle,
    required bool isRunning,
    required double progress,
    required double ringSize,
    required double scale,
  }) {
    const mintColor = Color(0xFF00F5D4);
    const purpleColor = Color(0xFFBD00FF);

    final timerFontSize = (54 * scale).clamp(40.0, 96.0);
    final roundFontSize = (16 * scale).clamp(13.0, 26.0);
    final approachFontSize = (14 * scale).clamp(11.5, 22.0);
    final spacing = (4 * scale).clamp(2.0, 10.0);

    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: mintColor.withValues(alpha: isRunning ? 0.35 : 0.15),
            blurRadius: (36 * scale).clamp(24.0, 64.0),
            spreadRadius: (4 * scale).clamp(2.0, 8.0),
          ),
          BoxShadow(
            color: purpleColor.withValues(alpha: isRunning ? 0.25 : 0.1),
            blurRadius: (48 * scale).clamp(32.0, 80.0),
            spreadRadius: (2 * scale).clamp(1.0, 6.0),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Внешнее мятное кольцо и дуга прогресса
          CustomPaint(
            size: Size(ringSize, ringSize),
            painter: _AmrapRingPainter(
              progress: progress,
              mintColor: mintColor,
              purpleColor: purpleColor,
            ),
          ),

          // Цифры и подписи внутри круга
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Оставшиеся минуты и секунды (например, 15:00 или 00:03)
              Text(
                _formatSeconds(remainingSec),
                style: GoogleFonts.chakraPetch(
                  fontSize: timerFontSize,
                  fontWeight: FontWeight.w800,
                  color: theme.isLight ? const Color(0xFF0F172A) : Colors.white,
                  letterSpacing: (2.5 * scale).clamp(1.5, 5.0),
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: theme.isLight
                      ? [
                          Shadow(
                            color: mintColor.withValues(alpha: 0.35),
                            blurRadius: (12 * scale).clamp(8.0, 24.0),
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : [
                          Shadow(
                            color: mintColor.withValues(alpha: 0.8),
                            blurRadius: (24 * scale).clamp(16.0, 48.0),
                          ),
                          Shadow(
                            color: purpleColor.withValues(alpha: 0.5),
                            blurRadius: (36 * scale).clamp(24.0, 64.0),
                          ),
                        ],
                ),
              ),

              SizedBox(height: spacing),

              // РАУНД X
              Text(
                'РАУНД $currentRound',
                style: GoogleFonts.chakraPetch(
                  fontSize: roundFontSize,
                  fontWeight: FontWeight.w800,
                  color: theme.isLight ? const Color(0xFF1E293B) : Colors.white,
                  letterSpacing: (1.8 * scale).clamp(1.2, 3.5),
                  shadows: theme.isLight
                      ? null
                      : [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.6),
                            blurRadius: (12 * scale).clamp(8.0, 24.0),
                          ),
                        ],
                ),
              ),

              SizedBox(height: spacing),

              // Подход 1 из X
              Text(
                approachSubtitle,
                style: GoogleFonts.chakraPetch(
                  fontSize: approachFontSize,
                  color: theme.isLight ? const Color(0xFF0F766E) : mintColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: (1.2 * scale).clamp(0.8, 2.5),
                  shadows: theme.isLight
                      ? null
                      : [
                          Shadow(
                            color: mintColor.withValues(alpha: 0.5),
                            blurRadius: (10 * scale).clamp(6.0, 20.0),
                          ),
                        ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Карточка текущего упражнения в фокусе (неоновая фиолетово-мятная рамка)
  Widget _buildCurrentExerciseCard(Exercise ex, {bool isDesktop = false}) {
    final repsStr = ex.reps != null
        ? '${ex.reps} × '
        : (ex.durationSeconds != null ? '${ex.durationSeconds}с × ' : '');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 22 : 18,
        vertical: isDesktop ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00F5D4),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D4EDD).withValues(alpha: 0.5),
            blurRadius: 22,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF00F5D4).withValues(alpha: 0.35),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ТЕКУЩЕЕ УПРАЖНЕНИЕ',
            style: GoogleFonts.chakraPetch(
              fontSize: isDesktop ? 13 : 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: const Color(0xFF00F5D4),
            ),
          ),
          SizedBox(height: isDesktop ? 6 : 4),
          Text(
            '$repsStr${ex.name.toUpperCase()}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.chakraPetch(
              fontSize: isDesktop ? 26 : 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Строка завершенного упражнения
  Widget _buildDoneExerciseRow(Exercise ex, {bool isDesktop = false}) {
    final repsStr = ex.reps != null
        ? '${ex.reps} × '
        : (ex.durationSeconds != null ? '${ex.durationSeconds}с × ' : '');

    final Color textColor = theme.isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.4);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 8 : 6,
        vertical: isDesktop ? 3 : 2,
      ),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: isDesktop ? 22 : 20, color: const Color(0xFF00E676)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$repsStr${ex.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: isDesktop ? 17 : 15.5,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
                decorationColor: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Строка предстоящего упражнения
  Widget _buildUpcomingExerciseRow(Exercise ex, int number, {bool isDesktop = false}) {
    final repsStr = ex.reps != null
        ? '${ex.reps} × '
        : (ex.durationSeconds != null ? '${ex.durationSeconds}с × ' : '');

    final Color numberColor = theme.isLight
        ? const Color(0xFF475569)
        : Colors.white.withValues(alpha: 0.4);

    final Color textColor = theme.isLight
        ? const Color(0xFF0F172A) // Deep crisp slate for light theme
        : Colors.white.withValues(alpha: 0.85);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 8 : 6,
        vertical: isDesktop ? 3 : 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: isDesktop ? 26 : 22,
            child: Text(
              '$number',
              style: TextStyle(
                color: numberColor,
                fontSize: isDesktop ? 17 : 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$repsStr${ex.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: isDesktop ? 17 : 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Отрисовщик концентрических светящихся колец с масштабируемой толщиной линий
class _AmrapRingPainter extends CustomPainter {
  final double progress;
  final Color mintColor;
  final Color purpleColor;

  _AmrapRingPainter({
    required this.progress,
    required this.mintColor,
    required this.purpleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeScale = (size.width / 250.0).clamp(0.85, 1.8);
    final margin = 16.0 * strokeScale;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - margin) / 2;

    // Внешнее мятное кольцо (полное)
    final outerPaint = Paint()
      ..color = mintColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 * strokeScale
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, outerPaint);

    // Внутреннее фиолетовое кольцо прогресса (динамическая дуга)
    final sweepAngle = 2 * 3.141592653589793 * (progress.clamp(0.0, 1.0));
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [purpleColor, mintColor, purpleColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius - (8 * strokeScale)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 * strokeScale
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - (9 * strokeScale)),
      -3.141592653589793 / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AmrapRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mintColor != mintColor ||
        oldDelegate.purpleColor != purpleColor;
  }
}
