import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/video_launcher.dart';
import '../../core/theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/workout_type_theme.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../data/models/workout.dart';
import '../../data/models/workout_session.dart';
import '../workout_editor/workout_editor_screen.dart';
import '../timer/timer_screen.dart';
import '../history/history_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../core/pluralization.dart';
import 'widgets/ai_recommendation_banner.dart';
import '../workout_generator/ai_workout_generator_dialog.dart';
export '../../data/repositories/workout_repository.dart' show workoutsProvider, workoutsNotifierProvider;


class WorkoutListScreen extends ConsumerStatefulWidget {
  const WorkoutListScreen({super.key});

  @override
  ConsumerState<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends ConsumerState<WorkoutListScreen> {
  String _selectedTag = 'Все';
  WorkoutType? _selectedType; // null = Все типы, WorkoutType.tabata, WorkoutType.emom
  bool _isCardView = true;
  String? _statusFilter; // 'done' | 'today' | 'plan'

  DateTime? _lastCompleted(Workout w, List<WorkoutSession> sessions) {
    DateTime? last;
    for (final s in sessions) {
      final matchId = w.isInBox && s.workoutId == w.key;
      final matchName = s.workoutName.trim().toLowerCase() == w.name.trim().toLowerCase();
      if ((matchId || matchName) && s.isCompleted) {
        if (last == null || s.startedAt.isAfter(last)) last = s.startedAt;
      }
    }
    return last;
  }

  bool _isDoneRecently(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !DateTime(d.year, d.month, d.day).isBefore(today.subtract(const Duration(days: 1)));
  }

  List<Workout> _applyStatus(List<Workout> list, List<WorkoutSession> sessions) {
    final last = {for (final w in list) w: _lastCompleted(w, sessions)};
    final done = list.where((w) => _isDoneRecently(last[w])).toList();
    final rest = list.where((w) => !_isDoneRecently(last[w])).toList()
      ..sort((a, b) {
        final la = last[a], lb = last[b];
        if (la == null && lb == null) return 0;
        if (la == null) return -1;
        if (lb == null) return 1;
        return la.compareTo(lb);
      });
    final today = rest.take(3).toList();
    final plan = rest.skip(3).toList();
    switch (_statusFilter) {
      case 'done':
        return done;
      case 'today':
        return today;
      case 'plan':
        return plan;
    }
    return [...rest, ...done];
  }

  Widget _statusChip(String id, String label, IconData icon, Color iconColor, AppThemeConfig t) {
    final sel = _statusFilter == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = sel ? null : id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: sel ? t.accent.withValues(alpha: 0.15) : t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? t.accent : t.cardBorder, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: sel ? t.accent : t.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    try {
      if (Hive.isBoxOpen('settings')) {
        _isCardView = Hive.box('settings').get('view_mode_cards', defaultValue: true) as bool;
      }
    } catch (_) {}
    // Ensure that on desktop / web, adaptive tiles mode is enabled by default
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
      _isCardView = true;
    }
  }

  void _toggleViewMode() {
    setState(() {
      _isCardView = !_isCardView;
    });
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('view_mode_cards', _isCardView);
      }
    } catch (_) {}
  }

  String _formatTotalDuration(Workout workout) {
    final l10n = AppLocalizations.of(context);
    return workout.formatTotalDuration(l10n?.minShort, l10n?.secShort);
  }

  Future<void> _editWorkout(Workout workout) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutEditorScreen(workout: workout)),
    );
    ref.read(workoutsNotifierProvider.notifier).refresh();
  }

  Future<void> _duplicateWorkout(Workout workout) async {
    final l10n = AppLocalizations.of(context);
    final copySuffix = l10n?.copySuffix ?? 'копия';
    final cloned = workout.cloneWithName('${workout.name} ($copySuffix)');
    await ref.read(workoutsNotifierProvider.notifier).saveWorkout(cloned);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.workoutDuplicated ?? 'Комплекс дублирован'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteWorkoutWithConfirmation(Workout workout) async {
    final l10n = AppLocalizations.of(context);
    final theme = ref.read(appThemeProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.cardBorder),
        ),
        title: Text(
          l10n?.delete ?? 'Удалить тренировку?',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Вы действительно хотите удалить комплекс «${workout.name}»? Это действие нельзя отменить.',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n?.cancel ?? 'Отмена',
              style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              l10n?.delete ?? 'Удалить',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(workoutsNotifierProvider.notifier).deleteWorkout(workout);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Комплекс «${workout.name}» удален'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportWorkout(Workout workout) async {
    HapticFeedback.lightImpact();
    final jsonMap = workout.toJson();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: jsonStr,
          subject: 'Комплекс тренировки: ${workout.name}',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Комплекс «${workout.name}» скопирован в буфер обмена'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportAllWorkouts() async {
    HapticFeedback.lightImpact();
    final workouts = ref.read(workoutsNotifierProvider);
    if (workouts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Список тренировок пуст'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final list = workouts.map((w) => w.toJson()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: jsonStr,
          subject: 'Комплексы тренировок (${workouts.length} шт.)',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Все комплексы (${workouts.length} шт.) скопированы в буфер обмена!'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openImportWorkoutDialog() {
    HapticFeedback.lightImpact();
    final theme = ref.read(appThemeProvider);
    final textController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.cardBorder),
            ),
            title: Row(
              children: [
                Icon(Icons.file_download_outlined, color: theme.accent),
                const SizedBox(width: 8),
                Text(
                  'Импорт комплексов',
                  style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Вставьте JSON комплекса, список комплексов или выберите файл .json:',
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textController,
                      maxLines: 6,
                      style: TextStyle(color: theme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: '[\n  {\n    "name": "Табата ноги",\n    "type": "tabata",\n    ...\n  }\n]',
                        hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: theme.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.textPrimary,
                            side: BorderSide(color: theme.cardBorder),
                          ),
                          onPressed: () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['json', 'txt'],
                              );
                              if (result != null && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                final content = await file.readAsString();
                                textController.text = content;
                                setDlgState(() => errorText = null);
                              }
                            } catch (e) {
                              setDlgState(() => errorText = 'Ошибка файла: $e');
                            }
                          },
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Выбрать файл', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.textPrimary,
                            side: BorderSide(color: theme.cardBorder),
                          ),
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null && data!.text!.isNotEmpty) {
                              textController.text = data.text!;
                              setDlgState(() => errorText = null);
                            }
                          },
                          icon: const Icon(Icons.paste_rounded, size: 16),
                          label: const Text('Из буфера', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                  ],
                ),
              ),
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
                ),
                onPressed: () async {
                  final text = textController.text.trim();
                  if (text.isEmpty) {
                    setDlgState(() => errorText = 'Вставьте JSON для импорта');
                    return;
                  }
                  try {
                    final dynamic decoded = jsonDecode(text);
                    final messenger = ScaffoldMessenger.of(context);
                    int importedCount = 0;
                    String lastImportedName = '';

                    if (decoded is List) {
                      for (final item in decoded) {
                        if (item is Map) {
                          final w = Workout.fromJson(Map<String, dynamic>.from(item));
                          await ref.read(workoutsNotifierProvider.notifier).saveWorkout(w);
                          importedCount++;
                          lastImportedName = w.name;
                        }
                      }
                    } else if (decoded is Map<String, dynamic>) {
                      if (decoded.containsKey('workouts') && decoded['workouts'] is List) {
                        for (final item in decoded['workouts']) {
                          if (item is Map) {
                            final w = Workout.fromJson(Map<String, dynamic>.from(item));
                            await ref.read(workoutsNotifierProvider.notifier).saveWorkout(w);
                            importedCount++;
                            lastImportedName = w.name;
                          }
                        }
                      } else {
                        final w = Workout.fromJson(decoded);
                        await ref.read(workoutsNotifierProvider.notifier).saveWorkout(w);
                        importedCount = 1;
                        lastImportedName = w.name;
                      }
                    } else {
                      setDlgState(() => errorText = 'Неверный формат JSON');
                      return;
                    }

                    if (importedCount == 0) {
                      setDlgState(() => errorText = 'Не найдено тренировок для импорта');
                      return;
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            importedCount == 1
                                ? 'Комплекс «$lastImportedName» успешно импортирован!'
                                : 'Успешно импортировано комплексов: $importedCount',
                          ),
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    setDlgState(() => errorText = 'Ошибка разбора JSON: $e');
                  }
                },
                child: const Text('Импортировать', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(workoutsProvider);
    final allSessions = ref.watch(historyProvider);
    final currentTheme = ref.watch(appThemeProvider);

    final l10n = AppLocalizations.of(context);

    // Collect all available tags dynamically from repository and workouts
    final repoTags = ref.watch(tagsProvider);
    final Set<String> allTagsSet = {'Все', ...repoTags};
    for (final w in workouts) {
      for (final t in w.tags) {
        if (t == 'Верх тела') {
          allTagsSet.add('Верх');
        } else if (t == 'Низ тела') {
          allTagsSet.add('Низ');
        } else if (t == 'ВИТ на всё тело') {
          allTagsSet.add('ВИТ');
        } else {
          allTagsSet.add(t);
        }
      }
    }
    final availableTags = allTagsSet.toList();

    // Filter workouts by selected tag and selected type
    final filteredWorkouts = workouts.where((w) {
      final matchesTag = _selectedTag == 'Все' ||
          w.tags.contains(_selectedTag) ||
          (_selectedTag == 'Верх' && w.tags.contains('Верх тела')) ||
          (_selectedTag == 'Низ' && w.tags.contains('Низ тела')) ||
          (_selectedTag == 'ВИТ' && w.tags.contains('ВИТ на всё тело'));
      final matchesType = _selectedType == null || w.type == _selectedType;
      return matchesTag && matchesType;
    }).toList();

    final displayWorkouts = _applyStatus(filteredWorkouts, allSessions);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: currentTheme.background,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main content: Command Center Library & Filters
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 14),
                        child: Row(
                          children: [
                            Text(
                              l10n?.workouts ?? 'Тренировки',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                color: currentTheme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: currentTheme.textPrimary,
                                side: BorderSide(color: currentTheme.cardBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onPressed: _exportAllWorkouts,
                              icon: Icon(Icons.share_outlined, size: 16, color: currentTheme.accent),
                              label: const Text('Экспорт', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: currentTheme.textPrimary,
                                side: BorderSide(color: currentTheme.cardBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onPressed: _openImportWorkoutDialog,
                              icon: Icon(Icons.file_upload_outlined, size: 16, color: currentTheme.accent),
                              label: const Text('Импорт', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            const SizedBox(width: 14),
                            // Tag selector
                            Container(
                              width: 230,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                              decoration: BoxDecoration(
                                color: currentTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedTag == 'Все' ? currentTheme.cardBorder : currentTheme.accent,
                                  width: 1.5,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: availableTags.contains(_selectedTag) ? _selectedTag : 'Все',
                                  dropdownColor: currentTheme.surface,
                                  icon: Icon(Icons.arrow_drop_down, color: currentTheme.accent, size: 28),
                                  isExpanded: true,
                                  borderRadius: BorderRadius.circular(14),
                                  items: availableTags.map((tag) {
                                    final isChosen = tag == _selectedTag;
                                    final displayTag = tag == 'Все' ? (l10n?.allTags ?? 'Все теги') : (tag.startsWith('#') ? tag.substring(1) : tag);
                                    return DropdownMenuItem<String>(
                                      value: tag,
                                      child: Row(
                                        children: [
                                          Icon(
                                            tag == 'Все' ? Icons.apps : Icons.local_offer,
                                            size: 18,
                                            color: isChosen ? currentTheme.accent : currentTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              displayTag,
                                              style: TextStyle(
                                                color: isChosen ? currentTheme.accent : currentTheme.textPrimary,
                                                fontWeight: isChosen ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (isChosen)
                                            Icon(Icons.check, size: 18, color: currentTheme.accent),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedTag = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            IconButton(
                              tooltip: _isCardView
                                  ? (l10n?.switchToListView ?? 'Переключить в режим Списка')
                                  : (l10n?.switchToCardView ?? 'Переключить в режим Плитки'),
                              icon: Icon(
                                _isCardView ? Icons.format_list_bulleted : Icons.grid_view_rounded,
                                color: currentTheme.accent,
                                size: 26,
                              ),
                              onPressed: _toggleViewMode,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Type Filter Buttons (TABATA / EMOM / AMRAP)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                        child: SizedBox(
                          height: 54,
                          child: Row(
                            children: [
                              _buildTypeFilterButton(
                                type: WorkoutType.tabata,
                                currentTheme: currentTheme,
                              ),
                              const SizedBox(width: 12),
                              _buildTypeFilterButton(
                                type: WorkoutType.emom,
                                currentTheme: currentTheme,
                              ),
                              const SizedBox(width: 12),
                              _buildTypeFilterButton(
                                type: WorkoutType.amrap,
                                currentTheme: currentTheme,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    _buildWorkoutsSliver(
                      filteredWorkouts: filteredWorkouts,
                      allSessions: allSessions,
                      currentTheme: currentTheme,
                      l10n: l10n,
                      isDesktop: true,
                      screenWidth: screenWidth,
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),

              // Right Sidebar: Gym Command Center & AI Coach
              Container(
                width: 410,
                decoration: BoxDecoration(
                  color: currentTheme.surface.withValues(alpha: 0.4),
                  border: Border(
                    left: BorderSide(color: currentTheme.cardBorder, width: 1.5),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutEditorScreen()));
                          ref.invalidate(workoutsProvider);
                        },
                        icon: const Icon(Icons.add_rounded, size: 24, color: Colors.white),
                        label: Text(
                          l10n?.createButton ?? 'Создать комплекс',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentTheme.accent,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => AiWorkoutGeneratorDialog.show(context),
                              icon: Icon(Icons.auto_awesome, size: 20, color: currentTheme.accent),
                              label: const Text('AI-Конструктор', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: currentTheme.accent,
                                side: BorderSide(color: currentTheme.accent.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportAllWorkouts,
                              icon: Icon(Icons.share_outlined, size: 18, color: currentTheme.accent),
                              label: const Text('Экспорт JSON', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: currentTheme.textPrimary,
                                side: BorderSide(color: currentTheme.cardBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openImportWorkoutDialog,
                              icon: Icon(Icons.file_upload_outlined, size: 18, color: currentTheme.accent),
                              label: const Text('Импорт JSON', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: currentTheme.textPrimary,
                                side: BorderSide(color: currentTheme.cardBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // AI Recommendation & Recovery Matrix
                      const AiRecommendationBanner(margin: EdgeInsets.zero),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: currentTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тренировка',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: currentTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Комплексы и таймеры',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: currentTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Экспорт всех комплексов',
                          icon: Icon(
                            Icons.share_outlined,
                            color: currentTheme.accent,
                            size: 22,
                          ),
                          onPressed: _exportAllWorkouts,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Импорт комплекса',
                          icon: Icon(
                            Icons.file_download_outlined,
                            color: currentTheme.accent,
                            size: 22,
                          ),
                          onPressed: _openImportWorkoutDialog,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'AI-Конструктор тренировок',
                          icon: Icon(
                            Icons.auto_awesome,
                            color: currentTheme.accent,
                            size: 22,
                          ),
                          onPressed: () => AiWorkoutGeneratorDialog.show(context),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: _isCardView
                              ? (l10n?.switchToListView ?? 'Переключить в режим Списка')
                              : (l10n?.switchToCardView ?? 'Переключить в режим Плитки'),
                          icon: Icon(
                            _isCardView ? Icons.format_list_bulleted : Icons.grid_view_rounded,
                            color: currentTheme.accent,
                            size: 22,
                          ),
                          onPressed: _toggleViewMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tag Filter Dropdown Menu
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: BoxDecoration(
                    color: currentTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedTag == 'Все' ? currentTheme.cardBorder : currentTheme.accent,
                      width: 1.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: availableTags.contains(_selectedTag) ? _selectedTag : 'Все',
                      dropdownColor: currentTheme.surface,
                      icon: Icon(Icons.arrow_drop_down, color: currentTheme.accent, size: 28),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      items: availableTags.map((tag) {
                        final isChosen = tag == _selectedTag;
                        final displayTag = tag == 'Все' ? (l10n?.allTags ?? 'Все теги') : (tag.startsWith('#') ? tag.substring(1) : tag);
                        return DropdownMenuItem<String>(
                          value: tag,
                          child: Row(
                            children: [
                              Icon(
                                tag == 'Все' ? Icons.apps : Icons.local_offer,
                                size: 18,
                                color: isChosen ? currentTheme.accent : currentTheme.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  displayTag,
                                  style: TextStyle(
                                    color: isChosen ? currentTheme.accent : currentTheme.textPrimary,
                                    fontWeight: isChosen ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (isChosen)
                                Icon(Icons.check, size: 18, color: currentTheme.accent),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedTag = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Type Filter Buttons (TABATA / EMOM / AMRAP) under tags
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      _buildTypeFilterButton(
                        type: WorkoutType.tabata,
                        currentTheme: currentTheme,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeFilterButton(
                        type: WorkoutType.emom,
                        currentTheme: currentTheme,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeFilterButton(
                        type: WorkoutType.amrap,
                        currentTheme: currentTheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Быстрый фильтр: Готово / Сегодня / План
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Row(
                  children: [
                    _statusChip('done', 'Готово', Icons.check_circle, Colors.green, currentTheme),
                    const SizedBox(width: 8),
                    _statusChip('today', 'Сегодня', Icons.bolt, Colors.amber, currentTheme),
                    const SizedBox(width: 8),
                    _statusChip('plan', 'План', Icons.hourglass_bottom, Colors.blueGrey, currentTheme),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            _buildWorkoutsSliver(
              filteredWorkouts: displayWorkouts,
              allSessions: allSessions,
              currentTheme: currentTheme,
              l10n: l10n,
              isDesktop: false,
              screenWidth: screenWidth,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB spacing
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutEditorScreen()));
          ref.invalidate(workoutsProvider);
        },
        backgroundColor: currentTheme.accent.withValues(alpha: 0.85),
        elevation: 4,
        shape: const CircleBorder(),
        child: Icon(
          Icons.add,
          color: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildWorkoutsSliver({
    required List<Workout> filteredWorkouts,
    required List<WorkoutSession> allSessions,
    required AppThemeConfig currentTheme,
    required AppLocalizations? l10n,
    required bool isDesktop,
    required double screenWidth,
  }) {
    if (filteredWorkouts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 76, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Text(
                _selectedTag == 'Все' && _selectedType == null
                    ? (l10n?.createWorkoutPrompt ?? 'Нет тренировок\nНажмите «+», чтобы добавить')
                    : 'Нет тренировок по выбранным фильтрам',
                textAlign: TextAlign.center,
                style: TextStyle(color: currentTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (_isCardView) {
      return SliverLayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.crossAxisExtent;
          // Adaptively compute 2 to 4 columns based on available content width
          final int crossAxisCount;
          if (availableWidth >= 1350) {
            crossAxisCount = 4;
          } else if (availableWidth >= 950) {
            crossAxisCount = 3;
          } else if (availableWidth >= 550) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = isDesktop ? 2 : 1;
          }

          return SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : (screenWidth >= 720 ? 24 : 16),
              vertical: 8,
            ),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              itemBuilder: (context, index) {
                final workout = filteredWorkouts[index];
                final durationText = _formatTotalDuration(workout);

                // Проверяем, выполнялась ли тренировка за последние 3 дня
                DateTime? lastCompletedAt;
                for (final s in allSessions) {
                  final matchId = workout.isInBox && s.workoutId == workout.key;
                  final matchName = s.workoutName.trim().toLowerCase() == workout.name.trim().toLowerCase();
                  if ((matchId || matchName) && s.isCompleted) {
                    if (lastCompletedAt == null || s.startedAt.isAfter(lastCompletedAt)) {
                      lastCompletedAt = s.startedAt;
                    }
                  }
                }

                bool isRecentlyCompleted = false;
                String? recentBadgeText;
                if (lastCompletedAt != null) {
                  final now = DateTime.now();
                  final diff = now.difference(lastCompletedAt);
                  if (diff.inDays <= 3) {
                    isRecentlyCompleted = true;
                    final dayDiff = now.difference(DateTime(lastCompletedAt.year, lastCompletedAt.month, lastCompletedAt.day)).inDays;
                    recentBadgeText = '✓ ${PluralHelper.daysAgo(dayDiff, short: false, localeCode: l10n?.localeName)}';
                  }
                }

                return _WorkoutCard(
                  workout: workout,
                  durationText: durationText,
                  theme: currentTheme,
                  isRecentlyCompleted: isRecentlyCompleted,
                  recentBadgeText: recentBadgeText,
                  isDesktop: isDesktop,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TimerScreen(workout: workout)));
                  },
                  onExport: () => _exportWorkout(workout),
                  onEdit: () => _editWorkout(workout),
                  onDuplicate: () => _duplicateWorkout(workout),
                  onDelete: () => _deleteWorkoutWithConfirmation(workout),
                );
              },
              childCount: filteredWorkouts.length,
            ),
          );
        },
      );
    } else {
      return SliverLayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.crossAxisExtent;
          // In list view on wide screens, adaptively split into 2 columns
          final int columns = (isDesktop && availableWidth >= 1100) ? 2 : 1;

          if (columns > 1) {
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 14,
                itemBuilder: (context, index) {
                  final workout = filteredWorkouts[index];
                  final durationText = _formatTotalDuration(workout);

                  DateTime? lastCompletedAt;
                  for (final s in allSessions) {
                    final matchId = workout.isInBox && s.workoutId == workout.key;
                    final matchName = s.workoutName.trim().toLowerCase() == workout.name.trim().toLowerCase();
                    if ((matchId || matchName) && s.isCompleted) {
                      if (lastCompletedAt == null || s.startedAt.isAfter(lastCompletedAt)) {
                        lastCompletedAt = s.startedAt;
                      }
                    }
                  }

                  bool isRecentlyCompleted = false;
                  String? recentBadgeText;
                  if (lastCompletedAt != null) {
                    final now = DateTime.now();
                    final diff = now.difference(lastCompletedAt);
                    if (diff.inDays <= 3) {
                      isRecentlyCompleted = true;
                      final dayDiff = now.difference(DateTime(lastCompletedAt.year, lastCompletedAt.month, lastCompletedAt.day)).inDays;
                      recentBadgeText = '✓ ${PluralHelper.daysAgo(dayDiff, short: false, localeCode: l10n?.localeName)}';
                    }
                  }

                  return _WorkoutListRow(
                    workout: workout,
                    durationText: durationText,
                    theme: currentTheme,
                    isRecentlyCompleted: isRecentlyCompleted,
                    recentBadgeText: recentBadgeText,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TimerScreen(workout: workout)));
                    },
                    onExport: () => _exportWorkout(workout),
                    onEdit: () => _editWorkout(workout),
                    onDuplicate: () => _duplicateWorkout(workout),
                    onDelete: () => _deleteWorkoutWithConfirmation(workout),
                  );
                },
                childCount: filteredWorkouts.length,
              ),
            );
          }

          return SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 20,
              vertical: 8,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final workout = filteredWorkouts[index];
                  final durationText = _formatTotalDuration(workout);

                  DateTime? lastCompletedAt;
                  for (final s in allSessions) {
                    final matchId = workout.isInBox && s.workoutId == workout.key;
                    final matchName = s.workoutName.trim().toLowerCase() == workout.name.trim().toLowerCase();
                    if ((matchId || matchName) && s.isCompleted) {
                      if (lastCompletedAt == null || s.startedAt.isAfter(lastCompletedAt)) {
                        lastCompletedAt = s.startedAt;
                      }
                    }
                  }

                  bool isRecentlyCompleted = false;
                  String? recentBadgeText;
                  if (lastCompletedAt != null) {
                    final now = DateTime.now();
                    final diff = now.difference(lastCompletedAt);
                    if (diff.inDays <= 3) {
                      isRecentlyCompleted = true;
                      final dayDiff = now.difference(DateTime(lastCompletedAt.year, lastCompletedAt.month, lastCompletedAt.day)).inDays;
                      recentBadgeText = '✓ ${PluralHelper.daysAgo(dayDiff, short: false, localeCode: l10n?.localeName)}';
                    }
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: _WorkoutListRow(
                        workout: workout,
                        durationText: durationText,
                        theme: currentTheme,
                        isRecentlyCompleted: isRecentlyCompleted,
                        recentBadgeText: recentBadgeText,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TimerScreen(workout: workout)));
                        },
                        onExport: () => _exportWorkout(workout),
                        onEdit: () => _editWorkout(workout),
                        onDuplicate: () => _duplicateWorkout(workout),
                        onDelete: () => _deleteWorkoutWithConfirmation(workout),
                      ),
                    ),
                  );
                },
                childCount: filteredWorkouts.length,
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildTypeFilterButton({
    required WorkoutType type,
    required AppThemeConfig currentTheme,
  }) {
    final isSelected = _selectedType == type;
    final color = WorkoutTypeTheme.primary(type, isLight: currentTheme.isLight);
    final icon = WorkoutTypeTheme.icon(type);
    final label = WorkoutTypeTheme.label(type);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = isSelected ? null : type;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : WorkoutTypeTheme.backgroundTint(type, isLight: currentTheme.isLight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color
                  : WorkoutTypeTheme.border(type, isLight: currentTheme.isLight),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: WorkoutTypeTheme.glow(type, isLight: currentTheme.isLight),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : icon,
                  color: isSelected ? Colors.white : color,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppTypography.buttonLabel(
                    color: isSelected ? Colors.white : color,
                    fontSize: 13.5,
                  ).copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    height: 1.15,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Card View (Adaptive Rich Tile) ---
class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final String durationText;
  final AppThemeConfig theme;
  final bool isRecentlyCompleted;
  final String? recentBadgeText;
  final bool isDesktop;
  final VoidCallback onTap;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  const _WorkoutCard({
    required this.workout,
    required this.durationText,
    required this.theme,
    this.isRecentlyCompleted = false,
    this.recentBadgeText,
    this.isDesktop = false,
    required this.onTap,
    required this.onExport,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final isEmom = workout.type == WorkoutType.emom;
    final isAmrap = workout.type == WorkoutType.amrap;
    final l10n = AppLocalizations.of(context);
    final typeColor = WorkoutTypeTheme.primary(workout.type, isLight: theme.isLight);
    final totalRounds = isEmom ? workout.emomRounds : workout.tabataRounds;
    final numExercises = workout.exercises.length;
    final circuits = numExercises > 0 ? (totalRounds / numExercises).ceil() : 1;

    final cardBg = isRecentlyCompleted
        ? (theme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF0F1420))
        : theme.surface;

    final cardBorderColor = isRecentlyCompleted
        ? (theme.isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08))
        : WorkoutTypeTheme.border(workout.type, isLight: theme.isLight);

    final List<BoxShadow> cardShadows = isRecentlyCompleted
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.isLight ? 0.04 : 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ]
        : [
            BoxShadow(
              color: WorkoutTypeTheme.glow(workout.type, isLight: theme.isLight),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            )
          ];

    return Opacity(
      opacity: isRecentlyCompleted ? 0.88 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorderColor, width: 1.5),
            boxShadow: cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Строка 1: Название тренировки + контекстное меню
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      workout.name,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.isLight
                            ? const Color(0xFF0A0F1D)
                            : (isRecentlyCompleted ? theme.textPrimary.withValues(alpha: 0.85) : theme.textPrimary),
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (workout.videoUrl != null && workout.videoUrl!.trim().isNotEmpty) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Смотреть видео комплекса',
                      icon: Icon(Icons.play_circle_fill_rounded, color: theme.accent, size: 24),
                      onPressed: () => VideoLauncher.open(context, workout.videoUrl!),
                    ),
                    const SizedBox(width: 4),
                  ],
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 22,
                      tooltip: 'Опции',
                      icon: Icon(Icons.more_vert, color: theme.isLight ? Colors.black54 : Colors.white60),
                      onSelected: (value) async {
                        if (value == 'video') {
                          await VideoLauncher.open(context, workout.videoUrl ?? '');
                        }
                        if (value == 'export') onExport();
                        if (value == 'edit') onEdit();
                        if (value == 'duplicate') onDuplicate();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        if (workout.videoUrl != null && workout.videoUrl!.trim().isNotEmpty)
                          PopupMenuItem(
                            value: 'video',
                            child: Row(
                              children: [
                                Icon(Icons.ondemand_video_rounded, size: 18, color: theme.accent),
                                const SizedBox(width: 8),
                                const Text('Видео комплекса'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18, color: theme.accent),
                              const SizedBox(width: 8),
                              const Text('Экспорт'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: theme.accent),
                              const SizedBox(width: 8),
                              Text(l10n?.edit ?? 'Редактировать'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 18, color: theme.accent),
                              const SizedBox(width: 8),
                              Text(l10n?.duplicate ?? 'Дублировать'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Text(l10n?.delete ?? 'Удалить'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Блок бейджей: Тип (ТАБАТА / EMOM / AMRAP), Время (#12 мин), Активность, Теги
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // 1. Бейдж типа
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isRecentlyCompleted
                          ? (theme.isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08))
                          : WorkoutTypeTheme.backgroundTint(workout.type, isLight: theme.isLight),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRecentlyCompleted
                            ? (theme.isLight ? Colors.black26 : Colors.white24)
                            : typeColor.withValues(alpha: 0.55),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          WorkoutTypeTheme.icon(workout.type),
                          size: 13,
                          color: isRecentlyCompleted
                              ? (theme.isLight ? Colors.black54 : Colors.white60)
                              : typeColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          WorkoutTypeTheme.label(workout.type),
                          style: TextStyle(
                            color: isRecentlyCompleted
                                ? (theme.isLight ? Colors.black54 : Colors.white60)
                                : typeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.3,
                            height: 1.15,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Хештег длительности
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isRecentlyCompleted
                          ? (theme.isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08))
                          : WorkoutTypeTheme.backgroundTint(workout.type, isLight: theme.isLight),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRecentlyCompleted
                            ? (theme.isLight ? Colors.black26 : Colors.white24)
                            : typeColor.withValues(alpha: 0.45),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      '#$durationText',
                      style: TextStyle(
                        color: isRecentlyCompleted
                            ? (theme.isLight ? Colors.black54 : Colors.white60)
                            : typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        height: 1.15,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),

                  // 3. Бейдж недавнего выполнения
                  if (isRecentlyCompleted && recentBadgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.isLight ? Colors.black26 : Colors.tealAccent.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        recentBadgeText!,
                        style: TextStyle(
                          color: theme.isLight ? Colors.teal.shade800 : Colors.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),

                  // 4. Теги тренировки
                  if (workout.tags.isNotEmpty)
                    for (final tag in workout.tags.where((t) => t.trim().isNotEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.isLight
                              ? theme.accent.withValues(alpha: 0.12)
                              : theme.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.accent.withValues(alpha: 0.45),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          tag.startsWith('#') ? tag.substring(1) : tag,
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            height: 1.15,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                        ),
                      ),
                ],
              ),

              const SizedBox(height: 12),

              // Параметры тренировки (если упражнений нет)
              if (workout.exercises.isEmpty) ...[
                Row(
                  children: [
                    Icon(
                      WorkoutTypeTheme.icon(workout.type),
                      size: 14,
                      color: typeColor.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isAmrap
                            ? '${l10n?.timeCap ?? "Ограничение по времени"}: ${workout.amrapDurationSeconds ~/ 60} ${l10n?.minShort ?? "мин"}'
                            : (isEmom
                                ? '${PluralHelper.rounds(workout.emomRounds, l10n?.localeName)} по ${workout.emomRoundDurationSeconds} ${l10n?.secShort ?? "сек"}'
                                : '${PluralHelper.rounds(workout.tabataRounds, l10n?.localeName)} (${l10n?.workShort ?? "работа:"} ${workout.tabataWorkSeconds}${l10n?.secShort ?? "с"}, ${l10n?.restShort ?? "отдых:"} ${workout.tabataRestSeconds}${l10n?.secShort ?? "с"})'),
                        style: TextStyle(color: theme.textSecondary, fontSize: 13.5, fontWeight: FontWeight.normal),
                      ),
                    ),
                  ],
                ),
              ],

              // Содержимое упражнений (если упражнения есть)
              if (workout.exercises.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 15,
                      color: typeColor.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAmrap
                          ? '${l10n?.timeCap ?? "Лимит"}: ${workout.amrapDurationSeconds ~/ 60} ${l10n?.minShort ?? "мин"} • ${workout.exercises.length} упр.:'
                          : '$circuits кр. • ${workout.exercises.length} упр.:',
                      style: TextStyle(
                        color: theme.isLight ? Colors.black54 : Colors.white70,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...workout.exercises.map((e) {
                  final isStatic = (e.durationSeconds != null && e.durationSeconds! > 0) || e.reps == null;
                  final dur = isAmrap
                      ? (isStatic ? (e.durationSeconds ?? 0) : 0)
                      : (e.durationSeconds ?? (isEmom ? workout.emomRoundDurationSeconds : workout.tabataWorkSeconds));
                  final reps = e.reps;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: (isDesktop ? 14.5 : 13.5) * 1.25,
                          child: Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: theme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.name,
                            maxLines: 3,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.isLight ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.92),
                              fontSize: isDesktop ? 14.5 : 13.5,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (reps != null && reps > 0 && !workout.tags.contains('Статика'))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: theme.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '$reps повт',
                                    style: TextStyle(
                                      color: theme.accent,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (dur > 0)
                                Text(
                                  '$dur сек',
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 10),

              // Кнопка Быстрый Старт внутри плитки
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: WorkoutTypeTheme.backgroundTint(workout.type, isLight: theme.isLight),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 20, color: typeColor),
                    const SizedBox(width: 6),
                    Text(
                      l10n?.start ?? 'Начать',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Compact List View ---
class _WorkoutListRow extends StatelessWidget {
  final Workout workout;
  final String durationText;
  final AppThemeConfig theme;
  final bool isRecentlyCompleted;
  final String? recentBadgeText;
  final VoidCallback onTap;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  const _WorkoutListRow({
    required this.workout,
    required this.durationText,
    required this.theme,
    this.isRecentlyCompleted = false,
    this.recentBadgeText,
    required this.onTap,
    required this.onExport,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final isEmom = workout.type == WorkoutType.emom;
    final isAmrap = workout.type == WorkoutType.amrap;
    final l10n = AppLocalizations.of(context);
    final typeColor = WorkoutTypeTheme.primary(workout.type, isLight: theme.isLight);
    final totalRounds = isEmom ? workout.emomRounds : workout.tabataRounds;
    final numExercises = workout.exercises.length;
    final circuits = numExercises > 0 ? (totalRounds / numExercises).ceil() : 1;

    final rowBg = isRecentlyCompleted
        ? (theme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF0F1420))
        : theme.surface;

    final rowBorder = isRecentlyCompleted
        ? (theme.isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08))
        : WorkoutTypeTheme.border(workout.type, isLight: theme.isLight);

    return Opacity(
      opacity: isRecentlyCompleted ? 0.88 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: rowBorder, width: 1.4),
            boxShadow: isRecentlyCompleted
                ? null
                : [
                    BoxShadow(
                      color: WorkoutTypeTheme.glow(workout.type, isLight: theme.isLight).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Строка 1: Название тренировки и общее время + кнопки управления
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        text: workout.name,
                        style: TextStyle(
                          color: theme.isLight
                              ? const Color(0xFF0A0F1D)
                              : (isRecentlyCompleted ? theme.textPrimary.withValues(alpha: 0.85) : theme.textPrimary),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                        children: [
                          TextSpan(
                            text: ' / $durationText',
                            style: TextStyle(
                              color: isRecentlyCompleted ? typeColor.withValues(alpha: 0.75) : typeColor,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (workout.videoUrl != null && workout.videoUrl!.trim().isNotEmpty) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Смотреть видео комплекса',
                      icon: Icon(Icons.play_circle_fill_rounded, color: theme.accent, size: 24),
                      onPressed: () => VideoLauncher.open(context, workout.videoUrl!),
                    ),
                    const SizedBox(width: 4),
                  ],
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 22,
                      tooltip: 'Опции',
                      icon: Icon(Icons.more_vert, color: theme.isLight ? Colors.black54 : Colors.white60),
                      onSelected: (value) async {
                        if (value == 'video') {
                          await VideoLauncher.open(context, workout.videoUrl ?? '');
                        }
                        if (value == 'export') onExport();
                        if (value == 'edit') onEdit();
                        if (value == 'duplicate') onDuplicate();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        if (workout.videoUrl != null && workout.videoUrl!.trim().isNotEmpty)
                          PopupMenuItem(
                            value: 'video',
                            child: Row(
                              children: [
                                Icon(Icons.ondemand_video_rounded, size: 18, color: theme.accent),
                                const SizedBox(width: 8),
                                const Text('Видео комплекса'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18, color: theme.accent),
                              const SizedBox(width: 8),
                              const Text('Экспорт'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: theme.accent),
                              const SizedBox(width: 8),
                              Text(l10n?.edit ?? 'Редактировать'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 18, color: theme.accent),
                              const SizedBox(width: 8),
                              Text(l10n?.duplicate ?? 'Дублировать'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Text(l10n?.delete ?? 'Удалить'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Строка 2: Тип (Табата / EMOM), активность (1 дн. назад), тег (#низ)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isRecentlyCompleted
                          ? (theme.isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08))
                          : WorkoutTypeTheme.backgroundTint(workout.type, isLight: theme.isLight),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRecentlyCompleted
                            ? (theme.isLight ? Colors.black26 : Colors.white24)
                            : typeColor.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          WorkoutTypeTheme.icon(workout.type),
                          size: 13,
                          color: isRecentlyCompleted
                              ? (theme.isLight ? Colors.black54 : Colors.white60)
                              : typeColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          WorkoutTypeTheme.label(workout.type),
                          style: TextStyle(
                            color: isRecentlyCompleted
                                ? (theme.isLight ? Colors.black54 : Colors.white60)
                                : typeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isRecentlyCompleted && recentBadgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.isLight ? Colors.black26 : Colors.tealAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        recentBadgeText!,
                        style: TextStyle(
                          color: theme.isLight ? Colors.teal.shade800 : Colors.tealAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ],
                  if (workout.tags.isNotEmpty && workout.tags.first.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.isLight
                            ? theme.accent.withValues(alpha: 0.12)
                            : theme.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: theme.accent.withValues(alpha: 0.45),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        workout.tags.first.startsWith('#')
                            ? workout.tags.first.substring(1)
                            : workout.tags.first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Если упражнений НЕТ: показываем строку с параметрами раундов
              if (workout.exercises.isEmpty) ...[
                Row(
                  children: [
                    Icon(
                      WorkoutTypeTheme.icon(workout.type),
                      size: 14,
                      color: typeColor.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isAmrap
                            ? '${l10n?.timeCap ?? "Ограничение по времени"}: ${workout.amrapDurationSeconds ~/ 60} ${l10n?.minShort ?? "мин"}'
                            : (isEmom
                                ? '${PluralHelper.rounds(workout.emomRounds, l10n?.localeName)} по ${workout.emomRoundDurationSeconds} ${l10n?.secShort ?? "сек"}'
                                : '${PluralHelper.rounds(workout.tabataRounds, l10n?.localeName)} (${l10n?.workShort ?? "работа:"} ${workout.tabataWorkSeconds}${l10n?.secShort ?? "с"}, ${l10n?.restShort ?? "отдых:"} ${workout.tabataRestSeconds}${l10n?.secShort ?? "с"})'),
                        style: TextStyle(color: theme.textSecondary, fontSize: 13.5, fontWeight: FontWeight.normal),
                      ),
                    ),
                  ],
                ),
              ],

              // Если упражнения ЕСТЬ: строка заголовка с количеством кругов и упражнений
              if (workout.exercises.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center_rounded,
                          size: 15,
                          color: typeColor.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAmrap
                              ? '${l10n?.timeCap ?? "Лимит"}: ${workout.amrapDurationSeconds ~/ 60} ${l10n?.minShort ?? "мин"} • ${workout.exercises.length} упр.:'
                              : '$circuits кр. • ${workout.exercises.length} упр.:',
                          style: TextStyle(
                            color: theme.isLight ? Colors.black54 : Colors.white60,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...workout.exercises.map((e) {
                      final isStatic = (e.durationSeconds != null && e.durationSeconds! > 0) || e.reps == null;
                      final dur = isAmrap
                          ? (isStatic ? (e.durationSeconds ?? 0) : 0)
                          : (e.durationSeconds ?? (isEmom ? workout.emomRoundDurationSeconds : workout.tabataWorkSeconds));
                      final reps = e.reps;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 14.5 * 1.25,
                              child: Center(
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: theme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.name,
                                maxLines: 3,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.isLight ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (reps != null && reps > 0 && !workout.tags.contains('Статика'))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: theme.accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        '$reps повт',
                                        style: TextStyle(
                                          color: theme.accent,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (dur > 0)
                                    Text(
                                      '$dur сек',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

