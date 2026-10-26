import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme.dart';
import '../../../data/models/workout.dart';
import '../../../services/warmup_service.dart';

class WorkoutStartBottomSheet extends StatefulWidget {
  final Workout workout;
  final AppThemeConfig theme;
  final void Function(int warmupSeconds) onStart;

  const WorkoutStartBottomSheet({
    super.key,
    required this.workout,
    required this.theme,
    required this.onStart,
  });

  static Future<void> show({
    required BuildContext context,
    required Workout workout,
    required AppThemeConfig theme,
    required void Function(int warmupSeconds) onStart,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkoutStartBottomSheet(
        workout: workout,
        theme: theme,
        onStart: onStart,
      ),
    );
  }

  @override
  State<WorkoutStartBottomSheet> createState() => _WorkoutStartBottomSheetState();
}

class _WorkoutStartBottomSheetState extends State<WorkoutStartBottomSheet> {
  // Default to 3 minutes warmup for back safety!
  int _selectedWarmupSeconds = 180;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    const accentAmber = Color(0xFFFFB300);

    final exercises = _selectedWarmupSeconds > 0
        ? WarmupService.getExercisesForDuration(_selectedWarmupSeconds)
        : <WarmupExercise>[];

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: theme.cardBorder, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: theme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Workout Title & Type
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.workout.name,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Подготовка к выполнению комплекса',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: theme.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Spine & Joint protection banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentAmber.withValues(alpha: theme.isLight ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: accentAmber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Разминка снижает риск травм и растяжений поясницы на 85%',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'ВЫБЕРИТЕ РАЗМИНКУ ПЕРЕД КОМПЛЕКСОМ',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 10),

          // Options row: 0 min, 3 min, 5 min
          Row(
            children: [
              _buildOption(
                seconds: 0,
                title: 'Без разминки',
                subtitle: '0 мин',
                icon: Icons.flash_on_rounded,
                isRecommended: false,
              ),
              const SizedBox(width: 8),
              _buildOption(
                seconds: 180,
                title: '3 минуты',
                subtitle: '6 упр. (спина/суставы)',
                icon: Icons.timer_outlined,
                isRecommended: true,
              ),
              const SizedBox(width: 8),
              _buildOption(
                seconds: 300,
                title: '5 минут',
                subtitle: '🛡️ Полная защита',
                icon: Icons.health_and_safety_rounded,
                isRecommended: false,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Preview of exercises if warmup is selected
          if (_selectedWarmupSeconds > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ПРОГРАММА РАЗМИНКИ (${exercises.length} УПР.)',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openWarmupCustomizer(context),
                  icon: const Icon(Icons.edit_note_rounded, size: 16, color: accentAmber),
                  label: const Text(
                    'Настроить',
                    style: TextStyle(color: accentAmber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: theme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.cardBorder),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                itemCount: exercises.length,
                separatorBuilder: (_, __) => Divider(color: theme.cardBorder.withValues(alpha: 0.5), height: 8),
                itemBuilder: (context, index) {
                  final ex = exercises[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(ex.icon, size: 16, color: accentAmber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ex.title,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '30 сек',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Start Button
          ElevatedButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              widget.onStart(_selectedWarmupSeconds);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedWarmupSeconds > 0 ? accentAmber : theme.accent,
              foregroundColor: _selectedWarmupSeconds > 0 ? Colors.black87 : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedWarmupSeconds > 0 ? Icons.play_arrow_rounded : Icons.bolt_rounded,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedWarmupSeconds > 0
                      ? 'Начать с разминкой (${_selectedWarmupSeconds ~/ 60} мин)'
                      : 'Начать без разминки',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required int seconds,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRecommended,
  }) {
    final isSelected = _selectedWarmupSeconds == seconds;
    final theme = widget.theme;
    const accentAmber = Color(0xFFFFB300);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedWarmupSeconds = seconds);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accentAmber.withValues(alpha: theme.isLight ? 0.2 : 0.15)
                : theme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accentAmber : theme.cardBorder,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentAmber.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRecommended)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentAmber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ТОП',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                const SizedBox(height: 15),
              Icon(
                icon,
                size: 22,
                color: isSelected ? accentAmber : theme.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? accentAmber : theme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWarmupCustomizer(BuildContext context) async {
    final theme = widget.theme;
    const accentAmber = Color(0xFFFFB300);
    final currentList = List<WarmupExercise>.from(
      WarmupService.getExercisesForDuration(_selectedWarmupSeconds),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: theme.cardBorder, width: 1.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Настройка разминки',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '${_selectedWarmupSeconds ~/ 60} мин • ${currentList.length} упр. по 30 сек',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await WarmupService.resetToDefaults(_selectedWarmupSeconds);
                          setSheetState(() {
                            currentList
                              ..clear()
                              ..addAll(WarmupService.getExercisesForDuration(_selectedWarmupSeconds));
                          });
                          setState(() {});
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Сброшено к стандартным упражнениям'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Сброс'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.textSecondary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            if (Hive.isBoxOpen('workouts')) {
                              final box = Hive.box<Workout>('workouts');
                              final workoutObj = WarmupService.toWorkout(_selectedWarmupSeconds);
                              await box.add(workoutObj);
                              if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(
                                    content: Text('«${workoutObj.name}» добавлена в базу тренировок!'),
                                    backgroundColor: accentAmber,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(content: Text('Ошибка сохранения: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                        label: const Text('В базу комплексов'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentAmber.withValues(alpha: 0.2),
                          foregroundColor: accentAmber,
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: currentList.length,
                      separatorBuilder: (_, __) => Divider(color: theme.cardBorder.withValues(alpha: 0.4), height: 1),
                      itemBuilder: (ctx, i) {
                        final item = currentList[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: accentAmber.withValues(alpha: 0.15),
                            radius: 16,
                            child: Icon(item.icon, size: 16, color: accentAmber),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            item.backProtectionTip,
                            style: TextStyle(color: theme.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                color: theme.textSecondary,
                                onPressed: () => _editSingleExercise(
                                  sheetContext,
                                  theme,
                                  item,
                                  (updated) {
                                    setSheetState(() {
                                      currentList[i] = updated;
                                    });
                                    WarmupService.saveCustomExercises(_selectedWarmupSeconds, currentList);
                                    setState(() {});
                                  },
                                ),
                              ),
                              if (currentList.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                  onPressed: () {
                                    setSheetState(() {
                                      currentList.removeAt(i);
                                    });
                                    WarmupService.saveCustomExercises(_selectedWarmupSeconds, currentList);
                                    setState(() {});
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _editSingleExercise(
                      sheetContext,
                      theme,
                      const WarmupExercise(
                        title: 'Новое упражнение',
                        description: 'Описание выполнения упражнения',
                        backProtectionTip: 'Держите спину прямо и контролируйте дыхание',
                        icon: Icons.fitness_center_rounded,
                      ),
                      (newEx) {
                        setSheetState(() {
                          currentList.add(newEx);
                        });
                        WarmupService.saveCustomExercises(_selectedWarmupSeconds, currentList);
                        setState(() {});
                      },
                      isNew: true,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18, color: accentAmber),
                    label: const Text('Добавить упражнение', style: TextStyle(color: accentAmber, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: accentAmber),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editSingleExercise(
    BuildContext context,
    AppThemeConfig theme,
    WarmupExercise initial,
    ValueChanged<WarmupExercise> onSaved, {
    bool isNew = false,
  }) async {
    final titleCtrl = TextEditingController(text: initial.title);
    final descCtrl = TextEditingController(text: initial.description);
    final tipCtrl = TextEditingController(text: initial.backProtectionTip);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isNew ? 'Добавить упражнение' : 'Редактировать упражнение',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Название',
                  labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: theme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Техника выполнения',
                  labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: theme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tipCtrl,
                maxLines: 2,
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Совет по защите спины/суставов',
                  labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: theme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                onSaved(
                  initial.copyWith(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    backProtectionTip: tipCtrl.text.trim(),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black87,
            ),
            child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
