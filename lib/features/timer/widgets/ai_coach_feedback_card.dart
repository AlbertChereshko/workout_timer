import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../data/models/athlete_profile.dart';
import '../../../data/models/workout.dart';
import '../../../services/gemini_coach_service.dart';

class AiCoachFeedbackCard extends ConsumerStatefulWidget {
  final String workoutName;
  final WorkoutType type;
  final int durationSeconds;
  final int caloriesBurned;
  final int completedRounds;
  final List<String> tags;
  final AppThemeConfig theme;
  final String? userNote;

  const AiCoachFeedbackCard({
    super.key,
    required this.workoutName,
    required this.type,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.completedRounds,
    required this.tags,
    required this.theme,
    this.userNote,
  });

  @override
  ConsumerState<AiCoachFeedbackCard> createState() => _AiCoachFeedbackCardState();
}

class _AiCoachFeedbackCardState extends ConsumerState<AiCoachFeedbackCard> {
  String? _feedback;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void didUpdateWidget(covariant AiCoachFeedbackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userNote != widget.userNote && widget.userNote != null && widget.userNote!.trim().isNotEmpty) {
      _loadFeedback();
    }
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoading = true);
    final profile = ref.read(athleteProfileProvider);
    final coach = ref.read(geminiCoachServiceProvider);

    final text = await coach.getWorkoutCompletionFeedback(
      workoutName: widget.workoutName,
      type: widget.type,
      durationSeconds: widget.durationSeconds,
      caloriesBurned: widget.caloriesBurned,
      completedRounds: widget.completedRounds,
      tags: widget.tags,
      profile: profile,
      userNote: widget.userNote,
    );

    if (mounted) {
      setState(() {
        _feedback = text;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.theme.isLight;
    final cardBg = isLight
        ? widget.theme.surface
        : const Color(0xFF131A2A).withValues(alpha: 0.85);
    final borderColor = isLight
        ? widget.theme.cardBorder
        : widget.theme.accent.withValues(alpha: 0.35);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: widget.theme.accent.withValues(alpha: isLight ? 0.06 : 0.15),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: widget.theme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 15,
                  color: widget.theme.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI ТРЕНЕР',
                style: TextStyle(
                  color: widget.theme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: widget.theme.accent,
                  ),
                )
              else
                InkWell(
                  onTap: _loadFeedback,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: widget.theme.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Другой совет',
                          style: TextStyle(
                            color: widget.theme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            Text(
              'Анализирую нагрузку и готовлю рекомендации...',
              style: TextStyle(
                color: widget.theme.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              _feedback ?? '',
              style: TextStyle(
                color: widget.theme.textPrimary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
