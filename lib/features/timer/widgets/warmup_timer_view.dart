import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../../../data/models/workout.dart';
import '../../../domain/timer_state.dart';
import '../../../services/warmup_service.dart';

class WarmupTimerView extends StatelessWidget {
  final Workout workout;
  final TimerState state;
  final AppThemeConfig theme;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipWarmup;
  final VoidCallback onSkipExercise;
  final VoidCallback onFinishEarly;

  const WarmupTimerView({
    super.key,
    required this.workout,
    required this.state,
    required this.theme,
    required this.onTogglePlayPause,
    required this.onSkipWarmup,
    required this.onSkipExercise,
    required this.onFinishEarly,
  });

  @override
  Widget build(BuildContext context) {
    final exercises = WarmupService.getExercisesForDuration(state.totalPhaseSeconds);
    final totalExercises = exercises.isNotEmpty ? exercises.length : 1;
    final currentIndex = state.currentExerciseIndex.clamp(0, totalExercises - 1);
    final currentEx = exercises.isNotEmpty
        ? exercises[currentIndex]
        : const WarmupExercise(
            title: 'Суставная разминка',
            description: 'Плавные круговые движения для разогрева суставов и связок.',
            backProtectionTip: 'Держите спину ровной и дышите спокойно.',
            icon: Icons.accessibility_rounded,
          );

    final elapsed = (state.totalPhaseSeconds - state.remainingSeconds).clamp(0, state.totalPhaseSeconds);
    final secInCurrentEx = (30 - (elapsed % 30));
    final exProgress = (30 - secInCurrentEx) / 30.0;

    final totalMin = state.remainingSeconds ~/ 60;
    final totalSec = state.remainingSeconds % 60;
    final totalTimeStr = '${totalMin.toString().padLeft(2, '0')}:${totalSec.toString().padLeft(2, '0')}';

    const accentAmber = Color(0xFFFFB300);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            return Column(
              children: [
                // Top Bar (Responsive, no overflow)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onFinishEarly();
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accentAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accentAmber.withValues(alpha: 0.45)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_rounded, size: 14, color: accentAmber),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'РАЗОГРЕВ СПИНЫ (${state.totalPhaseSeconds ~/ 60} МИН)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: accentAmber,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onSkipWarmup();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Пропустить',
                              style: TextStyle(
                                color: accentAmber,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.skip_next_rounded, size: 16, color: accentAmber),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress Dots
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: List.generate(totalExercises, (index) {
                      final isDone = index < currentIndex;
                      final isCurrent = index == currentIndex;
                      return Expanded(
                        child: Container(
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: isDone
                                ? accentAmber
                                : (isCurrent ? accentAmber.withValues(alpha: 0.8) : theme.cardBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 6),

                // Main Body: Portrait vs Landscape
                Expanded(
                  child: isLandscape
                      ? _buildLandscapeLayout(
                          context,
                          theme,
                          accentAmber,
                          currentEx,
                          currentIndex,
                          totalExercises,
                          secInCurrentEx,
                          exProgress,
                          totalTimeStr,
                        )
                      : _buildPortraitLayout(
                          context,
                          theme,
                          accentAmber,
                          currentEx,
                          currentIndex,
                          totalExercises,
                          secInCurrentEx,
                          exProgress,
                          totalTimeStr,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // PORTRAIT LAYOUT
  Widget _buildPortraitLayout(
    BuildContext context,
    AppThemeConfig theme,
    Color accentAmber,
    WarmupExercise currentEx,
    int currentIndex,
    int totalExercises,
    int secInCurrentEx,
    double exProgress,
    String totalTimeStr,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isShortScreen = availableHeight < 560;
        final circleSize = isShortScreen ? 140.0 : 180.0;

        return Column(
          children: [
            // Exercise index label
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'УПРАЖНЕНИЕ ${currentIndex + 1} ИЗ $totalExercises',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Circular exercise timer
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: circleSize,
                    height: circleSize,
                    child: CircularProgressIndicator(
                      value: exProgress.clamp(0.0, 1.0),
                      strokeWidth: isShortScreen ? 7 : 9,
                      backgroundColor: theme.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(accentAmber),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currentEx.icon, size: isShortScreen ? 28 : 36, color: accentAmber),
                      const SizedBox(height: 4),
                      Text(
                        '$secInCurrentEx',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: isShortScreen ? 40 : 50,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'секунд',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Total remaining time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.cardBorder),
              ),
              child: Text(
                'Всего в разминке: $totalTimeStr',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Exercise Title and Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    currentEx.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: isShortScreen ? 17 : 19,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentEx.description,
                    textAlign: TextAlign.center,
                    maxLines: isShortScreen ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Spine & Joint Protection Tip Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accentAmber.withValues(alpha: theme.isLight ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentAmber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.health_and_safety_rounded, color: accentAmber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ЗАЩИТА СПИНЫ И СУСТАВОВ',
                            style: TextStyle(
                              color: accentAmber,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            currentEx.backProtectionTip,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Controls Bar (Play/Pause, Next Exercise, Skip)
            _buildControlsBar(theme, accentAmber),
          ],
        );
      },
    );
  }

  // LANDSCAPE LAYOUT
  Widget _buildLandscapeLayout(
    BuildContext context,
    AppThemeConfig theme,
    Color accentAmber,
    WarmupExercise currentEx,
    int currentIndex,
    int totalExercises,
    int secInCurrentEx,
    double exProgress,
    String totalTimeStr,
  ) {
    return Row(
      children: [
        // Left Column: Timer & Controls
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'УПР. ${currentIndex + 1} ИЗ $totalExercises',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: exProgress.clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: theme.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(accentAmber),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currentEx.icon, size: 24, color: accentAmber),
                      Text(
                        '$secInCurrentEx',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'сек',
                        style: TextStyle(color: theme.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Осталось: $totalTimeStr',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              // Compact controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: onSkipExercise,
                    tooltip: 'След. упр.',
                    icon: Icon(Icons.arrow_forward_rounded, color: theme.textPrimary, size: 22),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      onTogglePlayPause();
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accentAmber,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentAmber.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 32,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onSkipWarmup,
                    tooltip: 'К тренировке',
                    icon: Icon(Icons.fast_forward_rounded, color: theme.textPrimary, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right Column: Scrollable Exercise Details
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  currentEx.title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentEx.description,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentAmber.withValues(alpha: theme.isLight ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentAmber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.health_and_safety_rounded, color: accentAmber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ЗАЩИТА СПИНЫ И СУСТАВОВ',
                              style: TextStyle(
                                color: accentAmber,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentEx.backProtectionTip,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsBar(AppThemeConfig theme, Color accentAmber) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Next exercise button (Expanded with FittedBox)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onSkipExercise();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 16, color: theme.textPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'След. упр.',
                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Main Play / Pause Button
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              onTogglePlayPause();
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accentAmber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentAmber.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 34,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Skip to main workout button (Expanded with FittedBox)
          Expanded(
            child: FilledButton.tonal(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onSkipWarmup();
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.surface,
                foregroundColor: theme.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.cardBorder),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('К тренировке →', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
