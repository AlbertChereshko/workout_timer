import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/models/athlete_profile.dart';
import '../../data/models/exercise_library.dart';
import '../../data/models/workout.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../services/gemini_coach_service.dart';
import '../../services/recovery_analyzer.dart';
import '../timer/timer_screen.dart';

class AiWorkoutGeneratorDialog extends ConsumerStatefulWidget {
  final MuscleGroup? initialMuscleFocus;

  const AiWorkoutGeneratorDialog({
    super.key,
    this.initialMuscleFocus,
  });

  static Future<void> show(BuildContext context, {MuscleGroup? initialMuscleFocus}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiWorkoutGeneratorDialog(initialMuscleFocus: initialMuscleFocus),
    );
  }

  @override
  ConsumerState<AiWorkoutGeneratorDialog> createState() => _AiWorkoutGeneratorDialogState();
}

class _AiWorkoutGeneratorDialogState extends ConsumerState<AiWorkoutGeneratorDialog> {
  late WorkoutType _selectedType;
  late int _selectedDurationMinutes;
  MuscleGroup? _selectedMuscleGroup;
  ExerciseEquipment _selectedEquipment = ExerciseEquipment.bodyweight;
  final TextEditingController _promptController = TextEditingController();

  bool _isGenerating = false;
  Workout? _generatedWorkout;
  String? _errorMessage;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _selectedType = WorkoutType.tabata;
    _selectedDurationMinutes = 12;
    _selectedMuscleGroup = widget.initialMuscleFocus;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _isSaved = false;
    });

    final historyRepo = ref.read(historyRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final profile = ref.read(athleteProfileProvider);
    final coach = ref.read(geminiCoachServiceProvider);

    final recentSessions = historyRepo.getSessions();
    final availableWorkouts = workoutRepo.getWorkouts();
    final report = RecoveryAnalyzer.analyze(
      recentSessions: recentSessions,
      availableWorkouts: availableWorkouts,
    );

    try {
      final workout = await coach.generateWorkout(
        targetType: _selectedType,
        targetDurationMinutes: _selectedDurationMinutes,
        targetMuscleGroup: _selectedMuscleGroup,
        equipment: _selectedEquipment,
        recoveryReport: report,
        profile: profile,
        userPrompt: _promptController.text.trim().isEmpty ? null : _promptController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _generatedWorkout = workout;
          _isGenerating = false;
          _isSaved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Не удалось сгенерировать комплекс: $e';
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _showEditWorkoutNameDialog(Workout workout) async {
    final controller = TextEditingController(text: workout.name);
    final theme = ref.read(appThemeProvider);
    final isLight = theme.isLight;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLight ? theme.surface : const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: theme.accent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Название комплекса',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: theme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Введите название комплекса...',
            hintStyle: TextStyle(color: theme.textSecondary),
            filled: true,
            fillColor: isLight ? Colors.grey.shade100 : const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.accent, width: 2),
            ),
          ),
          onSubmitted: (val) {
            final t = val.trim();
            if (t.isNotEmpty) {
              final formatted = t[0].toUpperCase() + t.substring(1);
              Navigator.pop(ctx, formatted);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                final formatted = val[0].toUpperCase() + val.substring(1);
                Navigator.pop(ctx, formatted);
              }
            },
            child: const Text('Применить', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() {
        workout.name = newName;
      });
    }
  }

  Future<void> _saveWorkoutToLibrary(Workout workout) async {
    HapticFeedback.mediumImpact();
    await ref.read(workoutsNotifierProvider.notifier).saveWorkout(workout);
    ref.invalidate(workoutsProvider);
    ref.invalidate(workoutRepositoryProvider);

    setState(() {
      _isSaved = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('«${workout.name}» сохранена в ваши тренировки!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _startWorkoutNow(Workout workout) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimerScreen(workout: workout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final isLight = theme.isLight;
    final historyRepo = ref.watch(historyRepositoryProvider);
    final workoutRepo = ref.watch(workoutRepositoryProvider);

    final recentSessions = historyRepo.getSessions();
    final availableWorkouts = workoutRepo.getWorkouts();
    final report = RecoveryAnalyzer.analyze(
      recentSessions: recentSessions,
      availableWorkouts: availableWorkouts,
    );

    final bestMuscle = report.recommendedGroup;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isLight ? theme.surface : const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome, color: theme.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI-Конструктор тренировок',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Персональный комплекс по балансу восстановления',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Блок готовности мышц
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: isLight ? 0.08 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: theme.accent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Готовность к тренировке:',
                              style: TextStyle(
                                color: theme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: report.statuses.map((s) {
                            final pct = (s.recoveryPercent * 100).round();
                            Color col = Colors.greenAccent;
                            if (pct < 40) {
                              col = Colors.redAccent;
                            } else if (pct < 75) {
                              col = Colors.amberAccent;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLight ? Colors.white : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: col.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                '${s.group.shortTag}: $pct%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Рекомендован акцент: ${bestMuscle.displayName} (${(report.statuses.firstWhere((st) => st.group == bestMuscle).recoveryPercent * 100).round()}% готовности).',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 1. Формат тренировки
                  _buildSectionTitle('1. Формат тренировки', Icons.timer_outlined, theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceChip(
                          label: 'ТАБАТА',
                          sub: '20с / 10с',
                          isSelected: _selectedType == WorkoutType.tabata,
                          onTap: () => setState(() => _selectedType = WorkoutType.tabata),
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChoiceChip(
                          label: 'EMOM',
                          sub: 'Каждую минуту',
                          isSelected: _selectedType == WorkoutType.emom,
                          onTap: () => setState(() => _selectedType = WorkoutType.emom),
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChoiceChip(
                          label: 'AMRAP',
                          sub: 'На максимум',
                          isSelected: _selectedType == WorkoutType.amrap,
                          onTap: () => setState(() => _selectedType = WorkoutType.amrap),
                          theme: theme,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Длительность
                  _buildSectionTitle('2. Длительность комплекса', Icons.hourglass_top_rounded, theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [8, 12, 16, 20].map((mins) {
                      final isSel = _selectedDurationMinutes == mins;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => setState(() => _selectedDurationMinutes = mins),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel ? theme.accent : theme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? theme.accent : theme.cardBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$mins мин',
                                  style: TextStyle(
                                    color: isSel
                                        ? (theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                                        : theme.textPrimary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 3. Мышечный фокус
                  _buildSectionTitle('3. Акцент мышц', Icons.accessibility_new_rounded, theme),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: '✨ Авто (по восстановлению)',
                        isSelected: _selectedMuscleGroup == null,
                        onTap: () => setState(() => _selectedMuscleGroup = null),
                        theme: theme,
                      ),
                      ...MuscleGroup.values.map((mg) {
                        return _buildFilterChip(
                          label: mg.displayName,
                          isSelected: _selectedMuscleGroup == mg,
                          onTap: () => setState(() => _selectedMuscleGroup = mg),
                          theme: theme,
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 4. Инвентарь
                  _buildSectionTitle('4. Инвентарь', Icons.fitness_center_rounded, theme),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Свой вес',
                        isSelected: _selectedEquipment == ExerciseEquipment.bodyweight,
                        onTap: () => setState(() => _selectedEquipment = ExerciseEquipment.bodyweight),
                        theme: theme,
                      ),
                      _buildFilterChip(
                        label: 'Резинки',
                        isSelected: _selectedEquipment == ExerciseEquipment.resistanceBand,
                        onTap: () => setState(() => _selectedEquipment = ExerciseEquipment.resistanceBand),
                        theme: theme,
                      ),
                      _buildFilterChip(
                        label: 'Гиря 16 кг',
                        isSelected: _selectedEquipment == ExerciseEquipment.kettlebell16,
                        onTap: () => setState(() => _selectedEquipment = ExerciseEquipment.kettlebell16),
                        theme: theme,
                      ),
                      _buildFilterChip(
                        label: 'Гиря 6 кг',
                        isSelected: _selectedEquipment == ExerciseEquipment.kettlebell6,
                        onTap: () => setState(() => _selectedEquipment = ExerciseEquipment.kettlebell6),
                        theme: theme,
                      ),
                      _buildFilterChip(
                        label: 'Обе гири (16+6 кг)',
                        isSelected: _selectedEquipment == ExerciseEquipment.kettlebell,
                        onTap: () => setState(() => _selectedEquipment = ExerciseEquipment.kettlebell),
                        theme: theme,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 5. Особые пожелания
                  _buildSectionTitle('5. Особые пожелания (необязательно)', Icons.edit_note_rounded, theme),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    maxLines: 2,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Например: "без прыжков", "больше статических планок", "щадя колени"...',
                      hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                      filled: true,
                      fillColor: theme.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.accent, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Кнопка генерации
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isGenerating ? null : _generate,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 20),
                      label: Text(
                        _isGenerating ? 'AI формирует комплекс...' : 'Сгенерировать комплекс',
                        style: TextStyle(
                          color: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],

                  // Предпросмотр сгенерированного комплекса
                  if (_generatedWorkout != null) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildGeneratedWorkoutPreview(_generatedWorkout!, theme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedWorkoutPreview(Workout workout, AppThemeConfig theme) {
    final isLight = theme.isLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: isLight ? 0.08 : 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.accent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  workout.type.name.toUpperCase(),
                  style: TextStyle(
                    color: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _showEditWorkoutNameDialog(workout),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            workout.name,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.edit_rounded, size: 16, color: theme.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Теги: ${workout.tags.join(', ')} • Упражнений: ${workout.exercises.length}',
            style: TextStyle(color: theme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Список упражнений
          ...workout.exercises.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final ex = entry.value;
            final isStatic = ex.durationSeconds != null && (ex.reps == null || ex.reps == 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: theme.accent.withValues(alpha: 0.2),
                    child: Text(
                      '$idx',
                      style: TextStyle(fontSize: 11, color: theme.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ex.name,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.cardBorder),
                    ),
                    child: Text(
                      isStatic ? '${ex.durationSeconds} сек' : (ex.reps != null ? '${ex.reps} повт' : 'Работа'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: theme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Кнопки запуска и сохранения
          Row(
            children: [
              Expanded(
                child: _isSaved
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          side: const BorderSide(color: Colors.greenAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _saveWorkoutToLibrary(workout),
                        icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.greenAccent),
                        label: const Text('Сохранено ✓', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.accent,
                          side: BorderSide(color: theme.accent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _saveWorkoutToLibrary(workout),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _startWorkoutNow(workout),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Старт', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, AppThemeConfig theme) {
    return Row(
      children: [
        Icon(icon, color: theme.accent, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required String sub,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeConfig theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent : theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.accent : theme.cardBorder,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                    : theme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                color: isSelected
                    ? (theme.accent.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70)
                    : theme.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeConfig theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent.withValues(alpha: 0.18) : theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.accent : theme.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.accent : theme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
