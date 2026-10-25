import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/timer_state.dart';
import '../../domain/emom_timer_notifier.dart';
import '../../data/models/workout.dart';
import '../../data/models/workout_session.dart';
import '../../core/theme.dart';
import '../../core/theme/app_typography.dart';
import 'animated_background.dart';
import 'widgets/neon_timer_view.dart';
import 'widgets/cosmic_timer_view.dart';
import 'widgets/amrap_flow_timer_view.dart';
import 'widgets/neon_ambient_background.dart';
import 'widgets/real_time_clock.dart';
import '../../core/typography_scale_provider.dart';
import '../history/history_screen.dart';
import '../../data/repositories/history_repository.dart';
import '../../services/music_service.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/athlete_profile.dart';
import '../../services/calorie_calculator.dart';
import 'widgets/ai_coach_feedback_card.dart';
import 'widgets/volume_control_sheet.dart';

class TimerScreen extends ConsumerStatefulWidget {
  final Workout workout;
  
  const TimerScreen({super.key, required this.workout});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeTimerProvider.notifier).loadWorkout(widget.workout);
    });
  }

  void _confirmExit(BuildContext context, AppThemeConfig currentTheme) {
    final notifier = ref.read(activeTimerProvider.notifier);
    notifier.pause();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: currentTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n?.finishEarly ?? 'Завершить тренировку?',
          style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Вы хотите сохранить результат в историю и оставить заметку или выйти без сохранения?',
          style: TextStyle(color: currentTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.resume();
            },
            child: Text(l10n?.resume ?? 'Продолжить', style: TextStyle(color: currentTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.invalidate(historyProvider);
              Navigator.pop(context);
            },
            child: Text('Выйти без сохранения', style: TextStyle(color: Colors.redAccent.shade100)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentTheme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.finishEarly();
            },
            child: const Text('Сохранить результат', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeTimerProvider);
    final currentTheme = ref.watch(appThemeProvider);
    final scaleConfig = ref.watch(typographyScaleProvider);
    
    if (state.phase == TimerPhase.finished) {
      return _buildSummaryScreen(context, ref, currentTheme, scaleConfig);
    }
    
    final progress = state.totalPhaseSeconds > 0 
        ? state.remainingSeconds / state.totalPhaseSeconds 
        : 0.0;

    // Определяем стиль таймера согласно виду тренировки:
    // AMRAP -> Спутники (Satellites)
    // EMOM -> Неон (Neon)
    // TABATA -> Круг (Circular)
    final effectiveTimerStyle = widget.workout.type == WorkoutType.amrap
        ? TimerStyle.satellites
        : (widget.workout.type == WorkoutType.emom
            ? TimerStyle.neon
            : TimerStyle.circular);

    Widget currentBody;

    // Режим 1: Неоновый таймер (Option 2) - для EMOM
    if (effectiveTimerStyle == TimerStyle.neon) {
      currentBody = NeonTimerView(
        workout: widget.workout,
        state: state,
        progress: progress,
        theme: currentTheme,
        onTogglePlayPause: () => ref.read(activeTimerProvider.notifier).toggle(),
        onSkipPrevious: () => ref.read(activeTimerProvider.notifier).skipPrevious(),
        onSkipNext: () => ref.read(activeTimerProvider.notifier).skipNext(),
        onFinishEarly: () => _confirmExit(context, currentTheme),
        onRecordAmrap: () {
          if (widget.workout.amrapCountByRounds) {
            ref.read(activeTimerProvider.notifier).recordAmrapRound();
          } else {
            ref.read(activeTimerProvider.notifier).recordAmrapExercise();
          }
        },
      );
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _confirmExit(context, currentTheme);
          }
        },
        child: currentBody,
      );
    }

    // Режим 2: Космический сливовый с орбитальным диском
    if (effectiveTimerStyle == TimerStyle.cosmic) {
      currentBody = CosmicTimerView(
        workout: widget.workout,
        state: state,
        progress: progress,
        scaleConfig: scaleConfig,
        theme: currentTheme,
        initialShowSatellites: false,
        onTogglePlayPause: () => ref.read(activeTimerProvider.notifier).toggle(),
        onSkipPrevious: () => ref.read(activeTimerProvider.notifier).skipPrevious(),
        onSkipNext: () => ref.read(activeTimerProvider.notifier).skipNext(),
        onReset: () => ref.read(activeTimerProvider.notifier).restart(),
        onFinishEarly: () => _confirmExit(context, currentTheme),
        onRecordAmrap: () {
          if (widget.workout.amrapCountByRounds) {
            ref.read(activeTimerProvider.notifier).recordAmrapRound();
          } else {
            ref.read(activeTimerProvider.notifier).recordAmrapExercise();
          }
        },
      );
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _confirmExit(context, currentTheme);
          }
        },
        child: currentBody,
      );
    }

    // Режим 3: Таймер AMRAP (AmrapFlowTimerView по новому неоновому дизайну)
    if (effectiveTimerStyle == TimerStyle.satellites) {
      currentBody = AmrapFlowTimerView(
        workout: widget.workout,
        state: state,
        progress: progress,
        theme: currentTheme,
        onTogglePlayPause: () => ref.read(activeTimerProvider.notifier).toggle(),
        onFinishEarly: () => _confirmExit(context, currentTheme),
        onRecordAmrap: () {
          ref.read(activeTimerProvider.notifier).recordAmrapExercise();
        },
      );
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _confirmExit(context, currentTheme);
          }
        },
        child: currentBody,
      );
    }
        
    Exercise? currentExerciseObj;
    String? currentExercise;
    String? nextExerciseName;
    final bool isAmrap = widget.workout.type == WorkoutType.amrap;
    final bool isRestPhase = !isAmrap && state.phase == TimerPhase.rest && state.currentRound < state.totalRounds;
    if (widget.workout.exercises.isNotEmpty) {
      if (isAmrap) {
        final curIdx = state.currentExerciseIndex % widget.workout.exercises.length;
        final nextIdx = (state.currentExerciseIndex + 1) % widget.workout.exercises.length;
        currentExerciseObj = widget.workout.exercises[curIdx];
        currentExercise = currentExerciseObj.name;
        nextExerciseName = widget.workout.exercises[nextIdx].name;
      } else {
        final index = (state.currentRound - 1) % widget.workout.exercises.length;
        final nextIndex = state.currentRound % widget.workout.exercises.length;
        
        final activeIndex = isRestPhase ? nextIndex : index;
        currentExerciseObj = widget.workout.exercises[activeIndex];
        currentExercise = currentExerciseObj.name;

        if (state.currentRound >= state.totalRounds) {
          nextExerciseName = 'Конец тренировки';
        } else {
          nextExerciseName = widget.workout.exercises[nextIndex].name;
        }
      }
    } else {
      nextExerciseName = isAmrap
          ? ''
          : (state.currentRound >= state.totalRounds
              ? 'Конец тренировки'
              : 'Раунд ${state.currentRound + 1}');
    }

    // Расчёт общего оставшегося времени до конца всей тренировки
    int remainingTotalSeconds = state.remainingSeconds;
    if (!isAmrap) {
      final int roundWorkTime = widget.workout.type == WorkoutType.emom 
          ? widget.workout.emomRoundDurationSeconds 
          : widget.workout.tabataWorkSeconds;
      final int roundRestTime = widget.workout.type == WorkoutType.emom 
          ? 0 
          : widget.workout.tabataRestSeconds;
      final int fullRoundDuration = roundWorkTime + roundRestTime;
      final int roundsRemaining = state.totalRounds - state.currentRound;

      if (state.phase == TimerPhase.work) {
        remainingTotalSeconds += roundRestTime + (roundsRemaining * fullRoundDuration);
      } else if (state.phase == TimerPhase.rest) {
        remainingTotalSeconds += (roundsRemaining * fullRoundDuration);
      } else {
        remainingTotalSeconds += (state.totalRounds * fullRoundDuration);
      }
    }
    final totalRemainingMins = remainingTotalSeconds ~/ 60;
    final totalRemainingSecs = remainingTotalSeconds % 60;
    final totalRemainingFormatted =
        '${totalRemainingMins.toString().padLeft(2, '0')}:${totalRemainingSecs.toString().padLeft(2, '0')}';
    
    final l10n = AppLocalizations.of(context);
    final animationKey = ValueKey('${state.phase}_${state.currentRound}_${state.currentExerciseIndex}');

    String? exerciseTargetText;
    if (currentExerciseObj != null) {
      if (!widget.workout.tags.contains('Статика') && currentExerciseObj.reps != null && currentExerciseObj.reps! > 0) {
        exerciseTargetText = '🔁 ${currentExerciseObj.reps} ${l10n?.repsUpper ?? 'ПОВТ'}';
      } else if (currentExerciseObj.durationSeconds != null && currentExerciseObj.durationSeconds! > 0) {
        exerciseTargetText = '⏱ ${currentExerciseObj.durationSeconds} ${l10n?.secUpper ?? 'СЕК'}';
      }
    }
    final int defaultRoundWorkTime = widget.workout.type == WorkoutType.emom
        ? widget.workout.emomRoundDurationSeconds
        : (widget.workout.type == WorkoutType.amrap
            ? widget.workout.amrapDurationSeconds
            : widget.workout.tabataWorkSeconds);
    if (exerciseTargetText == null && defaultRoundWorkTime > 0) {
      exerciseTargetText = '⏱ $defaultRoundWorkTime ${l10n?.secUpper ?? 'СЕК'}';
    }

    final isTabata = widget.workout.type == WorkoutType.tabata;
    final int totalEx = widget.workout.exercises.isNotEmpty
        ? widget.workout.exercises.length
        : state.totalRounds;
    final int currentEx = widget.workout.exercises.isNotEmpty
        ? ((state.currentRound - 1) % totalEx) + 1
        : state.currentRound;

    Color phaseColor;
    if (state.phase == TimerPhase.countdown) {
      phaseColor = const Color(0xFFF59E0B);
    } else if (state.phase == TimerPhase.work) {
      phaseColor = currentTheme.accent;
    } else {
      phaseColor = const Color(0xFF06B6D4);
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final circularScaffold = Scaffold(
      backgroundColor: currentTheme.background,
      body: Stack(
        children: [
          KeyedSubtree(
            key: animationKey,
            child: AnimatedBackground(
              phase: state.phase,
              progress: progress.clamp(0.0, 1.0),
              theme: currentTheme,
            ),
          ),
          SafeArea(
            child: isLandscape
                ? _buildLandscapeTimerBody(
                    context: context,
                    ref: ref,
                    currentTheme: currentTheme,
                    scaleConfig: scaleConfig,
                    state: state,
                    progress: progress,
                    animationKey: animationKey,
                    currentExercise: currentExercise,
                    exerciseTargetText: exerciseTargetText,
                    nextExerciseName: nextExerciseName,
                    totalRemainingFormatted: totalRemainingFormatted,
                    phaseColor: phaseColor,
                    isAmrap: isAmrap,
                    l10n: l10n,
                  )
                : Column(
              children: [
                // Top control bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary),
                                tooltip: 'Главный экран',
                                onPressed: () => _confirmExit(context, currentTheme),
                              ),
                              const SizedBox(width: 48), // Balances the two right action buttons so clock is centered
                            ],
                          ),
                          // Wall clock - увеличенные часы (39pt как в Спутниках)
                          Expanded(
                            child: Center(
                              child: RealTimeClock(
                                fontSize: 39,
                                color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                                scale: scaleConfig.activeDigitsScale,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Кнопка громкости приложения и тренера
                              IconButton(
                                icon: Icon(
                                  Icons.volume_up_rounded,
                                  color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary,
                                ),
                                tooltip: 'Громкость тренера',
                                onPressed: () => VolumeControlSheet.show(context, currentTheme),
                              ),
                              // Кнопка выбора музыкального приложения (Spotify / YouTube Music)
                              IconButton(
                                icon: Icon(Icons.music_note_rounded, color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary),
                                tooltip: 'Музыка',
                                onPressed: () => MusicService.showMusicPickerSheet(context, currentTheme),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Общее время тренировки строго по центру под часами (для всех режимов кроме Табата)
                      if (!isTabata)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: currentTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: currentTheme.accent.withValues(alpha: currentTheme.isLight ? 0.8 : 0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: currentTheme.accent.withValues(alpha: currentTheme.isLight ? 0.16 : 0.3),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('⏳', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                totalRemainingFormatted,
                                style: AppTypography.timerDisplay(
                                  color: currentTheme.accent,
                                  fontSize: 34 * scaleConfig.activeDigitsScale, // +30% от 26 (26 * 1.3 ≈ 34)
                                  letterSpacing: 2.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                Spacer(flex: isTabata ? 3 : 2),
                
                // Exercise Name НАД кругом
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: currentExercise != null
                      ? Text(
                          currentExercise.toUpperCase(),
                          style: AppTypography.exerciseTitle(
                            color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                            fontSize: 28.0 * scaleConfig.headingScale,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.normal,
                          ),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        )
                      : const SizedBox.shrink(),
                ),
                
                Spacer(flex: isTabata ? 2 : 1),

                // Center: Увеличенный круг секунд (диаметр 256px, чистый таймер отсчета без слов)
                Center(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(activeTimerProvider.notifier).toggle();
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 256,
                          height: 256,
                          child: TweenAnimationBuilder<double>(
                            key: animationKey,
                            duration: state.isRunning ? const Duration(milliseconds: 1000) : Duration.zero,
                            curve: Curves.linear,
                            tween: Tween<double>(begin: progress, end: progress),
                            builder: (context, value, _) {
                              return CircularProgressIndicator(
                                value: value,
                                strokeWidth: 13,
                                backgroundColor: currentTheme.isLight
                                    ? const Color(0xFFE2E8F0)
                                    : currentTheme.cardBorder,
                                color: phaseColor,
                              );
                            },
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${state.remainingSeconds}',
                              style: AppTypography.timerDisplay(
                                color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                                fontSize: 92 * scaleConfig.activeDigitsScale,
                                letterSpacing: 4.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                Spacer(flex: isTabata ? 2 : 1),
                
                // Следующее упражнение ПОД кругом со стрелочкой ↑ (резервируем высоту для центровки)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Opacity(
                    opacity: nextExerciseName.isNotEmpty ? 1.0 : 0.0,
                    child: Text(
                      '↑ ${(nextExerciseName.isNotEmpty ? nextExerciseName : " ").toUpperCase()}',
                      style: AppTypography.exerciseTitle(
                        color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                        fontSize: 24.0 * scaleConfig.bodyScale,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // В режиме Табата: общее время тренировки под кругом
                if (isTabata) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: currentTheme.accent.withValues(alpha: currentTheme.isLight ? 0.8 : 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentTheme.accent.withValues(alpha: currentTheme.isLight ? 0.16 : 0.3),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('⏳', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          totalRemainingFormatted,
                          style: AppTypography.timerDisplay(
                            color: currentTheme.accent,
                            fontSize: 34 * scaleConfig.activeDigitsScale,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalEx > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentTheme.isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: phaseColor.withValues(alpha: currentTheme.isLight ? 0.4 : 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${l10n?.round ?? "Раунд"} $currentEx/$totalEx',
                        style: GoogleFonts.chakraPetch(
                          color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                          fontSize: 24 * scaleConfig.activeDigitsScale, // на 20% меньше (было 30, стало 24)
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
                
                Spacer(flex: isTabata ? 3 : 2),
                
                // Controls Row: Prev Round, Play/Pause, Next Round (or AMRAP action button)
                if (isAmrap) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          '${l10n?.score ?? "Результат"}: ${state.currentRound} ${l10n?.rounds ?? "раундов"}${state.extraReps > 0 ? " + ${state.extraReps} ${l10n?.repsShort ?? "повт."}" : ""}',
                          style: TextStyle(
                            color: currentTheme.accent,
                            fontSize: 18 * scaleConfig.headingScale,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 6,
                            ),
                            icon: Icon(
                              widget.workout.amrapCountByRounds ? Icons.add_circle_outline_rounded : Icons.check_circle_outline_rounded,
                              size: 26,
                            ),
                            label: Text(
                              widget.workout.amrapCountByRounds
                                  ? '+1 ${l10n?.addRound ?? "Раунд"}'
                                  : (l10n?.nextExercise ?? 'След. упражнение'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            onPressed: () {
                              if (widget.workout.amrapCountByRounds) {
                                ref.read(activeTimerProvider.notifier).recordAmrapRound();
                              } else {
                                ref.read(activeTimerProvider.notifier).recordAmrapExercise();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        heroTag: 'timer_btn',
                        backgroundColor: currentTheme.isLight ? currentTheme.accent : Colors.white,
                        elevation: 6,
                        onPressed: () => ref.read(activeTimerProvider.notifier).toggle(),
                        child: Icon(
                          state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: currentTheme.isLight ? Colors.white : Colors.black,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ] else if (isTabata) ...[
                  // В режиме ТАБАТА нижние кнопки и "Завершить досрочно" скрыты по запросу пользователя.
                  // Тап по кругу ставит на паузу/возобновляет, стрелка назад завершает сессию.
                  const SizedBox.shrink(),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 40,
                        icon: Icon(Icons.skip_previous_rounded, color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary),
                        tooltip: l10n?.prevRoundTooltip ?? 'Предыдущий раунд / сброс',
                        onPressed: () => ref.read(activeTimerProvider.notifier).skipPrevious(),
                      ),
                      const SizedBox(width: 24),
                      FloatingActionButton.large(
                        heroTag: 'timer_btn',
                        backgroundColor: currentTheme.isLight ? currentTheme.accent : Colors.white,
                        elevation: 8,
                        onPressed: () => ref.read(activeTimerProvider.notifier).toggle(),
                        child: Icon(
                          state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: currentTheme.isLight ? Colors.white : Colors.black,
                          size: 48,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 40,
                        icon: Icon(Icons.skip_next_rounded, color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary),
                        tooltip: l10n?.nextRoundTooltip ?? 'Следующий раунд',
                        onPressed: () => ref.read(activeTimerProvider.notifier).skipNext(),
                      ),
                    ],
                  ),
                ],
                if (!isTabata) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _confirmExit(context, currentTheme),
                    child: Text(
                      l10n?.finishEarly ?? 'Завершить досрочно',
                      style: TextStyle(
                        color: currentTheme.isLight ? const Color(0xFF475569) : currentTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmExit(context, currentTheme);
        }
      },
      child: circularScaffold,
    );
  }

  Widget _buildLandscapeTimerBody({
    required BuildContext context,
    required WidgetRef ref,
    required AppThemeConfig currentTheme,
    required TypographyScaleConfig scaleConfig,
    required TimerState state,
    required double progress,
    required Key animationKey,
    required String? currentExercise,
    required String? exerciseTargetText,
    required String nextExerciseName,
    required String totalRemainingFormatted,
    required Color phaseColor,
    required bool isAmrap,
    required AppLocalizations? l10n,
  }) {
    final isTabata = widget.workout.type == WorkoutType.tabata;
    final int totalEx = widget.workout.exercises.isNotEmpty
        ? widget.workout.exercises.length
        : state.totalRounds;
    final int currentEx = widget.workout.exercises.isNotEmpty
        ? ((state.currentRound - 1) % totalEx) + 1
        : state.currentRound;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Navigation, Wall Clock, Exercise Names, Remaining Time, Round
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary,
                      ),
                      tooltip: 'Главный экран',
                      onPressed: () => _confirmExit(context, currentTheme),
                    ),
                    const SizedBox(width: 8),
                    RealTimeClock(
                      fontSize: 26,
                      color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                      scale: scaleConfig.activeDigitsScale,
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.volume_up_rounded,
                        color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary,
                      ),
                      tooltip: 'Громкость тренера',
                      onPressed: () => VolumeControlSheet.show(context, currentTheme),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.music_note_rounded,
                        color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary,
                      ),
                      tooltip: 'Музыка',
                      onPressed: () => MusicService.showMusicPickerSheet(context, currentTheme),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Prominent Current Exercise Card (modeled after AMRAP card)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: currentTheme.isLight
                          ? currentTheme.surface
                          : currentTheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: phaseColor.withValues(alpha: currentTheme.isLight ? 0.6 : 0.8),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: phaseColor.withValues(alpha: currentTheme.isLight ? 0.15 : 0.3),
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
                              state.phase == TimerPhase.work
                                  ? '🔥 РАБОТА'
                                  : (state.phase == TimerPhase.rest
                                      ? '🧘 ОТДЫХ'
                                      : (state.phase == TimerPhase.countdown
                                          ? '⏳ ПРИГОТОВИТЬСЯ'
                                          : 'ТЕКУЩЕЕ УПРАЖНЕНИЕ')),
                              style: TextStyle(
                                color: phaseColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Spacer(),
                            if (exerciseTargetText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: phaseColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: phaseColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  exerciseTargetText,
                                  style: TextStyle(
                                    color: phaseColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
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
                            (currentExercise ?? (state.phase == TimerPhase.rest ? 'ОТДЫХ' : 'РАБОТА')).toUpperCase(),
                            style: AppTypography.exerciseTitle(
                              color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                              fontSize: 34.0 * scaleConfig.headingScale,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 2,
                          ),
                        ),
                        if (nextExerciseName.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: currentTheme.isLight ? const Color(0xFF64748B) : currentTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'СЛЕД.: ${nextExerciseName.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: currentTheme.isLight ? const Color(0xFF64748B) : currentTheme.textSecondary,
                                    fontSize: 16.0 * scaleConfig.bodyScale,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: currentTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: currentTheme.accent.withValues(alpha: currentTheme.isLight ? 0.8 : 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⏳', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(
                            totalRemainingFormatted,
                            style: AppTypography.timerDisplay(
                              color: currentTheme.accent,
                              fontSize: 20 * scaleConfig.activeDigitsScale,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!isAmrap)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: currentTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (currentTheme.isLight ? const Color(0xFF6366F1) : const Color(0xFF818CF8))
                                .withValues(alpha: currentTheme.isLight ? 0.8 : 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 18,
                              color: currentTheme.isLight ? const Color(0xFF4F46E5) : const Color(0xFFA5B4FC),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${l10n?.round ?? "Раунд"} ${state.currentRound}/${state.totalRounds}',
                              style: TextStyle(
                                color: currentTheme.isLight ? const Color(0xFF4338CA) : const Color(0xFFA5B4FC),
                                fontSize: 20 * scaleConfig.activeDigitsScale,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
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

        // Right Column: Scaled Circular Progress Indicator + Controls
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
                        final fontSize = (ringDiameter * 0.38) * scaleConfig.activeDigitsScale;
                        return GestureDetector(
                          onTap: () => ref.read(activeTimerProvider.notifier).toggle(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: ringDiameter,
                                height: ringDiameter,
                                child: TweenAnimationBuilder<double>(
                                  key: animationKey,
                                  duration: state.isRunning ? const Duration(milliseconds: 1000) : Duration.zero,
                                  curve: Curves.linear,
                                  tween: Tween<double>(begin: progress, end: progress),
                                  builder: (context, value, _) {
                                    return CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: 9,
                                      backgroundColor: currentTheme.isLight
                                          ? const Color(0xFFE2E8F0)
                                          : currentTheme.cardBorder,
                                      color: phaseColor,
                                    );
                                  },
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${state.remainingSeconds}',
                                    style: AppTypography.timerDisplay(
                                      color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                                      fontSize: (isTabata ? fontSize * 0.85 : fontSize),
                                      letterSpacing: isTabata ? 2.5 : 4.0,
                                    ),
                                  ),
                                  if (isTabata) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: currentTheme.isLight
                                            ? Colors.black.withValues(alpha: 0.05)
                                            : Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: phaseColor.withValues(alpha: currentTheme.isLight ? 0.4 : 0.6),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        '${l10n?.round ?? "Раунд"} $currentEx/$totalEx',
                                        style: GoogleFonts.chakraPetch(
                                          color: currentTheme.isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary,
                                          fontSize: 22 * scaleConfig.activeDigitsScale,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (isAmrap) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'timer_btn_land',
                        backgroundColor: currentTheme.isLight ? currentTheme.accent : Colors.white,
                        onPressed: () => ref.read(activeTimerProvider.notifier).toggle(),
                        child: Icon(
                          state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: currentTheme.isLight ? Colors.white : Colors.black,
                          size: 24,
                        ),
                      ),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          if (widget.workout.amrapCountByRounds) {
                            ref.read(activeTimerProvider.notifier).recordAmrapRound();
                          } else {
                            ref.read(activeTimerProvider.notifier).recordAmrapExercise();
                          }
                        },
                      ),
                    ],
                  ),
                ] else if (isTabata) ...[
                  // В режиме ТАБАТА нижние кнопки скрыты
                  const SizedBox.shrink(),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 30,
                        icon: Icon(Icons.skip_previous_rounded,
                            color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary),
                        tooltip: l10n?.prevRoundTooltip ?? 'Предыдущий раунд / сброс',
                        onPressed: () => ref.read(activeTimerProvider.notifier).skipPrevious(),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'timer_btn_land',
                        backgroundColor: currentTheme.isLight ? currentTheme.accent : Colors.white,
                        elevation: 4,
                        onPressed: () => ref.read(activeTimerProvider.notifier).toggle(),
                        child: Icon(
                          state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: currentTheme.isLight ? Colors.white : Colors.black,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        iconSize: 30,
                        icon: Icon(Icons.skip_next_rounded,
                            color: currentTheme.isLight ? const Color(0xFF334155) : currentTheme.textSecondary),
                        tooltip: l10n?.nextRoundTooltip ?? 'Следующий раунд',
                        onPressed: () => ref.read(activeTimerProvider.notifier).skipNext(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryScreen(
    BuildContext context,
    WidgetRef ref,
    AppThemeConfig currentTheme,
    TypographyScaleConfig scaleConfig,
  ) {
    final notifier = ref.read(activeTimerProvider.notifier);
    final session = notifier.lastSession;
    final l10n = AppLocalizations.of(context);

    final duration = session?.finishedAt?.difference(session.startedAt) ?? Duration.zero;
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    final minUnit = l10n?.minShort ?? 'мин';
    final secUnit = l10n?.secShort ?? 'сек';
    final timeStr = '$mins$minUnit $secs$secUnit';

    final isAmrap = widget.workout.type == WorkoutType.amrap;
    final String roundsStr;
    if (isAmrap) {
      final completed = session?.completedRounds ?? 0;
      final extra = session?.extraReps ?? 0;
      if (extra > 0) {
        roundsStr = '$completed + $extra';
      } else {
        roundsStr = '$completed';
      }
    } else {
      roundsStr = '${session?.completedRounds ?? 0}/${session?.totalRounds ?? 0}';
    }

    final athleteProfile = ref.watch(athleteProfileProvider);
    final durationSec = duration.inSeconds;
    final calories = CalorieCalculator.calculateCaloriesBurned(
      type: widget.workout.type,
      tags: widget.workout.tags,
      durationSeconds: durationSec > 0 ? durationSec : 60,
      weightKg: athleteProfile.weightKg,
      fitnessLevel: athleteProfile.fitnessLevel,
    );

    switch (currentTheme.timerStyle) {
      case TimerStyle.neon:
        return _buildNeonSummaryScreen(context, ref, currentTheme, session, timeStr, roundsStr, calories, durationSec, scaleConfig, l10n);
      case TimerStyle.cosmic:
      case TimerStyle.satellites:
        return _buildCosmicSummaryScreen(context, ref, currentTheme, session, timeStr, roundsStr, calories, durationSec, scaleConfig, l10n);
      case TimerStyle.circular:
        return _buildClassicSummaryScreen(context, ref, currentTheme, session, timeStr, roundsStr, calories, durationSec, scaleConfig, l10n);
    }
  }

  Widget _buildNeonSummaryScreen(
    BuildContext context,
    WidgetRef ref,
    AppThemeConfig currentTheme,
    WorkoutSession? session,
    String timeStr,
    String roundsStr,
    int calories,
    int durationSec,
    TypographyScaleConfig scaleConfig,
    AppLocalizations? l10n,
  ) {
    final isLight = currentTheme.isLight;
    final bgColor = isLight ? currentTheme.background : const Color(0xFF060911);
    final cardColor = isLight ? currentTheme.surface : const Color(0xFF0B1422).withValues(alpha: 0.9);
    final primaryTextColor = isLight ? const Color(0xFF0A0F1D) : Colors.white;
    final accentColor = currentTheme.accent;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          NeonAmbientBackground(
            theme: currentTheme,
            phase: TimerPhase.finished,
            progress: 1.0,
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  // Неоновый победный кубок
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 78,
                    color: accentColor,
                    shadows: [
                      Shadow(
                        color: accentColor.withValues(alpha: isLight ? 0.35 : 0.95),
                        blurRadius: isLight ? 14 : 30,
                      ),
                      if (!isLight)
                        Shadow(
                          color: accentColor.withValues(alpha: 0.5),
                          blurRadius: 48,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 1. Поздравительная кибер-неоновая плитка завершения тренировки
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: accentColor,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: isLight ? 0.15 : 0.35),
                          blurRadius: 18,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ПОЗДРАВЛЯЕМ!',
                          style: GoogleFonts.inter(
                            fontSize: 16 * scaleConfig.headingScale,
                            fontWeight: FontWeight.w800,
                            color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '«${widget.workout.name.toUpperCase()}»',
                          style: GoogleFonts.inter(
                            fontSize: 20 * scaleConfig.headingScale,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                            letterSpacing: 1.5,
                            shadows: isLight
                                ? null
                                : [
                                    Shadow(
                                      color: accentColor.withValues(alpha: 0.8),
                                      blurRadius: 16,
                                    ),
                                  ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'завершена успешно! ⚡',
                          style: GoogleFonts.inter(
                            fontSize: 14 * scaleConfig.bodyScale,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Отдельные адаптивные плитки статистики в неоновом стиле
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 20) / 3;
                      const minItemWidth = 100.0;
                      final useThreeCols = itemWidth >= minItemWidth;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildNeonStatTile(
                            label: (l10n?.timeLabel ?? 'Время').toUpperCase(),
                            value: timeStr,
                            icon: Icons.timer_outlined,
                            width: useThreeCols ? itemWidth : (constraints.maxWidth - 10) / 2,
                            cardColor: cardColor,
                            borderColor: isLight ? currentTheme.cardBorder : const Color(0xFF00D4FF),
                            scaleConfig: scaleConfig,
                            isLight: isLight,
                          ),
                          _buildNeonStatTile(
                            label: (l10n?.rounds ?? 'Раундов').toUpperCase(),
                            value: roundsStr,
                            icon: Icons.repeat_rounded,
                            width: useThreeCols ? itemWidth : (constraints.maxWidth - 10) / 2,
                            cardColor: cardColor,
                            borderColor: isLight ? currentTheme.cardBorder : const Color(0xFF00D4FF),
                            scaleConfig: scaleConfig,
                            isLight: isLight,
                          ),
                          _buildNeonStatTile(
                            label: 'КАЛОРИИ',
                            value: '🔥$calories',
                            icon: Icons.local_fire_department_rounded,
                            width: useThreeCols ? itemWidth : constraints.maxWidth,
                            cardColor: cardColor,
                            borderColor: isLight ? currentTheme.cardBorder : const Color(0xFF00D4FF),
                            scaleConfig: scaleConfig,
                            isLight: isLight,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // AI Тренер совет и рекомендации
                  AiCoachFeedbackCard(
                    workoutName: widget.workout.name,
                    type: widget.workout.type,
                    durationSeconds: durationSec > 0 ? durationSec : 60,
                    caloriesBurned: calories,
                    completedRounds: session?.completedRounds ?? 0,
                    tags: widget.workout.tags,
                    theme: currentTheme,
                    userNote: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
                  ),

                  const SizedBox(height: 12),

                  // Поле комментария
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLight ? currentTheme.cardBorder : const Color(0xFF00D4FF).withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: l10n?.addCommentHint ?? 'Заметки о самочувствии...',
                        hintStyle: GoogleFonts.inter(
                          color: isLight ? currentTheme.textSecondary : Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Неоновая контурная кнопка "Сохранить и выйти" с ореолом
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isLight ? 0.08 : 0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: accentColor,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: isLight ? 0.35 : 0.65),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          if (session != null) {
                            final noteText = _commentController.text.trim();
                            session.note = noteText.isNotEmpty ? noteText : null;
                            await ref.read(historyRepositoryProvider).saveSession(session);
                          }
                          ref.invalidate(historyProvider);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          l10n?.saveAndExit ?? 'Сохранить и выйти',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 18 * scaleConfig.bodyScale,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCosmicSummaryScreen(
    BuildContext context,
    WidgetRef ref,
    AppThemeConfig currentTheme,
    WorkoutSession? session,
    String timeStr,
    String roundsStr,
    int calories,
    int durationSec,
    TypographyScaleConfig scaleConfig,
    AppLocalizations? l10n,
  ) {
    final isLight = currentTheme.isLight;
    final isCosmic = currentTheme.timerStyle == TimerStyle.cosmic;
    final isSatellites = currentTheme.timerStyle == TimerStyle.satellites;

    final bgColor = isLight ? currentTheme.background : const Color(0xFF130924);
    final cardColor = isLight 
        ? currentTheme.surface.withValues(alpha: 0.92) 
        : const Color(0xFF1E1038).withValues(alpha: 0.88);
    final primaryTextColor = isLight ? const Color(0xFF0A0F1D) : Colors.white;
    final secondaryTextColor = isLight ? const Color(0xFF334155) : const Color(0xFFA78BFA);
    final accentColor = currentTheme.accent;
    final borderColor = isLight ? currentTheme.cardBorder : const Color(0xFF8B5CF6).withValues(alpha: 0.35);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Анимированный тематический фон под стиль темы
          Positioned.fill(
            child: IgnorePointer(
              child: Builder(
                builder: (context) {
                  if (isCosmic) {
                    return CustomPaint(
                      painter: StarryConstellationPainter(
                        progress: 0.5,
                        isLight: isLight,
                        accentColor: accentColor,
                      ),
                    );
                  }
                  if (isSatellites && isLight) {
                    return CustomPaint(
                      painter: RainyOvercastPainter(
                        progress: 0.5,
                        accentColor: accentColor,
                      ),
                    );
                  }
                  return CustomPaint(
                    painter: CosmicPlanetsPainter(
                      progress: 0.5,
                      isLight: isLight,
                      primaryColor: const Color(0xFF7C3AED),
                      accentColor: accentColor,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Основное содержимое в SafeArea
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  // Верхняя панель: кнопка выхода / назад и Live часы
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: borderColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Center(
                          child: RealTimeClock(
                            fontSize: 32,
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            scale: scaleConfig.activeDigitsScale,
                          ),
                        ),
                      ),
                      const SizedBox(width: 44), // симметрия для центрирования часов
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Тематический кубок
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 80,
                    color: accentColor,
                    shadows: [
                      Shadow(
                        color: accentColor.withValues(alpha: isLight ? 0.4 : 0.8),
                        blurRadius: isLight ? 16 : 26,
                      ),
                      if (!isLight)
                        Shadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                          blurRadius: 40,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1. Поздравительная плитка завершения тренировки
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: accentColor.withValues(alpha: isLight ? 0.35 : 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: isLight ? 0.10 : 0.25),
                          blurRadius: 18,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ПОЗДРАВЛЯЕМ!',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 16 * scaleConfig.headingScale,
                            fontWeight: FontWeight.w700,
                            color: secondaryTextColor,
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '«${widget.workout.name}»',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 22 * scaleConfig.headingScale,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            letterSpacing: 1.0,
                            shadows: isLight
                                ? null
                                : [
                                    Shadow(
                                      color: accentColor.withValues(alpha: 0.7),
                                      blurRadius: 14,
                                    ),
                                  ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'завершена успешно! 🎉',
                          style: GoogleFonts.inter(
                            fontSize: 14 * scaleConfig.bodyScale,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Отдельные адаптивные плитки статистики (Время, Раунды, Калории)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 20) / 3;
                      const minItemWidth = 100.0;
                      final useThreeCols = itemWidth >= minItemWidth;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildCosmicStatTile(
                            label: (l10n?.timeLabel ?? 'Время').toUpperCase(),
                            value: timeStr,
                            icon: Icons.timer_outlined,
                            width: useThreeCols ? itemWidth : (constraints.maxWidth - 10) / 2,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            scaleConfig: scaleConfig,
                            secondaryTextColor: secondaryTextColor,
                            isLight: isLight,
                          ),
                          _buildCosmicStatTile(
                            label: (l10n?.rounds ?? 'Раундов').toUpperCase(),
                            value: roundsStr,
                            icon: Icons.repeat_rounded,
                            width: useThreeCols ? itemWidth : (constraints.maxWidth - 10) / 2,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            scaleConfig: scaleConfig,
                            secondaryTextColor: secondaryTextColor,
                            isLight: isLight,
                          ),
                          _buildCosmicStatTile(
                            label: 'КАЛОРИИ',
                            value: '🔥$calories',
                            icon: Icons.local_fire_department_rounded,
                            width: useThreeCols ? itemWidth : constraints.maxWidth,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            scaleConfig: scaleConfig,
                            secondaryTextColor: secondaryTextColor,
                            isLight: isLight,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // AI Тренер совет и рекомендации
                  AiCoachFeedbackCard(
                    workoutName: widget.workout.name,
                    type: widget.workout.type,
                    durationSeconds: durationSec > 0 ? durationSec : 60,
                    caloriesBurned: calories,
                    completedRounds: session?.completedRounds ?? 0,
                    tags: widget.workout.tags,
                    theme: currentTheme,
                    userNote: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
                  ),

                  const SizedBox(height: 12),

                  // Поле комментария
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: l10n?.addCommentHint ?? 'Добавить комментарий или заметку...',
                        hintStyle: GoogleFonts.inter(
                          color: secondaryTextColor.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Неоновая контурная кнопка сохранения с ореолом
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isLight ? 0.08 : 0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: accentColor,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: isLight ? 0.35 : 0.65),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          if (session != null) {
                            final noteText = _commentController.text.trim();
                            session.note = noteText.isNotEmpty ? noteText : null;
                            await ref.read(historyRepositoryProvider).saveSession(session);
                          }
                          ref.invalidate(historyProvider);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          l10n?.saveAndExit ?? 'Сохранить и выйти',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 18 * scaleConfig.bodyScale,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicSummaryScreen(
    BuildContext context,
    WidgetRef ref,
    AppThemeConfig currentTheme,
    WorkoutSession? session,
    String timeStr,
    String roundsStr,
    int calories,
    int durationSec,
    TypographyScaleConfig scaleConfig,
    AppLocalizations? l10n,
  ) {
    final isLight = currentTheme.isLight;
    final primaryTextColor = isLight ? const Color(0xFF0A0F1D) : currentTheme.textPrimary;
    final secondaryTextColor = isLight ? const Color(0xFF334155) : currentTheme.textSecondary;

    return Scaffold(
      backgroundColor: currentTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Icon(Icons.emoji_events_rounded, size: 84, color: currentTheme.accent),
              const SizedBox(height: 16),
              // 1. Поздравительная плитка завершения тренировки
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: currentTheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isLight
                        ? currentTheme.accent.withValues(alpha: 0.45)
                        : currentTheme.cardBorder,
                    width: 1.5,
                  ),
                  boxShadow: isLight
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      'ПОЗДРАВЛЯЕМ!',
                      style: TextStyle(
                        fontSize: 16 * scaleConfig.headingScale,
                        fontWeight: FontWeight.w800,
                        color: secondaryTextColor,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '«${widget.workout.name}»',
                      style: TextStyle(
                        fontSize: 20 * scaleConfig.headingScale,
                        fontWeight: FontWeight.w900,
                        color: currentTheme.accent,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'завершена успешно! 🏆',
                      style: TextStyle(
                        fontSize: 14 * scaleConfig.bodyScale,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Отдельные адаптивные плитки статистики
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 20) / 3;
                  const minItemWidth = 100.0;
                  final useThreeCols = itemWidth >= minItemWidth;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildClassicStatTile(
                        label: l10n?.timeLabel ?? 'Время',
                        value: timeStr,
                        icon: Icons.timer_outlined,
                        width: useThreeCols ? itemWidth : (constraints.maxWidth - 10) / 2,
                        currentTheme: currentTheme,
                        scaleConfig: scaleConfig,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        isLight: isLight,
                      ),
                      _buildClassicStatTile(
                        label: l10n?.rounds ?? 'Раунды',
                        value: roundsStr,
                        icon: Icons.repeat_rounded,
                        width: useThreeCols ? itemWidth : (constraints.maxWidth - 10) / 2,
                        currentTheme: currentTheme,
                        scaleConfig: scaleConfig,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        isLight: isLight,
                      ),
                      _buildClassicStatTile(
                        label: 'Калории',
                        value: '🔥$calories',
                        icon: Icons.local_fire_department_rounded,
                        width: useThreeCols ? itemWidth : constraints.maxWidth,
                        currentTheme: currentTheme,
                        scaleConfig: scaleConfig,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        isLight: isLight,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),

              // AI Тренер совет и рекомендации
              AiCoachFeedbackCard(
                workoutName: widget.workout.name,
                type: widget.workout.type,
                durationSeconds: durationSec > 0 ? durationSec : 60,
                caloriesBurned: calories,
                completedRounds: session?.completedRounds ?? 0,
                tags: widget.workout.tags,
                theme: currentTheme,
                userNote: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
              ),

              const SizedBox(height: 12),

              // Comment box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: currentTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLight ? const Color(0xFF94A3B8) : currentTheme.cardBorder,
                    width: isLight ? 1.5 : 1.0,
                  ),
                  boxShadow: isLight
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n?.addCommentHint ?? 'Добавить комментарий или заметку...',
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button (Современная контурная кнопка с ореолом свечения)
              SizedBox(
                width: double.infinity,
                height: 58,
                child: Container(
                  decoration: BoxDecoration(
                    color: currentTheme.accent.withValues(alpha: isLight ? 0.08 : 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: currentTheme.accent,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentTheme.accent.withValues(alpha: isLight ? 0.35 : 0.65),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      if (session != null) {
                        final noteText = _commentController.text.trim();
                        session.note = noteText.isNotEmpty ? noteText : null;
                        await ref.read(historyRepositoryProvider).saveSession(session);
                      }
                      ref.invalidate(historyProvider);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      l10n?.saveAndExit ?? 'Сохранить и выйти',
                      style: TextStyle(
                        fontSize: 18 * scaleConfig.bodyScale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeonStatTile({
    required String label,
    required String value,
    required IconData icon,
    required double width,
    required Color cardColor,
    required Color borderColor,
    required TypographyScaleConfig scaleConfig,
    required bool isLight,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor.withValues(alpha: isLight ? 0.6 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withValues(alpha: isLight ? 0.08 : 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14 * scaleConfig.bodyScale,
                color: const Color(0xFF00D4FF),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isLight ? const Color(0xFF475569) : Colors.white70,
                    fontSize: 11 * scaleConfig.bodyScale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.chakraPetch(
                color: const Color(0xFF00D4FF),
                fontSize: 22 * scaleConfig.activeDigitsScale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: isLight
                    ? null
                    : const [
                        Shadow(color: Color(0xFF00D4FF), blurRadius: 14),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCosmicStatTile({
    required String label,
    required String value,
    required IconData icon,
    required double width,
    required Color accentColor,
    required Color cardColor,
    required Color borderColor,
    required TypographyScaleConfig scaleConfig,
    required Color secondaryTextColor,
    required bool isLight,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isLight ? 0.08 : 0.18),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14 * scaleConfig.bodyScale,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: 11 * scaleConfig.bodyScale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.chakraPetch(
                color: accentColor,
                fontSize: 22 * scaleConfig.activeDigitsScale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: isLight
                    ? null
                    : [
                        Shadow(color: accentColor.withValues(alpha: 0.7), blurRadius: 12),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicStatTile({
    required String label,
    required String value,
    required IconData icon,
    required double width,
    required AppThemeConfig currentTheme,
    required TypographyScaleConfig scaleConfig,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isLight,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight ? currentTheme.cardBorder : currentTheme.cardBorder.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14 * scaleConfig.bodyScale,
                color: currentTheme.accent,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 11 * scaleConfig.bodyScale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: currentTheme.accent,
                fontSize: 22 * scaleConfig.activeDigitsScale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

