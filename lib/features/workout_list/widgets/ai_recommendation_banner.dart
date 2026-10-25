import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../data/models/athlete_profile.dart';
import '../../../data/models/workout.dart';
import '../../../data/models/workout_session.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../services/gemini_coach_service.dart';
import '../../../services/recovery_analyzer.dart';
import '../../profile/athlete_profile_dialog.dart';
import '../../timer/timer_screen.dart';
import '../../workout_generator/ai_workout_generator_dialog.dart';

class AiRecommendationBanner extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry? margin;
  const AiRecommendationBanner({super.key, this.margin});

  @override
  ConsumerState<AiRecommendationBanner> createState() => _AiRecommendationBannerState();
}

class _AiRecommendationBannerState extends ConsumerState<AiRecommendationBanner> {
  bool _isCollapsed = false;
  String? _aiAdvice;
  bool _isLoadingAi = false;
  String? _lastAnalyzedKey;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final historyRepo = ref.watch(historyRepositoryProvider);
    final workoutRepo = ref.watch(workoutRepositoryProvider);
    final profile = ref.watch(athleteProfileProvider);

    final recentSessions = historyRepo.getSessions();
    final availableWorkouts = workoutRepo.getWorkouts();

    if (availableWorkouts.isEmpty) {
      return const SizedBox.shrink();
    }

    final report = RecoveryAnalyzer.analyze(
      recentSessions: recentSessions,
      availableWorkouts: availableWorkouts,
    );

    // If Gemini key is available and advice not yet fetched for current session state, fetch once
    final currentKey = '${recentSessions.length}_${report.recommendedGroup.name}';
    if (_lastAnalyzedKey != currentKey && ref.read(geminiCoachServiceProvider).hasApiKey) {
      _lastAnalyzedKey = currentKey;
      _fetchAiAdvice(report, availableWorkouts, recentSessions, profile);
    }

    final isLight = theme.isLight;
    final cardBg = isLight ? theme.surface : const Color(0xFF10192A);
    final borderCol = isLight ? theme.cardBorder : theme.accent.withValues(alpha: 0.35);

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: isLight ? 0.05 : 0.12),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome, color: theme.accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'РЕКОМЕНДАЦИЯ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            if (_isLoadingAi) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: theme.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Баланс мышц: ${report.recommendedGroup.displayName}',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.tune_rounded, color: theme.textSecondary, size: 20),
                    tooltip: 'Параметры атлета',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => AthleteProfileDialog.show(context),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: theme.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible body
          if (!_isCollapsed) ...[
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recovery mini-bars
                  Row(
                    children: report.statuses.map((s) {
                      final p = s.recoveryPercent;
                      final col = s.isReady
                          ? Colors.greenAccent
                          : (s.isRecovering ? Colors.amberAccent : Colors.redAccent);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.group.shortTag,
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: p,
                                  minHeight: 5,
                                  backgroundColor: theme.surfaceSubtle,
                                  valueColor: AlwaysStoppedAnimation<Color>(col),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Recommendation text
                  Text(
                    _aiAdvice ?? report.recommendationReason,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  if (report.recommendedWorkout != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TimerScreen(workout: report.recommendedWorkout!),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: isLight ? 0.08 : 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_fill_rounded, color: theme.accent, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Рекомендуем: ${report.recommendedWorkout!.name}',
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${report.recommendedWorkout!.type.name.toUpperCase()} • ${report.recommendedWorkout!.tags.join(', ')}',
                                    style: TextStyle(
                                      color: theme.accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Старт',
                                style: TextStyle(
                                  color: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Кнопка вызова AI-конструктора под рекомендацию
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.accent,
                        side: BorderSide(color: theme.accent.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      ),
                      onPressed: () {
                        AiWorkoutGeneratorDialog.show(
                          context,
                          initialMuscleFocus: report.recommendedGroup,
                        );
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        '✨ Собрать комплекс: ${report.recommendedGroup.displayName}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, height: 1.2),
                        maxLines: 2,
                        softWrap: true,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _fetchAiAdvice(
    RecoveryReport report,
    List<Workout> workouts,
    List<WorkoutSession> sessions,
    AthleteProfile profile,
  ) async {
    setState(() => _isLoadingAi = true);
    final coach = ref.read(geminiCoachServiceProvider);
    final advice = await coach.getNextWorkoutRecommendation(
      report: report,
      availableWorkouts: workouts,
      recentSessions: sessions,
      profile: profile,
    );
    if (mounted) {
      setState(() {
        _aiAdvice = advice;
        _isLoadingAi = false;
      });
    }
  }
}
