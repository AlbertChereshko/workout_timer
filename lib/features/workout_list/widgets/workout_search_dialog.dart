import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/theme/workout_type_theme.dart';
import '../../../data/models/workout.dart';
import '../../../l10n/app_localizations.dart';

class WorkoutSearchDialog extends StatefulWidget {
  final List<Workout> workouts;
  final AppThemeConfig theme;
  final Function(Workout) onSelectWorkout;
  final Function(Workout) onEditWorkout;

  const WorkoutSearchDialog({
    super.key,
    required this.workouts,
    required this.theme,
    required this.onSelectWorkout,
    required this.onEditWorkout,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Workout> workouts,
    required AppThemeConfig theme,
    required Function(Workout) onSelectWorkout,
    required Function(Workout) onEditWorkout,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => WorkoutSearchDialog(
        workouts: workouts,
        theme: theme,
        onSelectWorkout: onSelectWorkout,
        onEditWorkout: onEditWorkout,
      ),
    );
  }

  @override
  State<WorkoutSearchDialog> createState() => _WorkoutSearchDialogState();
}

class _WorkoutSearchDialogState extends State<WorkoutSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = widget.theme;
    final isLight = theme.isLight;

    final q = _query.trim().toLowerCase();
    final results = widget.workouts.where((w) {
      if (q.isEmpty) return true;
      if (w.name.toLowerCase().contains(q)) return true;
      if (w.exercises.any((e) => e.name.toLowerCase().contains(q))) return true;
      if (w.tags.any((t) => t.toLowerCase().contains(q))) return true;
      return false;
    }).toList();

    final size = MediaQuery.of(context).size;
    final double dialogWidth = (size.width - 32).clamp(320.0, 560.0);
    final double dialogHeight = (size.height * 0.75).clamp(380.0, 680.0);

    return Dialog(
      backgroundColor: theme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isLight ? const Color(0xFF94A3B8) : theme.cardBorder,
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Title & Close Button
              Row(
                children: [
                  Icon(Icons.search_rounded, color: theme.accent, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Поиск',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search Text Field
              Container(
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _query.isNotEmpty ? theme.accent : (isLight ? const Color(0xFFCBD5E1) : theme.cardBorder),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Тренировка или упражнение...',
                    hintStyle: TextStyle(
                      color: theme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: theme.accent, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.cancel_rounded, color: theme.textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() => _query = val);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Search status text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      q.isEmpty
                          ? 'Все тренировки (${results.length})'
                          : 'Найдено: ${results.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Results list
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: theme.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Ничего не найдено',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Попробуйте другое название или упражнение',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: theme.textSecondary.withValues(alpha: 0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final workout = results[index];
                          final typeColor = WorkoutTypeTheme.primary(workout.type, isLight: isLight);
                          final durationText = workout.formatTotalDuration(l10n?.minShort, l10n?.secShort);

                          // Check if any exercises match query
                          final matchedExercises = q.isEmpty
                              ? <String>[]
                              : workout.exercises
                                  .where((e) => e.name.toLowerCase().contains(q))
                                  .map((e) => e.name)
                                  .toList();

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onSelectWorkout(workout);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? const Color(0xFFF8FAFC)
                                      : const Color(0xFF131D31),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isLight ? const Color(0xFFCBD5E1) : theme.cardBorder,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title
                                          Text(
                                            workout.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: theme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 5),

                                          // Chips row: Type, Duration, Exercises count
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              // Type badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: typeColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: typeColor.withValues(alpha: 0.4),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child: Text(
                                                  workout.type.name.toUpperCase(),
                                                  style: TextStyle(
                                                    color: typeColor,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              // Duration
                                              Text(
                                                durationText,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.accent,
                                                ),
                                              ),
                                              if (workout.exercises.isNotEmpty)
                                                Text(
                                                  '• ${workout.exercises.length} упр.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.textSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),

                                          // Matched exercise highlight
                                          if (matchedExercises.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline_rounded,
                                                  size: 13,
                                                  color: theme.accent,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Упражнение: ${matchedExercises.join(", ")}',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: theme.accent,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Action buttons: Edit & Play
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(Icons.edit_outlined, size: 20, color: theme.textSecondary),
                                      tooltip: 'Редактировать',
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onEditWorkout(workout);
                                      },
                                    ),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: theme.accent.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.accent.withValues(alpha: 0.5),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: theme.accent,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
