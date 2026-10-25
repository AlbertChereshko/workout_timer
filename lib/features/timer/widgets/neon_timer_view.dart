import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../data/models/workout.dart';
import '../../../data/models/exercise_library.dart';
import '../../../services/recovery_analyzer.dart';
import '../../../domain/timer_state.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/music_service.dart';
import 'neon_ambient_background.dart';
import 'real_time_clock.dart';

/// Неоновый интерфейс таймера с чистой вертикальной иерархией
class NeonTimerView extends StatefulWidget {
  final Workout workout;
  final TimerState state;
  final double progress;
  final AppThemeConfig theme;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipPrevious;
  final VoidCallback onSkipNext;
  final VoidCallback onFinishEarly;
  final VoidCallback? onRecordAmrap;

  const NeonTimerView({
    super.key,
    required this.workout,
    required this.state,
    required this.progress,
    required this.theme,
    required this.onTogglePlayPause,
    required this.onSkipPrevious,
    required this.onSkipNext,
    required this.onFinishEarly,
    this.onRecordAmrap,
  });

  @override
  State<NeonTimerView> createState() => _NeonTimerViewState();
}

class _NeonTimerViewState extends State<NeonTimerView> with SingleTickerProviderStateMixin {
  bool _isOutlinedNumbers = false; // Переключение двойным тапом: сплошные белые vs контурные цифры
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.45, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getPhaseColor() {
    switch (widget.state.phase) {
      case TimerPhase.work:
        return widget.theme.workPhase;
      case TimerPhase.rest:
        return const Color(0xFF00E676);
      case TimerPhase.countdown:
        return widget.theme.countdownPhase;
      case TimerPhase.finished:
        return widget.theme.accent;
    }
  }

  Color _getNextPhaseColor() {
    switch (widget.state.phase) {
      case TimerPhase.work:
        return widget.workout.tabataRestSeconds > 0
            ? const Color(0xFF00E676)
            : widget.theme.workPhase;
      case TimerPhase.rest:
        return widget.theme.workPhase;
      case TimerPhase.countdown:
        return widget.theme.workPhase;
      case TimerPhase.finished:
        return widget.theme.accent;
    }
  }

  String _getCurrentExerciseTitle() {
    if (widget.state.phase == TimerPhase.finished) {
      return 'ТРЕНИРОВКА ЗАВЕРШЕНА';
    }
    if (widget.state.phase == TimerPhase.rest) {
      return 'ОТДЫХ';
    }
    if (widget.workout.type == WorkoutType.amrap) {
      if (widget.workout.exercises.isNotEmpty) {
        final curIdx = widget.state.currentExerciseIndex % widget.workout.exercises.length;
        return widget.workout.exercises[curIdx].name.toUpperCase();
      }
      return widget.workout.name.toUpperCase();
    }
    if (widget.workout.exercises.isNotEmpty) {
      final curIdx = (widget.state.currentRound - 1).clamp(0, 999999) % widget.workout.exercises.length;
      return widget.workout.exercises[curIdx].name.toUpperCase();
    }
    return widget.workout.name.isNotEmpty
        ? widget.workout.name.toUpperCase()
        : (widget.workout.type == WorkoutType.emom ? 'РАУНД ${widget.state.currentRound}' : 'РАБОТА');
  }

  String? _getNextExerciseTitle() {
    if (widget.state.phase == TimerPhase.finished) {
      return null;
    }

    if (widget.workout.type == WorkoutType.amrap) {
      if (widget.workout.exercises.length > 1) {
        final nextIdx = (widget.state.currentExerciseIndex + 1) % widget.workout.exercises.length;
        return widget.workout.exercises[nextIdx].name.toUpperCase();
      }
      return null;
    }

    final totalRounds = widget.state.totalRounds;
    final currentRound = widget.state.currentRound;
    final exercises = widget.workout.exercises;

    // Если текущий раунд равен или превышает общее количество раундов — показываем "КОНЕЦ ТРЕНИРОВКИ"
    if (currentRound >= totalRounds) {
      return 'КОНЕЦ ТРЕНИРОВКИ';
    }

    // Номер следующего раунда
    final int nextRoundNumber = widget.state.phase == TimerPhase.countdown
        ? (totalRounds > 1 ? 2 : 1)
        : (currentRound + 1);

    if (nextRoundNumber > totalRounds) {
      return 'КОНЕЦ ТРЕНИРОВКИ';
    }

    if (exercises.isNotEmpty) {
      final nextEx = exercises[(nextRoundNumber - 1) % exercises.length];
      return nextEx.name.toUpperCase();
    } else {
      return 'РАУНД $nextRoundNumber';
    }
  }

  String _getTotalRemainingFormatted() {
    if (widget.workout.type == WorkoutType.amrap) {
      final totalRemainingMins = widget.state.remainingSeconds ~/ 60;
      final totalRemainingSecs = widget.state.remainingSeconds % 60;
      return '${totalRemainingMins.toString().padLeft(2, '0')}:${totalRemainingSecs.toString().padLeft(2, '0')}';
    }

    int remainingTotalSeconds = widget.state.remainingSeconds;
    final int roundWorkTime = widget.workout.type == WorkoutType.emom
        ? widget.workout.emomRoundDurationSeconds
        : widget.workout.tabataWorkSeconds;
    final int roundRestTime = widget.workout.type == WorkoutType.emom
        ? 0
        : widget.workout.tabataRestSeconds;
    final int fullRoundDuration = roundWorkTime + roundRestTime;
    final int roundsRemaining = widget.state.totalRounds - widget.state.currentRound;

    if (widget.state.phase == TimerPhase.work) {
      remainingTotalSeconds += roundRestTime + (roundsRemaining * fullRoundDuration);
    } else if (widget.state.phase == TimerPhase.rest) {
      remainingTotalSeconds += (roundsRemaining * fullRoundDuration);
    } else if (widget.state.phase == TimerPhase.countdown) {
      remainingTotalSeconds += (widget.state.totalRounds * fullRoundDuration);
    } else {
      return '00:00';
    }

    if (remainingTotalSeconds < 0) remainingTotalSeconds = 0;
    final totalRemainingMins = remainingTotalSeconds ~/ 60;
    final totalRemainingSecs = remainingTotalSeconds % 60;
    return '${totalRemainingMins.toString().padLeft(2, '0')}:${totalRemainingSecs.toString().padLeft(2, '0')}';
  }

  void _handleScreenTap() {
    HapticFeedback.mediumImpact();
    widget.onTogglePlayPause();
  }

  void _openSmartSwapSheet(BuildContext context) {
    if (widget.workout.exercises.isEmpty) return;

    final curIdx = widget.workout.type == WorkoutType.amrap
        ? widget.state.currentExerciseIndex % widget.workout.exercises.length
        : (widget.state.currentRound - 1).clamp(0, 999999) % widget.workout.exercises.length;

    final currentExercise = widget.workout.exercises[curIdx];

    // Определение целевой группы мышц текущего упражнения
    const allDefs = ExerciseLibrary.catalog;
    final match = allDefs.where((d) => d.name.trim().toLowerCase() == currentExercise.name.trim().toLowerCase()).firstOrNull;
    final targetMuscle = match?.targetMuscle ?? MuscleGroup.upperBody;

    // Подбираем альтернативные упражнения
    final alternatives = allDefs.where((d) => d.name != currentExercise.name).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.theme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horizontal_circle_outlined, color: widget.theme.accent, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Заменить «${currentExercise.name}»',
                              style: TextStyle(color: widget.theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Альтернативы для зоны: ${targetMuscle.displayName}',
                              style: TextStyle(color: widget.theme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: alternatives.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final alt = alternatives[idx];
                      final isSameGroup = alt.targetMuscle == targetMuscle;

                      return InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            widget.workout.exercises[curIdx] = alt.toExercise();
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: widget.theme.surface,
                              content: Text('Упражнение заменено на «${alt.name}»!', style: TextStyle(color: widget.theme.accent)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSameGroup
                                ? widget.theme.accent.withValues(alpha: 0.1)
                                : widget.theme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSameGroup ? widget.theme.accent.withValues(alpha: 0.4) : widget.theme.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: alt.isStatic ? Colors.amber.withValues(alpha: 0.2) : widget.theme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  alt.isStatic ? 'СТАТИКА' : alt.targetMuscle.shortTag,
                                  style: TextStyle(
                                    color: alt.isStatic ? Colors.amberAccent : widget.theme.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alt.name,
                                      style: TextStyle(color: widget.theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      alt.equipment.displayName,
                                      style: TextStyle(color: widget.theme.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.theme.accent),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getPhaseColor();
    final nextPhaseColor = _getNextPhaseColor();
    final currentExerciseTitle = _getCurrentExerciseTitle();
    final nextTitle = _getNextExerciseTitle();
    final isLight = widget.theme.isLight;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _handleScreenTap();
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
            // 1. Динамический фон со свечением по бокам
            NeonAmbientBackground(
              phase: widget.state.phase,
              progress: widget.progress,
              theme: widget.theme,
              isRunning: widget.state.isRunning,
            ),

            // 2. Фоновый детектор нажатия на весь экран для старта/паузы
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleScreenTap,
              ),
            ),

            // 3. Основной интерфейс: адаптивный (портрет / ландшафт)
            isLandscape
                ? _buildLandscapeBody(
                    activeColor: activeColor,
                    nextPhaseColor: nextPhaseColor,
                    currentExerciseTitle: currentExerciseTitle,
                    nextTitle: nextTitle,
                    isLight: isLight,
                  )
                : SafeArea(
                    child: Column(
                      children: [
                        // ВЕРХНИЙ БЛОК: Кнопка назад + Часы + Текущее упражнение + Кнопка замены + Музыка
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Назад',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Часы
                              RealTimeClock(
                                textStyle: GoogleFonts.chakraPetch(
                                  fontSize: 52 * AppTypography.currentScale.activeDigitsScale,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.0,
                                  color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  shadows: [
                                    Shadow(
                                      color: activeColor.withValues(alpha: isLight ? 0.35 : 0.8),
                                      blurRadius: 28,
                                      offset: const Offset(0, 2),
                                    ),
                                    Shadow(
                                      color: activeColor.withValues(alpha: isLight ? 0.2 : 0.45),
                                      blurRadius: 44,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Текущее упражнение: в строго фиксированном по высоте контейнере с увеличенным весом и шрифтом
                              SizedBox(
                                height: 64 * AppTypography.currentScale.headingScale,
                                child: Center(
                                  child: Text(
                                    currentExerciseTitle,
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: _isOutlinedNumbers
                                        ? GoogleFonts.chakraPetch(
                                            fontSize: 28.0 * AppTypography.currentScale.headingScale,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                            height: 1.15,
                                            foreground: Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 2.0
                                              ..color = (widget.state.phase == TimerPhase.rest
                                                  ? const Color(0xFF00E676)
                                                  : (isLight ? const Color(0xFF0A0F1D) : Colors.white)),
                                          )
                                        : GoogleFonts.chakraPetch(
                                            fontSize: 28.0 * AppTypography.currentScale.headingScale,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                            height: 1.15,
                                            color: widget.state.phase == TimerPhase.rest
                                                ? const Color(0xFF00E676)
                                                : (isLight ? const Color(0xFF0A0F1D) : Colors.white),
                                            shadows: [
                                              Shadow(
                                                color: (widget.state.phase == TimerPhase.rest
                                                        ? const Color(0xFF00E676)
                                                        : (isLight ? Colors.transparent : Colors.white))
                                                    .withValues(alpha: isLight ? 0.35 : 0.6),
                                                blurRadius: 28,
                                                offset: const Offset(0, 2),
                                              ),
                                              Shadow(
                                                color: (widget.state.phase == TimerPhase.rest
                                                        ? const Color(0xFF00E676)
                                                        : activeColor)
                                                    .withValues(alpha: isLight ? 0.2 : 0.45),
                                                blurRadius: 44,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Кнопка быстрой замены упражнения строго под названием (на месте прежнего общего времени)
                              if (widget.workout.exercises.isNotEmpty)
                                Tooltip(
                                  message: 'Заменить упражнение на лету',
                                  child: InkWell(
                                    onTap: () => _openSmartSwapSheet(context),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: (widget.state.phase == TimerPhase.rest
                                                ? const Color(0xFF00E676)
                                                : activeColor)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: (widget.state.phase == TimerPhase.rest
                                                  ? const Color(0xFF00E676)
                                                  : activeColor)
                                              .withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 20,
                                        color: widget.state.phase == TimerPhase.rest
                                            ? const Color(0xFF00E676)
                                            : (isLight ? const Color(0xFF0A0F1D) : Colors.white),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 32),
                            ],
                          ),
                        ),
                        // Кнопка выбора музыкального приложения (Spotify / YouTube Music)
                        _buildTopIconButton(
                          icon: Icons.music_note_rounded,
                          tooltip: 'Музыка',
                          onTap: () => MusicService.showMusicPickerSheet(context, widget.theme),
                        ),
                      ],
                    ),
                  ),

                  // Равномерный отступ
                  const Spacer(),

                  // ЦЕНТРАЛЬНЫЙ БЛОК: Обратный отсчет + Общее время тренировки + Кнопка плей/паузы
                  // Фиксированная геометрия: цифры отсчета НЕ двигаются при смене упражнения или длине названия
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleScreenTap,
                    onDoubleTap: () {
                      setState(() {
                        _isOutlinedNumbers = !_isOutlinedNumbers;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Фиксированный блок гигантских цифр отсчета (с динамическим круговым индикатором интервала для EMOM)
                        SizedBox(
                          height: (widget.workout.type == WorkoutType.emom ? 186.0 : 144.0) * AppTypography.currentScale.timerScale,
                          width: (widget.workout.type == WorkoutType.emom ? 186.0 : 200.0) * AppTypography.currentScale.timerScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (widget.workout.type == WorkoutType.emom) ...[
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: (widget.state.remainingSeconds / (widget.workout.emomRoundDurationSeconds > 0 ? widget.workout.emomRoundDurationSeconds.toDouble() : 60.0)).clamp(0.0, 1.0),
                                    strokeWidth: 4.5,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: activeColor.withValues(alpha: isLight ? 0.12 : 0.18),
                                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                                  ),
                                ),
                              ],
                              Center(
                                child: Text(
                                  '${widget.state.remainingSeconds}',
                                  style: _isOutlinedNumbers
                                      ? GoogleFonts.chakraPetch(
                                          fontSize: (widget.workout.type == WorkoutType.emom ? 116 : 148) * AppTypography.currentScale.timerScale,
                                          fontWeight: FontWeight.w800,
                                          height: 0.95,
                                          letterSpacing: widget.workout.type == WorkoutType.emom ? 4.0 : 8.0,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          foreground: Paint()
                                            ..style = PaintingStyle.stroke
                                            ..strokeWidth = 4.0
                                            ..color = activeColor,
                                        )
                                      : GoogleFonts.chakraPetch(
                                          fontSize: (widget.workout.type == WorkoutType.emom ? 116 : 148) * AppTypography.currentScale.timerScale,
                                          fontWeight: FontWeight.w800,
                                          height: 0.95,
                                          letterSpacing: widget.workout.type == WorkoutType.emom ? 4.0 : 8.0,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: activeColor.withValues(alpha: isLight ? 0.25 : 0.5),
                                              blurRadius: 28,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 2. Общее оставшееся время тренировки (строго под центральным таймером 60)
                        Text(
                          widget.state.phase == TimerPhase.finished
                              ? '00:00'
                              : _getTotalRemainingFormatted(),
                          style: GoogleFonts.chakraPetch(
                            fontSize: 32 * AppTypography.currentScale.activeDigitsScale,
                            fontWeight: FontWeight.w800,
                            color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                            letterSpacing: 2.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: activeColor.withValues(alpha: isLight ? 0.35 : 0.8),
                                blurRadius: 20,
                              ),
                              Shadow(
                                color: activeColor.withValues(alpha: isLight ? 0.2 : 0.45),
                                blurRadius: 36,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 3. Фиксированная кнопка Воспроизведение / Пауза (всегда доступна под таймером)
                        SizedBox(
                          height: 52,
                          child: Center(
                            child: _buildYouTubePlayButton(activeColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Равномерный отступ
                  const Spacer(),

                  // БЛОК СЛЕДУЮЩЕГО УПРАЖНЕНИЯ: Без прямоугольника, без секунд, тонкий увеличенный шрифт со стрелкой ↑
                  if (nextTitle != null)
                    _buildNextExerciseDisplay(
                      title: nextTitle,
                      nextPhaseColor: nextPhaseColor,
                    )
                  else
                    const SizedBox(height: 32),

                  // Равномерный отступ
                  const Spacer(),

                  // НИЖНЯЯ СТРОКА УПРАВЛЕНИЯ: AMRAP кнопка подсчета либо (⏮  Раунд 3/8  ⏭)
                  if (widget.workout.type == WorkoutType.amrap) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRoundCounter(activeColor),
                          const SizedBox(height: 12),
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
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildControlCircleButton(
                            icon: Icons.skip_previous_rounded,
                            tooltip: 'Предыдущий раунд',
                            onTap: widget.onSkipPrevious,
                          ),
                          _buildRoundCounter(activeColor),
                          _buildControlCircleButton(
                            icon: Icons.skip_next_rounded,
                            tooltip: 'Следующий раунд',
                            onTap: widget.onSkipNext,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeBody({
    required Color activeColor,
    required Color nextPhaseColor,
    required String currentExerciseTitle,
    required String? nextTitle,
    required bool isLight,
  }) {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column (flex: 5): Back, RealTimeClock, Music, Prominent Neon Exercise Card, Bottom Bar
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar
                  Row(
                    children: [
                      _buildTopIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Назад',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      RealTimeClock(
                        textStyle: GoogleFonts.chakraPetch(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(
                              color: activeColor.withValues(alpha: isLight ? 0.35 : 0.8),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildTopIconButton(
                        icon: Icons.music_note_rounded,
                        tooltip: 'Музыка',
                        onTap: () => MusicService.showMusicPickerSheet(context, widget.theme),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Prominent Neon Exercise Card (modeled after AMRAP card)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isLight
                            ? widget.theme.surface
                            : const Color(0xFF0F1626).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: activeColor.withValues(alpha: isLight ? 0.5 : 0.7),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: isLight ? 0.15 : 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.state.phase == TimerPhase.work
                                    ? '🔥 РАБОТА'
                                    : (widget.state.phase == TimerPhase.rest
                                        ? '🧘 ОТДЫХ'
                                        : (widget.state.phase == TimerPhase.countdown
                                            ? '⏳ ПРИГОТОВИТЬСЯ'
                                            : 'ТЕКУЩЕЕ УПРАЖНЕНИЕ')),
                                style: GoogleFonts.chakraPetch(
                                  color: activeColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              if (widget.workout.exercises.isNotEmpty)
                                Tooltip(
                                  message: 'Заменить упражнение',
                                  child: InkWell(
                                    onTap: () => _openSmartSwapSheet(context),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: activeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: activeColor.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 16,
                                        color: activeColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              currentExerciseTitle,
                              style: GoogleFonts.chakraPetch(
                                fontSize: 34.0 * AppTypography.currentScale.headingScale,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                letterSpacing: 1.2,
                                color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                                shadows: [
                                  Shadow(
                                    color: activeColor.withValues(alpha: isLight ? 0.25 : 0.5),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                            ),
                          ),
                          if (nextTitle != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '↑ $nextTitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.chakraPetch(
                                color: isLight ? const Color(0xFF64748B) : Colors.white70,
                                fontSize: 16.0 * AppTypography.currentScale.bodyScale,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom row: Remaining Time badge & Round pill in matching theme styles (2x font, no finish button)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isLight
                              ? widget.theme.surface
                              : const Color(0xFF0F1626).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: activeColor.withValues(alpha: isLight ? 0.6 : 0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withValues(alpha: isLight ? 0.1 : 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⏳', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              widget.state.phase == TimerPhase.finished
                                  ? '00:00'
                                  : _getTotalRemainingFormatted(),
                              style: GoogleFonts.chakraPetch(
                                color: activeColor,
                                fontSize: 20 * AppTypography.currentScale.activeDigitsScale,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isLight
                              ? widget.theme.surface
                              : const Color(0xFF0F1626).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (isLight ? const Color(0xFF6366F1) : const Color(0xFF818CF8)).withValues(alpha: isLight ? 0.6 : 0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isLight ? const Color(0xFF6366F1) : const Color(0xFF818CF8)).withValues(alpha: isLight ? 0.1 : 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 18,
                              color: isLight ? const Color(0xFF4F46E5) : const Color(0xFFA5B4FC),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'РАУНД ${widget.state.currentRound}/${widget.state.totalRounds}',
                              style: GoogleFonts.chakraPetch(
                                color: isLight ? const Color(0xFF4338CA) : const Color(0xFFA5B4FC),
                                fontSize: 20 * AppTypography.currentScale.activeDigitsScale,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Column (flex: 4): Circular Progress Ring with giant neon digits + YouTube Play/Pause and Controls
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, ringConstraints) {
                          final ringDiameter = (ringConstraints.maxHeight - 16).clamp(150.0, 220.0);
                          final fontSize = (ringDiameter * 0.42) * AppTypography.currentScale.timerScale;
                          return GestureDetector(
                            onTap: _handleScreenTap,
                            onDoubleTap: () {
                              setState(() {
                                _isOutlinedNumbers = !_isOutlinedNumbers;
                              });
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: ringDiameter,
                                  height: ringDiameter,
                                  child: CircularProgressIndicator(
                                    value: widget.workout.type == WorkoutType.emom
                                        ? (widget.state.remainingSeconds / (widget.workout.emomRoundDurationSeconds > 0 ? widget.workout.emomRoundDurationSeconds.toDouble() : 60.0)).clamp(0.0, 1.0)
                                        : widget.progress.clamp(0.0, 1.0),
                                    strokeWidth: 9,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: activeColor.withValues(alpha: isLight ? 0.12 : 0.18),
                                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                                  ),
                                ),
                                Text(
                                  '${widget.state.remainingSeconds}',
                                  style: _isOutlinedNumbers
                                      ? GoogleFonts.chakraPetch(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w800,
                                          height: 0.95,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          foreground: Paint()
                                            ..style = PaintingStyle.stroke
                                            ..strokeWidth = 3.5
                                            ..color = activeColor,
                                        )
                                      : GoogleFonts.chakraPetch(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w800,
                                          height: 0.95,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: activeColor.withValues(alpha: isLight ? 0.35 : 0.6),
                                              blurRadius: 24,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (widget.workout.type == WorkoutType.amrap) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildYouTubePlayButton(activeColor),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: Icon(
                            widget.workout.amrapCountByRounds ? Icons.add_circle_outline_rounded : Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            widget.workout.amrapCountByRounds ? '+1 Раунд' : 'След. упр.',
                            style: GoogleFonts.chakraPetch(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          onPressed: widget.onRecordAmrap,
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlCircleButton(
                          icon: Icons.skip_previous_rounded,
                          tooltip: 'Предыдущий раунд',
                          onTap: widget.onSkipPrevious,
                        ),
                        const SizedBox(width: 14),
                        _buildYouTubePlayButton(activeColor),
                        const SizedBox(width: 14),
                        _buildControlCircleButton(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Следующий раунд',
                          onTap: widget.onSkipNext,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isLight = widget.theme.isLight;
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLight
                  ? Colors.black.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubePlayButton(Color badgeColor) {
    final isFinished = widget.state.phase == TimerPhase.finished;
    final isLight = widget.theme.isLight;
    final IconData badgeIcon = isFinished ? Icons.replay_rounded : Icons.play_arrow_rounded;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glow = _glowAnimation.value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleScreenTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: badgeColor.withValues(alpha: 0.3),
            highlightColor: badgeColor.withValues(alpha: 0.15),
            child: Container(
              width: 76,
              height: 48,
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF0E1424).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: badgeColor.withValues(alpha: isLight ? 0.75 : glow),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: isLight ? 0.25 : glow * 0.5),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                  if (!isLight)
                    BoxShadow(
                      color: badgeColor.withValues(alpha: glow * 0.25),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(left: isFinished ? 0.0 : 3.0),
                  child: Icon(
                    badgeIcon,
                    color: badgeColor,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextExerciseDisplay({
    required String title,
    required Color nextPhaseColor,
  }) {
    final isLight = widget.theme.isLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          '↑ $title',
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 26 * AppTypography.currentScale.bodyScale,
            fontWeight: FontWeight.w400,
            color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: nextPhaseColor.withValues(alpha: isLight ? 0.25 : 0.45),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundCounter(Color activeColor) {
    final isLight = widget.theme.isLight;
    final isAmrap = widget.workout.type == WorkoutType.amrap;
    final roundText = isAmrap
        ? (widget.state.extraReps > 0
            ? '${widget.state.currentRound} + ${widget.state.extraReps}'
            : '${widget.state.currentRound}')
        : '${widget.state.currentRound}/${widget.state.totalRounds}';

    // 80% от размера высоты текущего времени вверху экрана (52 * activeDigitsScale * 0.8 ≈ 41.6)
    final clockFontSize = 52.0 * AppTypography.currentScale.activeDigitsScale;
    final roundFontSize = clockFontSize * 0.8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF0F1626).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: activeColor.withValues(alpha: isLight ? 0.35 : 0.55),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: isLight ? 0.15 : 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        roundText,
        style: GoogleFonts.chakraPetch(
          fontSize: roundFontSize,
          fontWeight: FontWeight.w800,
          color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
          letterSpacing: 2.0,
          height: 1.1,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [
            Shadow(
              color: activeColor.withValues(alpha: isLight ? 0.25 : 0.65),
              blurRadius: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isLight = widget.theme.isLight;
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(26),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0F1626).withValues(alpha: 0.85),
              border: Border.all(
                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isLight ? const Color(0xFF0A0F1D) : Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
