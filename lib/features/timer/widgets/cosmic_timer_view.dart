import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../data/models/workout.dart';
import '../../../domain/timer_state.dart';
import '../../../core/typography_scale_provider.dart';
import '../../../services/music_service.dart';
import 'real_time_clock.dart';

/// Виджет таймера в стиле Cosmic Plum / Satellites по референсу:
/// - Режим 1: Орбитальный циферблат с дугой и концентрическими кнопками
/// - Режим 2: "Разбросанные таймеры" (Orbital Dashboard) с 4 спутниковыми круговыми виджетами
class CosmicTimerView extends StatefulWidget {
  final Workout workout;
  final TimerState state;
  final double progress;
  final TypographyScaleConfig scaleConfig;
  final AppThemeConfig theme;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipPrevious;
  final VoidCallback onSkipNext;
  final VoidCallback onReset;
  final VoidCallback onFinishEarly;
  final VoidCallback? onRecordAmrap;
  final bool initialShowSatellites;

  const CosmicTimerView({
    super.key,
    required this.workout,
    required this.state,
    required this.progress,
    required this.scaleConfig,
    required this.theme,
    required this.onTogglePlayPause,
    required this.onSkipPrevious,
    required this.onSkipNext,
    required this.onReset,
    required this.onFinishEarly,
    this.onRecordAmrap,
    this.initialShowSatellites = false,
  });

  @override
  State<CosmicTimerView> createState() => _CosmicTimerViewState();
}

class _CosmicTimerViewState extends State<CosmicTimerView> with TickerProviderStateMixin {
  /// true = экран "Разбросанные таймеры" (4 орбитальных виджета), false = орбитальный циферблат
  late bool _showScatteredDashboard;
  late AnimationController _flowController;
  late Animation<double> _flowAnimation;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _showScatteredDashboard = widget.initialShowSatellites;
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _flowAnimation = CurvedAnimation(
      parent: _flowController,
      curve: Curves.linear,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(CosmicTimerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialShowSatellites != widget.initialShowSatellites) {
      _showScatteredDashboard = widget.initialShowSatellites;
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatMMSS(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scale = widget.scaleConfig;
    final isAmrap = widget.workout.type == WorkoutType.amrap;

    // Расчет оставшегося общего времени
    int roundWorkTime = 0;
    int roundRestTime = 0;
    if (widget.workout.type == WorkoutType.tabata) {
      roundWorkTime = widget.workout.tabataWorkSeconds;
      roundRestTime = widget.workout.tabataRestSeconds;
    } else if (widget.workout.type == WorkoutType.emom) {
      roundWorkTime = widget.workout.emomRoundDurationSeconds;
      roundRestTime = 0;
    } else {
      roundWorkTime = widget.workout.amrapDurationSeconds;
      roundRestTime = 0;
    }
    final fullRoundDuration = roundWorkTime + roundRestTime;
    final remainingRounds = (state.totalRounds - state.currentRound).clamp(0, 999);

    int remainingTotalSecs = 0;
    if (isAmrap) {
      remainingTotalSecs = state.remainingSeconds;
    } else if (state.phase == TimerPhase.work) {
      remainingTotalSecs = state.remainingSeconds + roundRestTime + (remainingRounds * fullRoundDuration);
    } else if (state.phase == TimerPhase.rest) {
      remainingTotalSecs = state.remainingSeconds + (remainingRounds * fullRoundDuration);
    } else if (state.phase == TimerPhase.finished) {
      remainingTotalSecs = 0;
    } else {
      remainingTotalSecs = state.remainingSeconds + (state.totalRounds * fullRoundDuration);
    }
    final totalRemainingFormatted = _formatMMSS(remainingTotalSecs);

    // Текущее и следующее упражнение
    String? currentExerciseName;
    String? nextExerciseName;
    int currentRoundWorkTime = roundWorkTime;
    if (widget.workout.exercises.isNotEmpty) {
      if (isAmrap) {
        final curIdx = state.currentExerciseIndex % widget.workout.exercises.length;
        final nextIdx = (state.currentExerciseIndex + 1) % widget.workout.exercises.length;
        final ex = widget.workout.exercises[curIdx];
        currentExerciseName = ex.name;
        nextExerciseName = widget.workout.exercises[nextIdx].name;
      } else {
        final curIdx = (state.currentRound - 1).clamp(0, 999999) % widget.workout.exercises.length;
        final nextIdx = state.currentRound % widget.workout.exercises.length;
        final ex = widget.workout.exercises[curIdx];
        currentExerciseName = ex.name;
        if (ex.durationSeconds != null && ex.durationSeconds! > 0) {
          currentRoundWorkTime = ex.durationSeconds!;
        }
        if (state.currentRound >= state.totalRounds) {
          nextExerciseName = 'Конец тренировки';
        } else {
          nextExerciseName = widget.workout.exercises[nextIdx].name;
        }
      }
    } else {
      nextExerciseName = isAmrap
          ? ''
          : (state.currentRound >= state.totalRounds
              ? 'Конец тренировки'
              : 'Раунд ${state.currentRound + 1}');
    }

    final bool isWorkPhase = state.phase == TimerPhase.work;
    final bool isRestPhase = state.phase == TimerPhase.rest;
    final bool isCountdown = state.phase == TimerPhase.countdown;

    // Значения времени для сателлитов (обратный отсчет во время активной фазы)
    final String workDisplay;
    if (isWorkPhase) {
      workDisplay = _formatMMSS(state.remainingSeconds);
    } else if (state.phase == TimerPhase.finished) {
      workDisplay = _formatMMSS(0);
    } else {
      workDisplay = _formatMMSS(currentRoundWorkTime);
    }

    final String restDisplay;
    if (isRestPhase) {
      restDisplay = _formatMMSS(state.remainingSeconds);
    } else if (state.phase == TimerPhase.finished) {
      restDisplay = _formatMMSS(0);
    } else {
      restDisplay = _formatMMSS(roundRestTime);
    }

    final isLight = widget.theme.isLight;
    final isSatellites = widget.theme.timerStyle == TimerStyle.satellites;
    final isCosmic = widget.theme.timerStyle == TimerStyle.cosmic;

    Color arcColor;
    String phaseLabel;
    if (isCountdown) {
      arcColor = widget.theme.countdownPhase;
      phaseLabel = state.isRunning ? 'ПОДГОТОВКА: ${state.remainingSeconds}с' : 'ПОДГОТОВКА';
    } else if (isWorkPhase) {
      arcColor = widget.theme.workPhase;
      phaseLabel = 'РАБОТА';
    } else {
      arcColor = widget.theme.restPhase;
      phaseLabel = 'ОТДЫХ';
    }

    final List<Color> gradientColors;
    if (isLight) {
      if (isSatellites) {
        gradientColors = const [
          Color(0xFFE0F2FE),
          Color(0xFFF0F9FF),
          Color(0xFFF8FAFC),
        ];
      } else {
        gradientColors = const [
          Color(0xFFF3E8FF),
          Color(0xFFFAF5FF),
          Color(0xFFFFFFFF),
        ];
      }
    } else {
      if (isSatellites) {
        gradientColors = const [
          Color(0xFF162035),
          Color(0xFF0F172A),
          Color(0xFF0B1120),
        ];
      } else {
        gradientColors = const [
          Color(0xFF2E134D),
          Color(0xFF180A2E),
          Color(0xFF11071F),
        ];
      }
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTogglePlayPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            widget.onFinishEarly();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onSkipNext();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.onSkipPrevious();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: widget.theme.background,
      body: Stack(
        children: [
          // 1. Анимированный фоновый градиент
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _flowController,
              builder: (context, _) {
                final double animValue = _flowController.value;

                if (isCosmic) {
                  // Для темы "Космос":
                  // - В светлой теме: красивое голубое небо с мягкими переливами
                  // - В темной теме: глубокий космос с переливами туманности
                  if (isLight) {
                    final double skyOffset = 0.20 * math.sin(animValue * 2 * math.pi);
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-skyOffset, -1.0),
                          end: Alignment(skyOffset, 1.0),
                          colors: const [
                            Color(0xFFBAE6FD), // Небесно-голубой
                            Color(0xFFE0F2FE), // Нежная лазурь с переливом
                            Color(0xFFF0F9FF), // Свежий светлый горизонт
                            Color(0xFFEBF8FF),
                          ],
                          stops: const [0.0, 0.40, 0.80, 1.0],
                        ),
                      ),
                    );
                  }
                } else if (isSatellites && isLight) {
                  // Для светлой темы "Спутники": пасмурное дождевое небо
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF64748B), // Мрачно-пасмурное дождевое небо
                          Color(0xFF94A3B8), // Серо-голубые облака
                          Color(0xFFCBD5E1), // Светлая дождевая дымка
                          Color(0xFFE2E8F0), // Нижняя кромка горизонта
                        ],
                        stops: [0.0, 0.35, 0.70, 1.0],
                      ),
                    ),
                  );
                }

                // Темные темы (Космос и Спутники): переливающийся космический источник света
                final double offsetX = 0.28 * math.sin(animValue * 2 * math.pi);
                final double offsetY = -0.28 + 0.18 * math.cos(animValue * 2 * math.pi);
                final double radius = 1.35 + 0.20 * math.sin(animValue * math.pi);

                final Color primaryTint = Color.lerp(
                  gradientColors[0],
                  arcColor,
                  0.24 + 0.16 * animValue,
                )!;
                final Color secondaryTint = Color.lerp(
                  gradientColors[1],
                  widget.theme.accent,
                  0.16 + 0.12 * animValue,
                )!;

                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(offsetX, offsetY),
                      radius: radius,
                      colors: [
                        primaryTint,
                        secondaryTint,
                        gradientColors[2],
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Интерактивная художественная россыпь фона:
          // - Для "Космос": звездное небо и созвездия (в темной и светлой темах)
          // - Для "Спутники" (светлая): пасмурная погода с дождем и каплями, стекающими по кругам
          // - Для "Спутники" (темная): космические планеты, орбиты и спутники
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flowController,
                builder: (context, _) {
                  if (isCosmic) {
                    return CustomPaint(
                      painter: StarryConstellationPainter(
                        progress: _flowController.value,
                        isLight: isLight,
                        accentColor: widget.theme.accent,
                        round: state.currentRound,
                        totalRounds: state.totalRounds,
                      ),
                    );
                  }
                  if (isSatellites && isLight) {
                    return CustomPaint(
                      painter: RainyOvercastPainter(
                        progress: _flowController.value,
                        accentColor: widget.theme.accent,
                      ),
                    );
                  }
                  return CustomPaint(
                    painter: CosmicPlanetsPainter(
                      progress: _flowController.value,
                      isLight: isLight,
                      primaryColor: arcColor,
                      accentColor: widget.theme.accent,
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Декоративные космические орбиты (только в темных темах)
          if (!isLight) ...[
            Positioned(
              top: -60,
              right: -60,
              child: AnimatedBuilder(
                animation: _flowAnimation,
                builder: (context, _) {
                  final double animValue = widget.state.isRunning ? _flowAnimation.value : 0.0;
                  return Container(
                    width: 220 + 10 * animValue,
                    height: 220 + 10 * animValue,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.03 + 0.04 * animValue),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: AnimatedBuilder(
                animation: _flowAnimation,
                builder: (context, _) {
                  final double animValue = widget.state.isRunning ? _flowAnimation.value : 0.0;
                  return Container(
                    width: 280 + 12 * animValue,
                    height: 280 + 12 * animValue,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: arcColor.withValues(alpha: 0.04 + 0.06 * animValue),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // 3. Основной контент в SafeArea
          SafeArea(
            child: Column(
              children: [
                // Шапка экрана
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(
                    children: [
                      // Кнопка выхода / завершения
                      _buildHeaderButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Завершить тренировку',
                        onTap: widget.onFinishEarly,
                      ),
                      const SizedBox(width: 8),

                      // Live Real-Time Clock
                      Expanded(
                        child: Center(
                          child: _showScatteredDashboard
                              ? _buildRectangularClockSatellite(
                                  scale: scale,
                                  isLight: isLight,
                                )
                              : RealTimeClock(
                                  fontSize: 39,
                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                  scale: scale.activeDigitsScale,
                                ),
                        ),
                      ),
                      // Кнопка выбора музыкального приложения (Spotify / YouTube Music)
                      _buildHeaderButton(
                        icon: Icons.music_note_rounded,
                        tooltip: 'Музыка',
                        onTap: () => MusicService.showMusicPickerSheet(context, widget.theme),
                      ),
                    ],
                  ),
                ),

                // Бейдж текущего раунда (скрыт в режиме спутников и космоса)
                if (!_showScatteredDashboard && !isCosmic)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLight
                            ? (isSatellites ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF))
                            : (isSatellites ? const Color(0xFF162035) : const Color(0xFF1E1038)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: arcColor.withValues(alpha: isLight ? 0.35 : 0.4), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: arcColor.withValues(alpha: isLight ? 0.08 : 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: arcColor,
                              boxShadow: [
                                BoxShadow(color: arcColor, blurRadius: 6, spreadRadius: 1),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'РАУНД ${state.currentRound} / ${state.totalRounds} • $phaseLabel',
                            style: GoogleFonts.chakraPetch(
                              color: isLight ? const Color(0xFF0F172A) : Colors.white,
                              fontSize: 13 * scale.activeDigitsScale,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Пропорциональная вертикальная компоновка элементов
                if (_showScatteredDashboard) ...[
                  const Spacer(flex: 1),

                  // 1. Название текущего упражнения над кругами
                  if (currentExerciseName != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        currentExerciseName.toUpperCase(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          fontSize: 21.6 * scale.headingScale,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                  ],

                  // 2. Комплекс кругов ("Разбросанные таймеры")
                  _buildScatteredDashboard(
                    state: state,
                    scale: scale,
                    workDisplay: workDisplay,
                    restDisplay: restDisplay,
                    isWorkActive: isWorkPhase,
                    isRestActive: isRestPhase,
                    totalRemainingFormatted: totalRemainingFormatted,
                  ),

                  const Spacer(flex: 1),

                  // 3. Следующее упражнение внизу под кругами
                  if (nextExerciseName.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        nextExerciseName.toUpperCase(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: widget.theme.accent,
                          fontSize: 19.5 * scale.bodyScale,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.25,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                  ],
                ] else if (isCosmic) ...[
                  // Режим "Космос": равномерное распределение по высоте экрана
                  const Spacer(flex: 2),

                  // Название текущего упражнения НАД циферблатом
                  if (currentExerciseName != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        currentExerciseName.toUpperCase(),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.chakraPetch(
                          color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          fontSize: 32 * scale.headingScale,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          height: 1.15,
                          shadows: [
                            Shadow(
                              color: arcColor.withValues(alpha: isLight ? 0.25 : 0.6),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(flex: 1),

                  // Циферблат таймера (чистый отсчет без лишних слов)
                  _buildOrbitalDial(
                    state: state,
                    scale: scale,
                    arcColor: arcColor,
                    phaseLabel: phaseLabel,
                    totalRemainingFormatted: totalRemainingFormatted,
                    currentExerciseName: currentExerciseName,
                    nextExerciseName: nextExerciseName,
                    isRestPhase: isRestPhase,
                  ),

                  const Spacer(flex: 1),

                  // Следующее упражнение ПОД циферблатом
                  if (nextExerciseName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '↑ ${nextExerciseName.toUpperCase()}',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            fontSize: 26 * scale.bodyScale,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: widget.theme.accent.withValues(alpha: isLight ? 0.25 : 0.45),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const Spacer(flex: 2),
                ] else ...[
                  const Spacer(flex: 1),
                  _buildOrbitalDial(
                    state: state,
                    scale: scale,
                    arcColor: arcColor,
                    phaseLabel: phaseLabel,
                    totalRemainingFormatted: totalRemainingFormatted,
                    currentExerciseName: currentExerciseName,
                    nextExerciseName: nextExerciseName,
                    isRestPhase: isRestPhase,
                  ),
                  const Spacer(flex: 2),
                ],

                // Нижний блок управления: фирменная концентрическая кнопка в стиле темы или круглая кнопка AMRAP
                if (isAmrap) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                    child: _showScatteredDashboard
                        ? _buildCircularAmrapButton(scale, isLight)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 6,
                                  ),
                                  icon: Icon(
                                    widget.workout.amrapCountByRounds
                                        ? Icons.add_circle_outline_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 24,
                                  ),
                                  label: Text(
                                    widget.workout.amrapCountByRounds
                                        ? '+1 РАУНД'
                                        : 'СЛЕД. УПРАЖНЕНИЕ',
                                    style: GoogleFonts.chakraPetch(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  onPressed: widget.onRecordAmrap,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildConcentricEmeraldButton(
                                    isRunning: state.isRunning,
                                    onTap: widget.onTogglePlayPause,
                                    scale: scale,
                                    buttonColor: isCosmic ? widget.theme.accent : const Color(0xFF10B981),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 38, left: 24, right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Кнопка назад / предыдущий раунд
                        _buildFlankingCircleButton(
                          icon: Icons.skip_previous_rounded,
                          tooltip: 'Предыдущий раунд',
                          onTap: widget.onSkipPrevious,
                        ),
                        const SizedBox(width: 24),

                        // Главная концентрическая неоновая/космическая кнопка Старт / Пауза
                        _buildConcentricEmeraldButton(
                          isRunning: state.isRunning,
                          onTap: widget.onTogglePlayPause,
                          scale: scale,
                          buttonColor: isCosmic ? widget.theme.accent : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 24),

                        // Кнопка вперед / следующий раунд
                        _buildFlankingCircleButton(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Следующий раунд',
                          onTap: widget.onSkipNext,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  // ---------------------------------------------------------------------------
  // Режим 1: Орбитальный циферблат с янтарной дугой и цифрами
  // ---------------------------------------------------------------------------
  Widget _buildOrbitalDial({
    required TimerState state,
    required TypographyScaleConfig scale,
    required Color arcColor,
    required String phaseLabel,
    required String totalRemainingFormatted,
    required String? currentExerciseName,
    required String? nextExerciseName,
    required bool isRestPhase,
  }) {
    final isLight = widget.theme.isLight;
    final isCosmic = widget.theme.timerStyle == TimerStyle.cosmic;
    const double dialSize = 270.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTogglePlayPause,
          child: SizedBox(
            width: dialSize,
            height: dialSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Внешний контур свечения диска
                Container(
                  width: dialSize,
                  height: dialSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: arcColor.withValues(alpha: isLight ? 0.08 : 0.12),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),

                // Кастомный художник дуги прогресса со светящейся точкой на конце
                CustomPaint(
                  size: const Size(dialSize, dialSize),
                  painter: _OrbitalDialPainter(
                    progress: widget.progress.clamp(0.0, 1.0),
                    trackColor: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF22113D),
                    arcColor: arcColor,
                    strokeWidth: 14.0,
                  ),
                ),

                // Внутреннее содержимое диска: в режиме Космос только таймер
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Верхняя метка в круге (скрыта в режиме Космос)
                      if (!isCosmic) ...[
                        Text(
                          widget.workout.type == WorkoutType.amrap
                              ? 'AMRAP • СЧЕТ: ${state.currentRound}${state.extraReps > 0 ? " + ${state.extraReps}" : ""}'
                              : 'ROUND ${state.currentRound}',
                          style: GoogleFonts.inter(
                            color: isLight ? widget.theme.accent : const Color(0xFFA78BFA),
                            fontSize: 12 * scale.bodyScale,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Крупные цифры обратного отсчета (MM:SS или SS)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatMMSS(state.remainingSeconds),
                          style: GoogleFonts.chakraPetch(
                            fontSize: (isCosmic ? 86 : 74) * scale.timerScale,
                            fontWeight: FontWeight.w800,
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            letterSpacing: 4.0,
                            height: 1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: arcColor.withValues(alpha: isLight ? 0.2 : 0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Общее время под цифрами (скрыто в режиме Космос)
                      if (!isCosmic) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TOTAL ',
                              style: GoogleFonts.inter(
                                color: isLight ? const Color(0xFF64748B) : Colors.white54,
                                fontSize: 11 * scale.bodyScale,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              totalRemainingFormatted,
                              style: GoogleFonts.chakraPetch(
                                color: isLight ? widget.theme.accent : const Color(0xFF10B981),
                                fontSize: 13 * scale.activeDigitsScale,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Бейдж паузы если таймер остановлен (скрыт в режиме Космос)
                      if (!isCosmic && !state.isRunning) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: arcColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: arcColor.withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: arcColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pause_rounded,
                                size: 14,
                                color: arcColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ПАУЗА',
                                style: GoogleFonts.inter(
                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                  fontSize: 11 * scale.bodyScale,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: arcColor.withValues(alpha: 0.8),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Название упражнения под диском (для других тем, кроме Космос, где они уже вынесены отдельно)
        if (!isCosmic && currentExerciseName != null) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                if (isRestPhase)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E1038),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      'СЛЕДУЮЩЕЕ УПРАЖНЕНИЕ:',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10B981),
                        fontSize: 10 * scale.bodyScale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                Text(
                  currentExerciseName.toUpperCase(),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.chakraPetch(
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                    fontSize: 20 * scale.headingScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    height: 1.15,
                    shadows: [
                      Shadow(
                        color: arcColor.withValues(alpha: isLight ? 0.25 : 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                if (nextExerciseName != null && nextExerciseName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '↑ ${nextExerciseName.toUpperCase()}',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                        fontSize: 14 * scale.bodyScale,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: widget.theme.accent.withValues(alpha: isLight ? 0.25 : 0.45),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Режим 2: "Разбросанные таймеры" (Orbital Dashboard)
  // ---------------------------------------------------------------------------
  Widget _buildScatteredDashboard({
    required TimerState state,
    required TypographyScaleConfig scale,
    required String workDisplay,
    required String restDisplay,
    required bool isWorkActive,
    required bool isRestActive,
    required String totalRemainingFormatted,
  }) {
    // В режиме EMOM (или если время отдыха равно 0) круг "ОТДЫХ" не нужен.
    // Отображаем 3 круга: доминирующий большой круг "РАБОТА" сверху
    // и пропорционально меньшие "СЕТЫ" и "ОБЩЕЕ ВРЕМЯ" снизу в ряд.
    final bool isEmom = widget.workout.type == WorkoutType.emom ||
        widget.workout.type == WorkoutType.amrap ||
        widget.workout.tabataRestSeconds == 0;

    if (isEmom) {
      final isAmrap = widget.workout.type == WorkoutType.amrap;
      final setsValue = isAmrap
          ? (state.extraReps > 0 ? '${state.currentRound} + ${state.extraReps}' : '${state.currentRound}')
          : '${state.currentRound} / ${state.totalRounds}';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Главный доминирующий спутник РАБОТА (пропорционально увеличен)
            _SatellitePod(
              size: 185.0,
              title: isAmrap ? '' : 'РАБОТА',
              value: workDisplay,
              subtitle: isAmrap ? '' : 'Интервал',
              accentColor: isAmrap ? const Color(0xFF8B5CF6) : widget.theme.workPhase,
              scale: scale,
              isLight: widget.theme.isLight,
              isActive: isWorkActive,
              isRunning: state.isRunning,
              onTap: widget.onTogglePlayPause,
            ),
            const SizedBox(height: 20),

            // 2. Нижний ряд: СЕТЫ и ОБЩЕЕ ВРЕМЯ (компактные поддерживающие спутники)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SatellitePod(
                  size: 122.0,
                  title: isAmrap ? 'РАУНДЫ' : 'СЕТЫ',
                  value: setsValue,
                  subtitle: isAmrap ? 'Счет' : 'Раунд',
                  accentColor: isAmrap ? const Color(0xFF8B5CF6) : widget.theme.accent,
                  scale: scale,
                  isLight: widget.theme.isLight,
                  isActive: false,
                  isRunning: state.isRunning,
                  onTap: widget.onTogglePlayPause,
                ),
                _SatellitePod(
                  size: 122.0,
                  title: 'ОБЩЕЕ ВРЕМЯ',
                  value: totalRemainingFormatted,
                  subtitle: 'Осталось',
                  accentColor: widget.theme.accent,
                  scale: scale,
                  isLight: widget.theme.isLight,
                  isActive: false,
                  isRunning: state.isRunning,
                  onTap: widget.onTogglePlayPause,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Стандартный режим (Табата / с интервалом отдыха): сетка 2х2 из 4 кругов
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. СЕТЫ (SETS)
              _SatellitePod(
                title: 'СЕТЫ',
                value: '${state.currentRound} / ${state.totalRounds}',
                subtitle: 'Раунд',
                accentColor: widget.theme.accent,
                scale: scale,
                isLight: widget.theme.isLight,
                isActive: false,
                isRunning: state.isRunning,
                onTap: widget.onTogglePlayPause,
              ),

              // 2. ДЕЙСТВИЕ / РАБОТА (ACTION)
              _SatellitePod(
                title: 'РАБОТА',
                value: workDisplay,
                subtitle: 'Интервал',
                accentColor: widget.theme.workPhase,
                scale: scale,
                isLight: widget.theme.isLight,
                isActive: isWorkActive,
                isRunning: state.isRunning,
                onTap: widget.onTogglePlayPause,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 3. ОТДЫХ (BREAK)
              _SatellitePod(
                title: 'ОТДЫХ',
                value: restDisplay,
                subtitle: 'Перерыв',
                accentColor: widget.theme.restPhase,
                scale: scale,
                isLight: widget.theme.isLight,
                isActive: isRestActive,
                isRunning: state.isRunning,
                onTap: widget.onTogglePlayPause,
              ),

              // 4. ВСЕГО ВРЕМЕНИ (TOTAL TIME)
              _SatellitePod(
                title: 'ОБЩЕЕ ВРЕМЯ',
                value: totalRemainingFormatted,
                subtitle: 'Осталось',
                accentColor: widget.theme.accent,
                scale: scale,
                isLight: widget.theme.isLight,
                isActive: false,
                isRunning: state.isRunning,
                onTap: widget.onTogglePlayPause,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Прямоугольный спутник с закругленными углами для отображения текущего времени (часов)
  Widget _buildRectangularClockSatellite({
    required TypographyScaleConfig scale,
    required bool isLight,
  }) {
    final accentColor = widget.theme.accent;
    final baseBg = isLight ? Colors.white : const Color(0xFF162035);
    final bgColor = Color.lerp(baseBg, accentColor, isLight ? 0.05 : 0.10)!;

    return GestureDetector(
      onTap: widget.onTogglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 140.0,
        height: 56.0,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withValues(alpha: isLight ? 0.6 : 0.45),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isLight ? 0.12 : 0.22),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RealTimeClock(
                fontSize: 28,
                scale: scale.activeDigitsScale,
                color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Нижние кнопки управления
  // ---------------------------------------------------------------------------

  /// Круглая кнопка фиксации следующего упражнения/раунда с пульсирующим ореолом в стиле темы
  Widget _buildCircularAmrapButton(TypographyScaleConfig scale, bool isLight) {
    final double buttonSize = (145.0 * scale.bodyScale).clamp(128.0, 160.0);
    final isByRounds = widget.workout.amrapCountByRounds;
    const primaryColor = Color(0xFF8B5CF6);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        final double pulseAlpha = (0.35 + 0.35 * pulse).clamp(0.0, 1.0);
        final double dynamicBlur = 18.0 + 12.0 * pulse;
        final double dynamicSpread = 2.0 + 4.0 * pulse;

        return Center(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onRecordAmrap?.call();
            },
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: pulseAlpha),
                    blurRadius: dynamicBlur,
                    spreadRadius: dynamicSpread,
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isByRounds ? Icons.add_circle_outline_rounded : Icons.check_circle_outline_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isByRounds ? '+1\nРАУНД' : 'СЛЕД.\nУПР.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.chakraPetch(
                          fontSize: 15 * scale.headingScale,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Фирменная концентрическая кнопка Старт / Пауза (изумрудная для Неона, фиолетовая/акцентная для Космоса)
  Widget _buildConcentricEmeraldButton({
    required bool isRunning,
    required VoidCallback onTap,
    required TypographyScaleConfig scale,
    Color buttonColor = const Color(0xFF10B981),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          // Внешний концентрический ореол
          border: Border.all(color: buttonColor.withValues(alpha: 0.35), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.4),
              blurRadius: 26,
              spreadRadius: 3,
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: buttonColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 42,
              color: const Color(0xFF0D0618),
            ),
          ),
        ),
      ),
    );
  }

  /// Круглые кнопки пропуска/переключения раундов рядом со стартом
  Widget _buildFlankingCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isLight = widget.theme.isLight;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1038),
            border: Border.all(
              color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: isLight ? const Color(0xFF0F172A) : Colors.white70,
            size: 28,
          ),
        ),
      ),
    );
  }

  /// Кнопка в шапке экрана
  Widget _buildHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool isHighlighted = false,
    String? label,
  }) {
    final isLight = widget.theme.isLight;
    final btn = Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHighlighted
                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                  : (isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1038)),
              border: Border.all(
                color: isHighlighted
                    ? const Color(0xFF10B981)
                    : (isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: Icon(
              icon,
              color: isHighlighted
                  ? const Color(0xFF10B981)
                  : (isLight ? const Color(0xFF0F172A) : Colors.white),
              size: 20,
            ),
          ),
        ),
      ),
    );

    if (label == null) return btn;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn,
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isHighlighted ? const Color(0xFF10B981) : const Color(0xFFA78BFA),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Интерактивный спутниковый круговой виджет с поддержкой масштабирования
/// и активного пульсирующего космического ореола свечения при обратном отсчете.
class _SatellitePod extends StatefulWidget {
  final double? size;
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final TypographyScaleConfig scale;
  final bool isLight;
  final bool isActive;
  final bool isRunning;
  final VoidCallback? onTap;

  const _SatellitePod({
    this.size,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.scale,
    required this.isLight,
    this.isActive = false,
    this.isRunning = false,
    this.onTap,
  });

  @override
  State<_SatellitePod> createState() => _SatellitePodState();
}

class _SatellitePodState extends State<_SatellitePod> with TickerProviderStateMixin {
  late final AnimationController _activeController;
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _activeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.09).animate(
      CurvedAnimation(parent: _activeController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.isActive) {
      _activeController.value = 1.0;
      if (widget.isRunning) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _SatellitePod oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _activeController.forward();
        if (widget.isRunning) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _activeController.reverse();
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    } else if (widget.isActive && widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _activeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double podSize = widget.size ?? 135.0;
    final double sizeRatio = podSize / 135.0;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_activeController, _pulseController]),
        builder: (context, child) {
          final activeProgress = _activeController.value;
          final pulse = _pulseController.value;

          // Динамический ореол свечения вокруг активного кружка
          final double baseAlpha = widget.isLight ? 0.35 : 0.52;
          final double pulseAlpha = (baseAlpha + (widget.isLight ? 0.15 : 0.22) * pulse) * activeProgress;
          final double dynamicSpread = (1.5 + (3.0 + pulse * 4.0) * activeProgress) * sizeRatio;
          final double dynamicBlur = (16.0 + (10.0 + pulse * 8.0) * activeProgress) * sizeRatio;

          final baseBg = widget.isLight ? Colors.white : const Color(0xFF1D0E36);
          final tintColor = widget.isLight
              ? Color.lerp(Colors.white, widget.accentColor, 0.07)!
              : Color.lerp(const Color(0xFF1D0E36), widget.accentColor, 0.14)!;
          final bgColor = Color.lerp(baseBg, tintColor, activeProgress)!;

          final borderWidth = (2.5 + 0.8 * activeProgress) * (sizeRatio >= 1.0 ? 1.0 : sizeRatio);
          final borderAlpha = (widget.isLight ? 0.7 : 0.4) + (widget.isLight ? 0.3 : 0.6) * activeProgress;

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: podSize,
              height: podSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: borderAlpha.clamp(0.0, 1.0)),
                  width: borderWidth,
                ),
                boxShadow: [
                  // Активный ореол свечения (Halo / Aura)
                  if (activeProgress > 0.01) ...[
                    // 1. Внешний мягкий ореол
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: pulseAlpha.clamp(0.0, 1.0)),
                      blurRadius: dynamicBlur,
                      spreadRadius: dynamicSpread,
                    ),
                    // 2. Внутренний концентрический контур свечения
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: (pulseAlpha * 0.75).clamp(0.0, 1.0)),
                      blurRadius: (10 + 4 * pulse) * sizeRatio,
                      spreadRadius: 1.5 * sizeRatio,
                    ),
                  ],
                  // Базовая фоновая тень для объема
                  BoxShadow(
                    color: widget.isLight
                        ? Colors.black.withValues(alpha: 0.06 * (1.0 - activeProgress * 0.5))
                        : widget.accentColor.withValues(
                            alpha: (widget.isLight ? 0.14 : 0.18) * (1.0 - activeProgress * 0.5),
                          ),
                    blurRadius: 18 * sizeRatio,
                    spreadRadius: 1 * sizeRatio,
                    offset: Offset(0, 4 * sizeRatio),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all((12 * sizeRatio).clamp(8.0, 20.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.title.isNotEmpty) ...[
                        Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            color: widget.accentColor,
                            fontSize: (12 + 0.6 * activeProgress) * widget.scale.bodyScale * sizeRatio,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 6 * sizeRatio),
                      ],
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.value,
                          style: GoogleFonts.chakraPetch(
                            color: widget.isLight ? const Color(0xFF0A0F1D) : Colors.white,
                            fontSize: (widget.title.isEmpty ? 44.0 : (27.0 + 2.0 * activeProgress)) *
                                widget.scale.activeDigitsScale *
                                sizeRatio,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Художник орбитального циферблата с неоновой дугой и индикаторной точкой на конце
class _OrbitalDialPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  _OrbitalDialPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Темный трек под дугой
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.001) return;

    // 2. Светящаяся неоновая дуга прогресса (по часовой стрелке от -pi/2)
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Свечение дуги
    final glowPaint = Paint()
      ..color = arcColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Основная линия дуги
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // 3. Светящаяся точка на конце дуги
    final endAngle = startAngle + sweepAngle;
    final dotX = center.dx + radius * math.cos(endAngle);
    final dotY = center.dy + radius * math.sin(endAngle);
    final dotCenter = Offset(dotX, dotY);

    final dotGlowPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(dotCenter, 6.0, dotGlowPaint);

    final dotCorePaint = Paint()..color = Colors.white;
    canvas.drawCircle(dotCenter, 4.0, dotCorePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Анимированный космический фон: стилизованные планеты, кольца, орбиты и спутники
class CosmicPlanetsPainter extends CustomPainter {
  final double progress;
  final bool isLight;
  final Color primaryColor;
  final Color accentColor;

  CosmicPlanetsPainter({
    required this.progress,
    required this.isLight,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double animAngle = progress * 2 * math.pi;

    // 1. Планета с кольцами (в стиле Сатурна) в верхне-левой части
    _drawRingedPlanet(
      canvas: canvas,
      center: Offset(
        size.width * 0.16 + 10 * math.sin(animAngle),
        size.height * 0.20 + 7 * math.cos(animAngle),
      ),
      radius: 24.0,
      tilt: 0.38,
    );

    // 2. Планета с орбитой и вращающимся спутником/луной в нижне-правой части
    _drawPlanetWithMoon(
      canvas: canvas,
      center: Offset(
        size.width * 0.84 - 8 * math.cos(animAngle),
        size.height * 0.64 + 9 * math.sin(animAngle),
      ),
      radius: 18.0,
      orbitA: 38.0,
      orbitB: 16.0,
      orbitAngle: animAngle * 1.6,
    );

    // 3. Космический исследовательский спутник/зонд с солнечными панелями
    _drawProbeSatellite(
      canvas: canvas,
      position: Offset(
        size.width * 0.82 + 12 * math.sin(animAngle * 0.8),
        size.height * 0.17 + 8 * math.cos(animAngle * 0.8),
      ),
      animAngle: animAngle,
    );

    // 4. Мягкие парящие космические микро-спутники / звездные огоньки
    _drawCosmicMotes(canvas, size, animAngle);
  }

  void _drawRingedPlanet({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double tilt,
  }) {
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 3.4,
      height: radius * 1.15,
    );

    final ringColor = (isLight ? accentColor : const Color(0xFFC084FC))
        .withValues(alpha: isLight ? 0.22 : 0.38);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;

    // Задняя часть кольца (за планетой)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.drawArc(ringRect, math.pi, math.pi, false, ringPaint);
    canvas.restore();

    // Атмосферное свечение планеты
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: isLight ? 0.10 : 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawCircle(center, radius + 3, glowPaint);

    // Тело планеты с градиентной тенью
    final planetPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: isLight
            ? [
                accentColor.withValues(alpha: 0.28),
                accentColor.withValues(alpha: 0.10),
              ]
            : [
                accentColor.withValues(alpha: 0.55),
                const Color(0xFF1B0E32),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, planetPaint);

    // Передняя часть кольца (перед планетой)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.drawArc(ringRect, 0, math.pi, false, ringPaint);
    canvas.restore();
  }

  void _drawPlanetWithMoon({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double orbitA,
    required double orbitB,
    required double orbitAngle,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Эллиптическая орбита спутника
    final orbitPaint = Paint()
      ..color = (isLight ? primaryColor : Colors.white).withValues(alpha: isLight ? 0.16 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: orbitA * 2, height: orbitB * 2),
      orbitPaint,
    );

    // Планета
    final planetGlow = Paint()
      ..color = primaryColor.withValues(alpha: isLight ? 0.10 : 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(Offset.zero, radius + 2, planetGlow);

    final planetPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: isLight
            ? [
                primaryColor.withValues(alpha: 0.26),
                primaryColor.withValues(alpha: 0.08),
              ]
            : [
                primaryColor.withValues(alpha: 0.50),
                const Color(0xFF13192B),
              ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, planetPaint);

    // Спутник / луна на орбите
    final moonOffset = Offset(orbitA * math.cos(orbitAngle), orbitB * math.sin(orbitAngle));
    final moonGlow = Paint()
      ..color = primaryColor.withValues(alpha: isLight ? 0.3 : 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(moonOffset, 4.5, moonGlow);

    final moonPaint = Paint()
      ..color = isLight ? primaryColor.withValues(alpha: 0.75) : Colors.white;
    canvas.drawCircle(moonOffset, 3.2, moonPaint);

    canvas.restore();
  }

  void _drawProbeSatellite({
    required Canvas canvas,
    required Offset position,
    required double animAngle,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(0.25 * math.sin(animAngle));

    final baseColor = isLight
        ? accentColor.withValues(alpha: 0.50)
        : Colors.white.withValues(alpha: 0.65);

    final probePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    // Корпус зонда
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 9),
        const Radius.circular(2),
      ),
      probePaint,
    );

    // Штанга солнечных батарей
    final wingPaint = Paint()
      ..color = baseColor.withValues(alpha: isLight ? 0.40 : 0.50)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-13, 0), const Offset(13, 0), wingPaint);

    // Солнечные панели
    final panelPaint = Paint()
      ..color = (isLight ? widgetAccentLight : widgetAccentDark).withValues(alpha: isLight ? 0.35 : 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromCenter(center: const Offset(-10, 0), width: 5, height: 10), panelPaint);
    canvas.drawRect(Rect.fromCenter(center: const Offset(10, 0), width: 5, height: 10), panelPaint);

    // Антенна с радио-маячком
    canvas.drawLine(const Offset(0, -5), const Offset(0, -11), wingPaint);
    final beaconPulse = 0.5 + 0.5 * math.sin(animAngle * 4.0);
    final beaconPaint = Paint()
      ..color = primaryColor.withValues(alpha: (0.4 + 0.6 * beaconPulse).clamp(0.0, 1.0));
    canvas.drawCircle(const Offset(0, -11), 2.2, beaconPaint);

    canvas.restore();
  }

  Color get widgetAccentLight => accentColor;
  Color get widgetAccentDark => accentColor;

  void _drawCosmicMotes(Canvas canvas, Size size, double animAngle) {
    // Несколько блуждающих микро-спутников / звезд с мягким свечением
    final motes = [
      Offset(size.width * 0.10, size.height * 0.48),
      Offset(size.width * 0.28, size.height * 0.78),
      Offset(size.width * 0.88, size.height * 0.42),
      Offset(size.width * 0.42, size.height * 0.15),
      Offset(size.width * 0.68, size.height * 0.86),
    ];

    for (int i = 0; i < motes.length; i++) {
      final base = motes[i];
      final phase = animAngle + i * 1.3;
      final offset = Offset(
        base.dx + 6.0 * math.cos(phase),
        base.dy + 6.0 * math.sin(phase),
      );

      final pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(phase * 1.8));
      final moteColor = i.isEven ? accentColor : primaryColor;

      final moteGlow = Paint()
        ..color = moteColor.withValues(alpha: (isLight ? 0.18 : 0.30) * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(offset, 3.5, moteGlow);

      final moteCore = Paint()
        ..color = (isLight ? moteColor : Colors.white).withValues(alpha: (isLight ? 0.5 : 0.75) * pulse);
      canvas.drawCircle(offset, 1.8, moteCore);
    }
  }

  @override
  bool shouldRepaint(covariant CosmicPlanetsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isLight != isLight ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Пасмурная погода с дождем и каплями, стекающими по кругам-спутникам
/// для светлой темы "Спутники"
class RainyOvercastPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  RainyOvercastPainter({
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Мягкий пасмурный небесный градиент
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFCBD5E1), // Серый грозовой/пасмурный сизый
          Color(0xFFE2E8F0),
          Color(0xFFF1F5F9),
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Бледное тусклое солнце сквозь тучи
    final sunCenter = Offset(w * 0.78, h * 0.16);
    final sunGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFBEB).withValues(alpha: 0.55),
          const Color(0xFFFEF3C7).withValues(alpha: 0.25),
          const Color(0xFFF1F5F9).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 95));
    canvas.drawCircle(sunCenter, 95, sunGlowPaint);

    final sunCorePaint = Paint()
      ..color = const Color(0xFFFFFBEB).withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(sunCenter, 28, sunCorePaint);

    // 3. Плавные грозовые слоистые облака
    _drawOvercastClouds(canvas, size, progress);

    // 4. Непрерывный органичный дождь (капли падают под легким наклоном ветра)
    _drawRaindrops(canvas, size, progress);
  }

  void _drawOvercastClouds(Canvas canvas, Size size, double p) {
    final w = size.width;
    final h = size.height;

    final cloudPaint1 = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    final cloudPaint2 = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    // Верхняя гряда туч
    final shift1 = (p * 0.08) * w;
    for (int i = -1; i <= 3; i++) {
      final cx = (i * w * 0.45 + shift1) % (w * 1.5) - w * 0.25;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.09), width: w * 0.65, height: 110),
        cloudPaint1,
      );
    }

    // Средняя более темная дождевая полоса туч
    final shift2 = ((1.0 - p) * 0.05) * w;
    for (int i = -1; i <= 3; i++) {
      final cx = (i * w * 0.5 + shift2) % (w * 1.6) - w * 0.3;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.18), width: w * 0.75, height: 130),
        cloudPaint2,
      );
    }
  }

  void _drawRaindrops(Canvas canvas, Size size, double p) {
    final w = size.width;
    final h = size.height;

    final rainPaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.38)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final faintRainPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // 70 капель дождя с уникальными псевдослучайными сидами
    // Вычисляем y как ((seedY + p * speed) % 1.0) * h для полной непрерывности
    const int dropCount = 70;
    const double windDx = 14.0; // наклон ветра вправо
    const double dropLen = 22.0;

    for (int i = 0; i < dropCount; i++) {
      final seedX = ((i * 37.19 + 13.0) % 100.0) / 100.0;
      final seedY = ((i * 59.41 + 47.0) % 100.0) / 100.0;
      final speedMult = 0.8 + ((i * 17.3) % 10.0) / 10.0 * 0.7; // разная скорость
      final isFaint = (i % 3 == 0);

      final currentNormY = (seedY + p * 2.2 * speedMult) % 1.0;
      final x = seedX * w + (currentNormY * windDx);
      final y = currentNormY * (h + dropLen * 2) - dropLen;

      final pPaint = isFaint ? faintRainPaint : rainPaint;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + (windDx * (dropLen / h)), y + dropLen),
        pPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RainyOvercastPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
  }
}

/// Выделенный звездный космический фон с мерцающими созвездиями и туманностями
/// для темы "Космос" (работает в темной и светлой темах)
class StarryConstellationPainter extends CustomPainter {
  final double progress;
  final bool isLight;
  final Color accentColor;
  final int round;
  final int totalRounds;

  StarryConstellationPainter({
    required this.progress,
    required this.isLight,
    required this.accentColor,
    this.round = 1,
    this.totalRounds = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isLight) {
      // 1. Для светлой темы "Космос": фон - это чистое голубое небо, не закрашиваем его темнотой!
      // Добавляем лишь мягкие небесные сияния / полупрозрачные облачные переливы
      final skyGlowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      final glow1Center = Offset(
        w * 0.35 + math.sin(progress * 2 * math.pi) * 30,
        h * 0.25 + math.cos(progress * 2 * math.pi) * 20,
      );
      canvas.drawCircle(glow1Center, w * 0.45, skyGlowPaint);

      final skyGlowPaint2 = Paint()
        ..color = const Color(0xFF93C5FD).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
      final glow2Center = Offset(
        w * 0.70 + math.cos(progress * 2 * math.pi) * 25,
        h * 0.70 + math.sin(progress * 2 * math.pi) * 25,
      );
      canvas.drawCircle(glow2Center, w * 0.50, skyGlowPaint2);
    } else {
      // 1. Темная тема "Космос": глубокий космический градиент
      final baseColors = [
        const Color(0xFF030712),
        const Color(0xFF090D1A),
        const Color(0xFF02040A),
      ];

      final bgPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.25,
          colors: baseColors,
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

      // 2. Светящиеся космические туманности (Nebulae)
      final nebulaPaint1 = Paint()
        ..color = accentColor.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 75);
      final neb1Center = Offset(
        w * 0.3 + math.sin(progress * 2 * math.pi) * 25,
        h * 0.28 + math.cos(progress * 2 * math.pi) * 20,
      );
      canvas.drawCircle(neb1Center, w * 0.42, nebulaPaint1);

      final nebulaPaint2 = Paint()
        ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 85);
      final neb2Center = Offset(
        w * 0.72 + math.cos(progress * 2 * math.pi) * 30,
        h * 0.68 + math.sin(progress * 2 * math.pi) * 25,
      );
      canvas.drawCircle(neb2Center, w * 0.48, nebulaPaint2);
    }

    // 3. Созвездия: узлы со звездами и соединительными тонкими лучами, меняющиеся со временем и раундами
    _drawConstellations(canvas, size, progress);

    // 4. Мерцающие одиночные звезды с хаотичным расположением (~30% активно мерцают)
    _drawStarField(canvas, size, progress);
  }

  void _drawConstellations(Canvas canvas, Size size, double p) {
    final w = size.width;
    final h = size.height;

    // Библиотека созвездий (нормализованные координаты 0.0 - 1.0)
    final constellationPool = [
      // 0: Большая Медведица / Ковш (Ursa Major)
      [
        const Offset(0.12, 0.18),
        const Offset(0.24, 0.16),
        const Offset(0.32, 0.22),
        const Offset(0.40, 0.20),
        const Offset(0.46, 0.28),
        const Offset(0.34, 0.30),
        const Offset(0.32, 0.22),
      ],
      // 1: Кассиопея (W-образное)
      [
        const Offset(0.70, 0.14),
        const Offset(0.77, 0.20),
        const Offset(0.83, 0.13),
        const Offset(0.89, 0.21),
        const Offset(0.94, 0.16),
      ],
      // 2: Орион (Пояс и контур)
      [
        const Offset(0.15, 0.72),
        const Offset(0.28, 0.70),
        const Offset(0.23, 0.78),
        const Offset(0.20, 0.81),
        const Offset(0.17, 0.84),
        const Offset(0.12, 0.90),
        const Offset(0.26, 0.88),
      ],
      // 3: Лебедь / Северный Крест (Cygnus)
      [
        const Offset(0.72, 0.70),
        const Offset(0.82, 0.75),
        const Offset(0.90, 0.80),
        const Offset(0.78, 0.82),
        const Offset(0.82, 0.75),
        const Offset(0.84, 0.67),
      ],
      // 4: Пегас / Квадрат
      [
        const Offset(0.14, 0.22),
        const Offset(0.29, 0.18),
        const Offset(0.33, 0.29),
        const Offset(0.18, 0.32),
        const Offset(0.14, 0.22),
      ],
      // 5: Лира (Lyra) & Вега
      [
        const Offset(0.68, 0.72),
        const Offset(0.76, 0.69),
        const Offset(0.84, 0.73),
        const Offset(0.80, 0.82),
        const Offset(0.72, 0.81),
        const Offset(0.68, 0.72),
      ],
    ];

    // Выбираем созвездия в зависимости от текущего раунда и времени упражнения
    final cycleIdx = ((round - 1).clamp(0, 9999)) % (constellationPool.length ~/ 2);
    final groupTop = constellationPool[cycleIdx * 2];
    final groupBottom = constellationPool[cycleIdx * 2 + 1];

    final lineAlpha = (isLight ? 0.35 : 0.22) + 0.12 * math.sin(p * 2 * math.pi);
    final linePaint = Paint()
      ..color = (isLight ? const Color(0xFF0284C7) : const Color(0xFF93C5FD))
          .withValues(alpha: lineAlpha.clamp(0.15, 0.85))
      ..strokeWidth = isLight ? 1.4 : 1.15
      ..style = PaintingStyle.stroke;

    final starGlowPaint = Paint()
      ..color = (isLight ? const Color(0xFF38BDF8) : const Color(0xFFBAE6FD)).withValues(alpha: isLight ? 0.45 : 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final starCorePaint = Paint()
      ..color = isLight ? const Color(0xFF0C4A6E) : Colors.white
      ..style = PaintingStyle.fill;

    for (final group in [groupTop, groupBottom]) {
      // Соединительные линии
      for (int i = 0; i < group.length - 1; i++) {
        final p1 = Offset(group[i].dx * w, group[i].dy * h);
        final p2 = Offset(group[i + 1].dx * w, group[i + 1].dy * h);
        canvas.drawLine(p1, p2, linePaint);
      }

      // Звезды на вершинах созвездий с индивидуальным мерцанием
      for (int i = 0; i < group.length; i++) {
        final pt = Offset(group[i].dx * w, group[i].dy * h);
        final starPhase = (p * 2 * math.pi * 1.5) + (i * 1.3) + (round * 0.7);
        // ~30% звезд созвездия мерцают резко и ярко, остальные мягко пульсируют
        final bool isSharpSparkle = (i % 3 == 0);
        final double pulse = isSharpSparkle
            ? 1.0 + 0.65 * math.pow((0.5 + 0.5 * math.sin(starPhase * 2)), 3)
            : 1.0 + 0.25 * math.sin(starPhase);

        canvas.drawCircle(pt, 5.0 * pulse, starGlowPaint);
        canvas.drawCircle(pt, 2.2 * pulse, starCorePaint);

        // Яркие крестообразные лучи у ключевых мерцающих звезд созвездий
        if (isSharpSparkle && pulse > 1.3) {
          final beamPaint = Paint()
            ..color = (isLight ? const Color(0xFF0284C7) : const Color(0xFFE0F2FE))
                .withValues(alpha: (0.45 * (pulse - 1.0)).clamp(0.0, 1.0))
            ..strokeWidth = 0.8;
          final beam = 7.0 * pulse;
          canvas.drawLine(Offset(pt.dx - beam, pt.dy), Offset(pt.dx + beam, pt.dy), beamPaint);
          canvas.drawLine(Offset(pt.dx, pt.dy - beam), Offset(pt.dx, pt.dy + beam), beamPaint);
        }
      }
    }
  }

  void _drawStarField(Canvas canvas, Size size, double p) {
    final w = size.width;
    final h = size.height;

    final starPaint = Paint()..style = PaintingStyle.fill;

    // Псевдо-случайное, нелинейное распределение 120 звезд
    const int totalStars = 120;
    for (int i = 0; i < totalStars; i++) {
      // Псевдослучайный хэш для естественного хаотичного рассеивания
      final hashX = ((i * 173.371 + 31.7) * 23.917) % 1.0;
      final hashY = ((i * 281.923 + 67.3) * 41.139) % 1.0;

      final sx = hashX * w;
      final sy = hashY * h;

      // Около 30% звезд мерцают интенсивно и быстро (i % 3 == 0 или (i % 10 < 3))
      final bool isTwinkleStar = (i % 3 == 0);
      final double phase = (p * 2 * math.pi) * (isTwinkleStar ? 2.5 : 0.8) + (i * 1.7);

      double alpha;
      double radius;

      if (isTwinkleStar) {
        // Резкое мерцание с острым пиком яркости
        final twinkleVal = math.pow((0.5 + 0.5 * math.sin(phase)), 4);
        alpha = (0.2 + 0.78 * twinkleVal).clamp(0.05, 1.0);
        radius = 1.0 + 1.2 * twinkleVal;
      } else {
        // Мягкое фоновое дыхание остальных 70% звезд
        final calmVal = 0.5 + 0.5 * math.sin(phase);
        alpha = (0.25 + 0.45 * calmVal).clamp(0.15, 0.75);
        radius = 0.8 + ((i % 5 == 1) ? 0.6 : 0.2);
      }

      final starColor = isLight ? const Color(0xFF0369A1) : Colors.white;
      starPaint.color = starColor.withValues(alpha: (alpha * (isLight ? 0.85 : 1.0)).clamp(0.1, 1.0));
      canvas.drawCircle(Offset(sx, sy), radius, starPaint);

      // Алмазные лучики у самых ярких мерцающих звезд
      if (isTwinkleStar && (i % 7 == 0) && alpha > 0.65) {
        final crossPaint = Paint()
          ..color = (isLight ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD))
              .withValues(alpha: (alpha * 0.7).clamp(0.0, 1.0))
          ..strokeWidth = 0.85;
        final beamLen = 5.0 * (alpha / 0.8);
        canvas.drawLine(Offset(sx - beamLen, sy), Offset(sx + beamLen, sy), crossPaint);
        canvas.drawLine(Offset(sx, sy - beamLen), Offset(sx, sy + beamLen), crossPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarryConstellationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isLight != isLight ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.round != round ||
        oldDelegate.totalRounds != totalRounds;
  }
}
