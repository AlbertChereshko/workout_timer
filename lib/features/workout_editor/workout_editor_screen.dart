import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/video_launcher.dart';
import '../../core/theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/workout_type_theme.dart';
import '../../data/models/workout.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../l10n/app_localizations.dart';
import '../history/history_screen.dart';

class WorkoutEditorScreen extends ConsumerStatefulWidget {
  final Workout? workout;
  const WorkoutEditorScreen({super.key, this.workout});

  @override
  ConsumerState<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends ConsumerState<WorkoutEditorScreen> {
  late TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  final _exerciseController = TextEditingController();
  late TextEditingController _videoUrlController;
  bool _isTagsExpanded = false;
  
  late WorkoutType _type;
  late double _emomRounds;
  late double _emomDuration;
  late double _tabataWork;
  late double _tabataRest;
  late double _tabataRounds;
  late double _amrapDurationMinutes;
  late bool _amrapCountByRounds;
  
  late double _circuits;
  
  List<Exercise> _exercises = [];
  List<String> _selectedTags = [];
  
  String _localizedTag(String tag, AppLocalizations? l10n) {
    switch (tag) {
      case 'Верх':
      case 'Верх тела':
        return l10n?.tagUpperBody ?? 'Верх';
      case 'Низ':
      case 'Низ тела':
        return l10n?.tagLowerBody ?? 'Низ';
      case 'ВИТ':
      case 'ВИТ на всё тело':
        return l10n?.tagFullBodyHiit ?? 'ВИТ';
      case 'Статика':
        return l10n?.tagIsometric ?? 'Статика';
      case 'Full Body':
        return l10n?.tagFullBody ?? 'Full Body';
      case 'Гиря':
        return l10n?.tagKettlebell ?? tag;
      case 'Калистеника':
        return l10n?.tagCalisthenics ?? tag;
      default:
        return tag;
    }
  }

  @override
  void initState() {
    super.initState();
    final w = widget.workout;
    _nameController = TextEditingController(text: w?.name ?? "Новая тренировка");
    _videoUrlController = TextEditingController(text: w?.videoUrl ?? '');
    _type = w?.type ?? WorkoutType.tabata;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocusNode.requestFocus();
        _nameController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _nameController.text.length,
        );
      }
    });
    
    _emomRounds = (w?.emomRounds ?? 10).toDouble();
    _emomDuration = (w?.emomRoundDurationSeconds ?? 60).toDouble();
    
    _tabataWork = (w?.tabataWorkSeconds ?? 20).toDouble();
    _tabataRest = (w?.tabataRestSeconds ?? 10).toDouble();
    _tabataRounds = (w?.tabataRounds ?? 8).toDouble();
    _amrapDurationMinutes = ((w?.amrapDurationSeconds ?? 900) / 60).toDouble();
    _amrapCountByRounds = w?.amrapCountByRounds ?? true;
    
    if (w != null && w.exercises.isNotEmpty) {
      _exercises = w.exercises.map((e) => Exercise()
        ..name = e.name
        ..description = e.description
        ..reps = e.reps
        ..durationSeconds = (w.type == WorkoutType.amrap) ? null : e.durationSeconds).toList();
      final totalRounds = w.type == WorkoutType.tabata ? w.tabataRounds : w.emomRounds;
      _circuits = (totalRounds / _exercises.length).ceil().toDouble();
      if (_circuits < 1) _circuits = 1;
    } else {
      _circuits = 3;
    }
    
    if (w != null && w.tags.isNotEmpty) {
      _selectedTags = w.tags.map((t) {
        if (t == 'Верх тела') return 'Верх';
        if (t == 'Низ тела') return 'Низ';
        if (t == 'ВИТ на всё тело') return 'ВИТ';
        return t;
      }).toList();
    } else {
      _selectedTags = ['Верх'];
    }
  }

  int get _defaultDuration => _type == WorkoutType.amrap ? 60 : (_type == WorkoutType.tabata ? _tabataWork.toInt() : _emomDuration.toInt());

  int get _calculatedTotalSeconds {
    if (_type == WorkoutType.amrap) {
      return (_amrapDurationMinutes * 60).toInt();
    } else if (_type == WorkoutType.emom) {
      if (_exercises.isNotEmpty) {
        int sumPerCircuit = 0;
        for (final e in _exercises) {
          sumPerCircuit += (e.durationSeconds ?? _emomDuration.toInt());
        }
        return sumPerCircuit * _circuits.toInt();
      } else {
        return _emomRounds.toInt() * _emomDuration.toInt();
      }
    } else {
      if (_exercises.isNotEmpty) {
        int sumPerCircuit = 0;
        for (final e in _exercises) {
          sumPerCircuit += (e.durationSeconds ?? _tabataWork.toInt()) + _tabataRest.toInt();
        }
        return sumPerCircuit * _circuits.toInt();
      } else {
        return _tabataRounds.toInt() * (_tabataWork.toInt() + _tabataRest.toInt());
      }
    }
  }

  String _formatTotalWorkoutDuration([String? minShort, String? secShort]) {
    return WorkoutDurationExtension.formatSeconds(
      _calculatedTotalSeconds,
      minShort: minShort,
      secShort: secShort,
    );
  }

  void _addSingleExercise() {
    if (_exerciseController.text.trim().isEmpty) return;
    String name = _exerciseController.text.trim();
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }
    final isAmrap = (_type == WorkoutType.amrap);
    setState(() {
      _exercises.add(Exercise()
        ..name = name
        ..durationSeconds = isAmrap ? null : _defaultDuration
        ..reps = null);
      _exerciseController.clear();
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _duplicateExercise(int index) {
    final orig = _exercises[index];
    setState(() {
      _exercises.insert(
        index + 1,
        Exercise()
          ..name = orig.name
          ..durationSeconds = orig.durationSeconds
          ..reps = orig.reps,
      );
    });
  }

  bool get _isStaticWorkout => _selectedTags.contains('Статика');

  void _selectTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
        if (tag == 'Статика') {
          for (final e in _exercises) {
            e.reps = null;
          }
        }
      }
    });
  }

  void _showAddTagDialog(BuildContext context, AppThemeConfig theme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Новый тег / категория', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Например: Гимнастика, Лимфа, Кор...',
            hintStyle: TextStyle(color: theme.textSecondary),
            filled: true,
            fillColor: theme.surfaceSubtle,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (v) async {
            final t = TagsRepository.capitalize(v.trim());
            if (t.isNotEmpty) {
              await ref.read(tagsNotifierProvider.notifier).addTag(t);
              setState(() {
                if (!_selectedTags.contains(t)) _selectedTags.add(t);
              });
              if (ctx.mounted) Navigator.pop(ctx);
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
            ),
            onPressed: () async {
              final t = TagsRepository.capitalize(controller.text.trim());
              if (t.isNotEmpty) {
                await ref.read(tagsNotifierProvider.notifier).addTag(t);
                setState(() {
                  if (!_selectedTags.contains(t)) _selectedTags.add(t);
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showManageTagDialog(BuildContext context, String tag, AppThemeConfig theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Text(
                  'Управление тегом «$tag»',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: theme.accent),
                  title: Text('Переименовать тег', style: TextStyle(color: theme.textPrimary)),
                  onTap: () {
                    Navigator.pop(bctx);
                    _showRenameTagDialog(context, tag, theme);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Удалить тег', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(bctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (cctx) => AlertDialog(
                        backgroundColor: theme.surface,
                        title: Text('Удалить тег «$tag»?', style: TextStyle(color: theme.textPrimary)),
                        content: Text(
                          'Тег будет убран из списка доступных тегов.',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(cctx, false), child: const Text('Отмена')),
                          TextButton(
                            onPressed: () => Navigator.pop(cctx, true),
                            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(tagsNotifierProvider.notifier).deleteTag(tag);
                      setState(() => _selectedTags.remove(tag));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameTagDialog(BuildContext context, String oldTag, AppThemeConfig theme) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Переименовать тег', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Новое название',
            hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (val) async {
            final t = TagsRepository.capitalize(val.trim());
            if (t.isNotEmpty && t != oldTag) {
              await ref.read(tagsNotifierProvider.notifier).renameTag(oldTag, t);
              setState(() {
                if (_selectedTags.contains(oldTag)) {
                  _selectedTags.remove(oldTag);
                  _selectedTags.add(t);
                }
              });
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
            ),
            onPressed: () async {
              final t = TagsRepository.capitalize(controller.text.trim());
              if (t.isNotEmpty && t != oldTag) {
                await ref.read(tagsNotifierProvider.notifier).renameTag(oldTag, t);
                setState(() {
                  if (_selectedTags.contains(oldTag)) {
                    _selectedTags.remove(oldTag);
                    _selectedTags.add(t);
                  }
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // --- Bulk Add Dialog ---
  void _showBulkAddDialog() {
    final currentTheme = ref.read(appThemeProvider);
    final l10n = AppLocalizations.of(context);
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: currentTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.playlist_add, color: currentTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n?.bulkAddDialogTitle ?? 'Добавить',
                  style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.bulkAddPrompt ?? 'Введите названия (каждое с новой строки или через запятую):',
                  style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: currentTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: currentTheme.cardBorder),
                  ),
                  child: TextField(
                    controller: textController,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: currentTheme.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n?.bulkAddHint ?? 'Отжимания\nПриседания\nПланка\nВыпады\nПодтягивания',
                      hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5), fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n?.cancel ?? 'Отмена', style: TextStyle(color: currentTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final raw = textController.text;
                final names = raw
                    .split(RegExp(r'[\n,]+'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .map((s) => s[0].toUpperCase() + s.substring(1))
                    .toList();

                if (names.isNotEmpty) {
                  final isAmrap = (_type == WorkoutType.amrap);
                  final finalSec = isAmrap ? null : _defaultDuration;

                  setState(() {
                    for (final name in names) {
                      _exercises.add(Exercise()
                        ..name = name
                        ..durationSeconds = finalSec
                        ..reps = null);
                    }
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text(
                l10n?.addAll ?? 'Добавить все',
                style: TextStyle(
                  color: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Edit Individual Exercise Dialog ---
  void _showEditExerciseDialog(int index) {
    final currentTheme = ref.read(appThemeProvider);
    final l10n = AppLocalizations.of(context);
    final ex = _exercises[index];
    final nameController = TextEditingController(text: ex.name);
    int currentSec = ex.durationSeconds ?? _defaultDuration;
    int editMinutes = currentSec ~/ 60;
    int editSeconds = currentSec % 60;
    final repsController = TextEditingController(text: ex.reps != null && ex.reps! > 0 ? '${ex.reps}' : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: currentTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(l10n?.editExerciseTitle ?? 'Редактировать упражнение', style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n?.exerciseNameLabel ?? 'Название:', style: TextStyle(color: currentTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: currentTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: currentTheme.cardBorder),
                      ),
                      child: TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: currentTheme.textPrimary),
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                    if (_type != WorkoutType.amrap) ...[
                      const SizedBox(height: 16),
                      Text(l10n?.executionTimeLabel ?? 'Время выполнения:', style: TextStyle(color: currentTheme.accent, fontWeight: FontWeight.normal, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${l10n?.minShort ?? 'Мин'}: $editMinutes', style: TextStyle(color: currentTheme.textSecondary, fontSize: 12)),
                                Slider(
                                  value: editMinutes.toDouble(),
                                  min: 0,
                                  max: 10,
                                  activeColor: currentTheme.accent,
                                  onChanged: (v) => setDialogState(() => editMinutes = v.toInt()),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${l10n?.secShort ?? 'Сек'}: $editSeconds', style: TextStyle(color: currentTheme.textSecondary, fontSize: 12)),
                                Slider(
                                  value: editSeconds.toDouble(),
                                  min: 0,
                                  max: 55,
                                  divisions: 11,
                                  activeColor: currentTheme.accent,
                                  onChanged: (v) => setDialogState(() => editSeconds = v.toInt()),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: Text(
                          '${editMinutes * 60 + editSeconds} ${l10n?.secShort ?? 'сек'}',
                          style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.normal),
                        ),
                      ),
                    ],
                    if (!_isStaticWorkout) ...[
                      const SizedBox(height: 16),
                      Text(l10n?.repsCountLabel ?? 'Количество повторений:', style: TextStyle(color: currentTheme.accent, fontWeight: FontWeight.normal, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: currentTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: currentTheme.cardBorder),
                        ),
                        child: TextField(
                          controller: repsController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: currentTheme.textPrimary),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: l10n?.repsHint ?? 'Например: 15 (или пусто)',
                            hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n?.cancel ?? 'Отмена', style: TextStyle(color: currentTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final rawName = nameController.text.trim();
                    if (rawName.isNotEmpty) {
                      final name = rawName[0].toUpperCase() + rawName.substring(1);
                      final isAmrap = (_type == WorkoutType.amrap);
                      final totalSec = editMinutes * 60 + editSeconds;
                      final finalSec = isAmrap
                          ? null
                          : (totalSec > 0 ? totalSec : _defaultDuration);
                      final parsedReps = int.tryParse(repsController.text.trim());
                      final reps = _isStaticWorkout
                          ? null
                          : parsedReps;

                      setState(() {
                        _exercises[index].name = name;
                        _exercises[index].durationSeconds = finalSec;
                        _exercises[index].reps = reps;
                      });
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    l10n?.save ?? 'Сохранить',
                    style: TextStyle(
                      color: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Mass Adjust Time (+/- seconds for all) ---
  void _bulkAdjustTime(int deltaSeconds) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      for (final e in _exercises) {
        final cur = e.durationSeconds ?? _defaultDuration;
        final next = (cur + deltaSeconds).clamp(5, 600);
        e.durationSeconds = next;
      }
      if (_type == WorkoutType.tabata) {
        _tabataWork = (_tabataWork + deltaSeconds).clamp(5, 600).toDouble();
      } else {
        _emomDuration = (_emomDuration + deltaSeconds).clamp(5, 600).toDouble();
      }
    });

    final currentTheme = ref.read(appThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deltaSeconds > 0
              ? (l10n?.addedSecAll(deltaSeconds) ?? 'Добавлено +$deltaSeconds сек ко всем упражнениям!')
              : (l10n?.reducedSecAll(deltaSeconds.abs()) ?? 'Уменьшено на ${deltaSeconds.abs()} сек во всех упражнениях!'),
          style: TextStyle(color: currentTheme.textPrimary),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: currentTheme.surface,
      ),
    );
  }

  // --- Set Exact Time for All ---
  void _showSetTimeForAllDialog() {
    final currentTheme = ref.read(appThemeProvider);
    final l10n = AppLocalizations.of(context);
    int minutes = _defaultDuration ~/ 60;
    int seconds = _defaultDuration % 60;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: currentTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(l10n?.setTimeForAllDialogTitle ?? 'Задать время для ВСЕХ', style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n?.setTimeForAllPrompt ?? 'Выберите новое время для всех упражнений в комплексе:', style: TextStyle(color: currentTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('${l10n?.minShort ?? 'Мин'}: $minutes', style: TextStyle(color: currentTheme.textSecondary)),
                            Slider(
                              value: minutes.toDouble(),
                              min: 0,
                              max: 10,
                              activeColor: currentTheme.accent,
                              onChanged: (v) => setDialogState(() => minutes = v.toInt()),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('${l10n?.secShort ?? 'Сек'}: $seconds', style: TextStyle(color: currentTheme.textSecondary)),
                            Slider(
                              value: seconds.toDouble(),
                              min: 0,
                              max: 55,
                              divisions: 11,
                              activeColor: currentTheme.accent,
                              onChanged: (v) => setDialogState(() => seconds = v.toInt()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text('${minutes * 60 + seconds} ${l10n?.secShort ?? 'сек'}', style: TextStyle(color: currentTheme.accent, fontWeight: FontWeight.normal, fontSize: 16)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n?.cancel ?? 'Отмена', style: TextStyle(color: currentTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final total = minutes * 60 + seconds;
                    final finalSec = total > 0 ? total : 30;
                    setState(() {
                      for (final e in _exercises) {
                        e.durationSeconds = finalSec;
                      }
                      if (_type == WorkoutType.tabata) {
                        _tabataWork = finalSec.toDouble().clamp(5, 60).toDouble();
                      } else {
                        _emomDuration = finalSec.toDouble().clamp(10, 300).toDouble();
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    l10n?.applyToAll ?? 'Применить ко всем',
                    style: TextStyle(
                      color: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Set Reps for All ---
  void _showSetRepsForAllDialog() {
    final currentTheme = ref.read(appThemeProvider);
    final l10n = AppLocalizations.of(context);
    final repsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: currentTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n?.setRepsForAllDialogTitle ?? 'Задать повторы для ВСЕХ', style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n?.setRepsForAllPrompt ?? 'Введите количество повторений для каждого упражнения:', style: TextStyle(color: currentTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: currentTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentTheme.cardBorder),
                ),
                child: TextField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: currentTheme.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n?.repsHint ?? 'Например: 15',
                    hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n?.cancel ?? 'Отмена', style: TextStyle(color: currentTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final reps = int.tryParse(repsController.text.trim());
                if (reps != null && reps > 0) {
                  setState(() {
                    for (final e in _exercises) {
                      e.reps = reps;
                    }
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text(
                l10n?.applyToAll ?? 'Применить ко всем',
                style: TextStyle(
                  color: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentTheme = ref.watch(appThemeProvider);
    final availableTags = ref.watch(tagsProvider);

    return Scaffold(
      backgroundColor: currentTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: currentTheme.textPrimary,
        title: Text(
          widget.workout == null
              ? (l10n?.newWorkoutTitle ?? 'Новая тренировка')
              : (l10n?.editWorkoutTitle ?? 'Редактировать'),
          style: TextStyle(fontWeight: FontWeight.bold, color: currentTheme.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Первая строка: Название тренировки и общее время тренировки
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: currentTheme.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n?.workoutName ?? 'Название',
                      hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: currentTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: currentTheme.accent.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 17,
                        color: currentTheme.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTotalWorkoutDuration(l10n?.minShort, l10n?.secShort),
                        style: TextStyle(
                          color: currentTheme.textPrimary,
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tags (expandable multi-line wrap or compact scroll)
            _buildTagsSection(availableTags, currentTheme, l10n),
            const SizedBox(height: 20),
            
            // Workout Type selection
            Row(
              children: [
                _buildTypeButton(WorkoutType.tabata, 'TABATA', currentTheme),
                const SizedBox(width: 8),
                _buildTypeButton(WorkoutType.emom, 'EMOM', currentTheme),
                const SizedBox(width: 8),
                _buildTypeButton(WorkoutType.amrap, 'AMRAP', currentTheme),
              ],
            ),
            const SizedBox(height: 16),

            // Video link / file section
            _buildVideoLinkSection(currentTheme, l10n),
            const SizedBox(height: 24),
            
            // Exercises section header (with overflow safety)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _exercises.isEmpty ? 'Упражнения' : 'Упражнения (${_exercises.length})',
                    style: TextStyle(
                      color: currentTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showBulkAddDialog,
                  icon: Icon(Icons.playlist_add, color: currentTheme.accent, size: 20),
                  label: Text(l10n?.bulkAddButton ?? 'Списком', style: TextStyle(color: currentTheme.accent, fontWeight: FontWeight.normal)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Single add field
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: currentTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: currentTheme.cardBorder),
                    ),
                    child: TextField(
                      controller: _exerciseController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: currentTheme.textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: l10n?.addExercise ?? 'Добавить упражнение...',
                        hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5)),
                      ),
                      onSubmitted: (_) => _addSingleExercise(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: currentTheme.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: currentTheme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white),
                    onPressed: _addSingleExercise,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            if (_exercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: currentTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: currentTheme.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n?.bulkAddExerciseHelp ?? 'Добавьте упражнения по одному или нажмите «Списком», чтобы включить режим Кругов с индивидуальной настройкой времени и повторений.',
                        style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Exercise Cards List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final ex = _exercises[index];
                final duration = ex.durationSeconds ?? _defaultDuration;
                final isAmrap = (_type == WorkoutType.amrap);
                final showDuration = !isAmrap && (ex.durationSeconds != null && ex.durationSeconds! > 0);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: currentTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: currentTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: currentTheme.accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: currentTheme.accent, fontWeight: FontWeight.normal, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: TextStyle(color: currentTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (showDuration)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: currentTheme.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: currentTheme.cardBorder.withValues(alpha: 0.6),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '⏱ $duration ${l10n?.secShort ?? 'сек'}',
                                      style: TextStyle(
                                        color: currentTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (!_isStaticWorkout && ex.reps != null && ex.reps! > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: currentTheme.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: currentTheme.accent.withValues(alpha: 0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '🔁 ${ex.reps} повт',
                                      style: TextStyle(
                                        color: currentTheme.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 22,
                          icon: Icon(
                            Icons.more_vert,
                            color: currentTheme.textSecondary,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') _showEditExerciseDialog(index);
                            if (value == 'duplicate') _duplicateExercise(index);
                            if (value == 'delete') _removeExercise(index);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18, color: currentTheme.accent),
                                  const SizedBox(width: 8),
                                  Text(l10n?.edit ?? 'Редактировать'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'duplicate',
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 18, color: currentTheme.accent),
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
                );
              },
            ),
            
            // Панель "Время и повторы" (под перечнем упражнений)
            if (_exercises.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: currentTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: currentTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, color: currentTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _type == WorkoutType.amrap
                                ? 'Повторы'
                                : (_isStaticWorkout ? (l10n?.timeLabel ?? 'Время') : 'Время и повторы'),
                            style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    if (_type != WorkoutType.amrap) ...[
                      const SizedBox(height: 12),
                      // Быстрые дельты изменения времени в один ряд (-10с, -5с, +5с, +10с без +30с)
                      Row(
                        children: [
                          Expanded(child: _buildQuickActionButton('-10${l10n?.secShort ?? 'с'}', () => _bulkAdjustTime(-10), currentTheme)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildQuickActionButton('-5${l10n?.secShort ?? 'с'}', () => _bulkAdjustTime(-5), currentTheme)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildQuickActionButton('+5${l10n?.secShort ?? 'с'}', () => _bulkAdjustTime(5), currentTheme)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildQuickActionButton('+10${l10n?.secShort ?? 'с'}', () => _bulkAdjustTime(10), currentTheme)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Кнопки "Задать время" и "Задать повторы" в один гармоничный ряд
                    Row(
                      children: [
                        if (_type != WorkoutType.amrap) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: currentTheme.accent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              ),
                              onPressed: _showSetTimeForAllDialog,
                              icon: Icon(Icons.timer_outlined, size: 16, color: currentTheme.accent),
                              label: Text(
                                'Время',
                                style: TextStyle(color: currentTheme.accent, fontSize: 13, fontWeight: FontWeight.normal),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (!_isStaticWorkout) const SizedBox(width: 10),
                        ],
                        if (!_isStaticWorkout) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _type == WorkoutType.amrap ? currentTheme.accent : currentTheme.cardBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              ),
                              onPressed: _showSetRepsForAllDialog,
                              icon: Icon(Icons.repeat, size: 16, color: _type == WorkoutType.amrap ? currentTheme.accent : currentTheme.textSecondary),
                              label: Text(
                                _type == WorkoutType.amrap ? 'Задать повторы для всех' : 'Повторы',
                                style: TextStyle(color: _type == WorkoutType.amrap ? currentTheme.accent : currentTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.normal),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            
            // Две карточки в один ряд: Количество кругов и Длительность раунда
            _buildCircuitsAndDurationCards(currentTheme, l10n),

            const SizedBox(height: 36),
            Consumer(
              builder: (context, ref, child) {
                return SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentTheme.accent.withValues(alpha: currentTheme.isLight ? 0.08 : 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: currentTheme.accent,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentTheme.accent.withValues(alpha: currentTheme.isLight ? 0.35 : 0.65),
                          blurRadius: 20,
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
                        if (_selectedTags.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Пожалуйста, выберите хотя бы один тег для комплекса'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final workout = widget.workout ?? Workout();
                        String wName = _nameController.text.trim();
                        if (wName.isNotEmpty) {
                          wName = wName[0].toUpperCase() + wName.substring(1);
                        } else {
                          wName = "Новая тренировка";
                        }
                        workout.name = wName;
                        workout.type = _type;
                        
                        if (_exercises.isNotEmpty) {
                          int totalRounds = _exercises.length * _circuits.toInt();
                          workout.emomRounds = totalRounds;
                          workout.tabataRounds = totalRounds;
                        } else {
                          workout.emomRounds = _emomRounds.toInt();
                          workout.tabataRounds = _tabataRounds.toInt();
                        }
                        
                        workout.emomRoundDurationSeconds = _emomDuration.toInt();
                        workout.tabataWorkSeconds = _tabataWork.toInt();
                        workout.tabataRestSeconds = _tabataRest.toInt();
                        workout.amrapDurationSeconds = (_amrapDurationMinutes * 60).toInt();
                        workout.amrapCountByRounds = _amrapCountByRounds;
                        if (_isStaticWorkout) {
                          for (final e in _exercises) {
                            e.reps = null;
                          }
                        } else if (_type == WorkoutType.amrap) {
                          for (final e in _exercises) {
                            e.durationSeconds = null;
                            if (e.reps != null && e.reps! <= 0) {
                              e.reps = null;
                            }
                          }
                        }
                        workout.exercises = _exercises;
                        workout.tags = _selectedTags;
                        workout.videoUrl = _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim();
                          
                        if (widget.workout != null) {
                          await workout.save(); 
                          final historyRepo = ref.read(historyRepositoryProvider);
                          final sessions = historyRepo.getSessions().where((s) => s.workoutId == workout.key);
                          for (var s in sessions) {
                            s.workoutName = workout.name;
                            s.tags = workout.tags;
                            await s.save();
                          }
                          ref.invalidate(historyProvider);
                        } else {
                          await ref.read(workoutRepositoryProvider).saveWorkout(workout);
                        }
                        ref.read(workoutsNotifierProvider.notifier).refresh();
                        
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Builder(
                        builder: (context) {
                          final buttonTextColor = currentTheme.textPrimary;
                          final durationStr = _formatTotalWorkoutDuration(l10n?.minShort, l10n?.secShort);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n?.save ?? 'Сохранить',
                                style: AppTypography.buttonLabel(
                                  color: buttonTextColor,
                                  fontSize: 18,
                                ),
                              ),
                              if (_calculatedTotalSeconds > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: buttonTextColor.withValues(alpha: 0.5),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.timer_outlined,
                                  size: 19,
                                  color: currentTheme.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  durationStr,
                                  style: AppTypography.buttonLabel(
                                    color: buttonTextColor,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, VoidCallback? onTap, AppThemeConfig currentTheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap != null ? currentTheme.surfaceSubtle : currentTheme.surfaceSubtle.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: currentTheme.cardBorder),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? currentTheme.textPrimary : currentTheme.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildCircuitsAndDurationCards(AppThemeConfig currentTheme, AppLocalizations? l10n) {
    final isDark = currentTheme.accent.computeLuminance() > 0.5;

    if (_type == WorkoutType.amrap) {
      final presets = [5, 10, 12, 15, 20];
      final currentMins = _amrapDurationMinutes.toInt();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Карточка 1: Лимит времени
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: currentTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: currentTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.timeCap ?? 'Лимит времени',
                        style: TextStyle(
                          color: currentTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: presets.map((val) {
                          final isSelected = currentMins == val;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: GestureDetector(
                                onTap: () => setState(() => _amrapDurationMinutes = val.toDouble()),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? currentTheme.accent : currentTheme.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? currentTheme.accent : currentTheme.cardBorder,
                                      width: 1.1,
                                    ),
                                  ),
                                  child: Text(
                                    '$val',
                                    style: TextStyle(
                                      color: isSelected
                                          ? (isDark ? Colors.black87 : Colors.white)
                                          : currentTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniButton(
                            Icons.remove,
                            _amrapDurationMinutes > 1
                                ? () => setState(() => _amrapDurationMinutes -= 1)
                                : null,
                            currentTheme,
                          ),
                          Text(
                            '$currentMins ${l10n?.minutesShort ?? 'мин'}',
                            style: TextStyle(
                              color: currentTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildMiniButton(
                            Icons.add,
                            _amrapDurationMinutes < 60
                                ? () => setState(() => _amrapDurationMinutes += 1)
                                : null,
                            currentTheme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Карточка 2: Режим подсчета
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: currentTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: currentTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.countMode ?? 'Режим подсчёта',
                        style: TextStyle(
                          color: currentTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => setState(() => _amrapCountByRounds = true),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: _amrapCountByRounds ? currentTheme.accent : currentTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _amrapCountByRounds ? currentTheme.accent : currentTheme.cardBorder,
                              width: 1.1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.repeat_rounded,
                                size: 14,
                                color: _amrapCountByRounds
                                    ? (isDark ? Colors.black87 : Colors.white)
                                    : currentTheme.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  l10n?.byRounds ?? 'По раундам',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _amrapCountByRounds
                                        ? (isDark ? Colors.black87 : Colors.white)
                                        : currentTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: _amrapCountByRounds ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setState(() => _amrapCountByRounds = false),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: !_amrapCountByRounds ? currentTheme.accent : currentTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !_amrapCountByRounds ? currentTheme.accent : currentTheme.cardBorder,
                              width: 1.1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                size: 14,
                                color: !_amrapCountByRounds
                                    ? (isDark ? Colors.black87 : Colors.white)
                                    : currentTheme.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  l10n?.byExercises ?? 'По упражнениям',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: !_amrapCountByRounds
                                        ? (isDark ? Colors.black87 : Colors.white)
                                        : currentTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: !_amrapCountByRounds ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Информационная плашка AMRAP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: currentTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: currentTheme.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: currentTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'AMRAP: $currentMins ${l10n?.minShort ?? 'мин'}',
                  style: TextStyle(
                    color: currentTheme.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final isTabata = _type == WorkoutType.tabata;

    // Circuits / Rounds config
    final isExercises = _exercises.isNotEmpty;
    final int currentCircuits = isExercises
        ? _circuits.toInt()
        : (isTabata ? _tabataRounds.toInt() : _emomRounds.toInt());
    final List<int> circuitPresets = isExercises
        ? [2, 3, 4, 5]
        : (isTabata ? [4, 8, 12, 16] : [5, 8, 10, 12]);
    final String circuitsTitle = isExercises
        ? (l10n?.circuitsCountLabel ?? 'Кругов')
        : (l10n?.roundsCount ?? 'Раундов');

    // Duration / Work config
    final int currentDuration = isTabata ? _tabataWork.toInt() : _emomDuration.toInt();
    final List<int> durationPresets = isTabata ? [20, 30, 40, 45] : [30, 45, 60, 90];
    final String durationTitle = isTabata
        ? (l10n?.baseWorkTime ?? 'Время работы')
        : (l10n?.roundDuration ?? 'Интервал');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Карточка 1: Количество кругов (или раундов)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: currentTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: currentTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок ВСЕГДА на отдельной строке, первым:
                    Text(
                      circuitsTitle,
                      style: TextStyle(
                        color: currentTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Под заголовком: чипсы быстрого выбора
                    Row(
                      children: circuitPresets.map((val) {
                        final isSelected = currentCircuits == val;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isExercises) {
                                    _circuits = val.toDouble();
                                  } else if (isTabata) {
                                    _tabataRounds = val.toDouble();
                                  } else {
                                    _emomRounds = val.toDouble();
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? currentTheme.accent : currentTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? currentTheme.accent : currentTheme.cardBorder,
                                    width: 1.1,
                                  ),
                                ),
                                child: Text(
                                  '$val',
                                  style: TextStyle(
                                    color: isSelected
                                        ? (isDark ? Colors.black87 : Colors.white)
                                        : currentTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Карточка 2: Длительность раунда (или время работы)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: currentTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: currentTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок ВСЕГДА на отдельной строке, первым:
                    Text(
                      durationTitle,
                      style: TextStyle(
                        color: currentTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Под заголовком: чипсы быстрого выбора
                    Row(
                      children: durationPresets.map((val) {
                        final isSelected = currentDuration == val;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isTabata) {
                                    _tabataWork = val.toDouble();
                                  } else {
                                    _emomDuration = val.toDouble();
                                  }
                                  for (final e in _exercises) {
                                    e.durationSeconds = val;
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? currentTheme.accent : currentTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? currentTheme.accent : currentTheme.cardBorder,
                                    width: 1.1,
                                  ),
                                ),
                                child: Text(
                                  '$val',
                                  style: TextStyle(
                                    color: isSelected
                                        ? (isDark ? Colors.black87 : Colors.white)
                                        : currentTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Для Табаты: выбор времени отдыха
        if (isTabata) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: currentTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: currentTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.baseRestTime ?? 'Время отдыха:',
                  style: TextStyle(color: currentTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [10, 15, 20, 30].map((restSec) {
                    final isRestSelected = _tabataRest.toInt() == restSec;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setState(() => _tabataRest = restSec.toDouble()),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isRestSelected ? currentTheme.accent : currentTheme.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isRestSelected ? currentTheme.accent : currentTheme.cardBorder,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              '$restSecс',
                              style: TextStyle(
                                color: isRestSelected
                                    ? (isDark ? Colors.black87 : Colors.white)
                                    : currentTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: isRestSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Информационная сводка
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: currentTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: currentTheme.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isTabata ? Icons.local_fire_department_rounded : Icons.timer_outlined,
                color: currentTheme.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${isTabata ? 'ТАБАТА' : 'ЕМОМ'}: ${_formatTotalWorkoutDuration(l10n?.minShort, l10n?.secShort)}',
                style: TextStyle(
                  color: currentTheme.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(String label, VoidCallback onTap, AppThemeConfig currentTheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: currentTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: currentTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(color: currentTheme.textPrimary, fontWeight: FontWeight.normal, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildTypeButton(WorkoutType type, String label, AppThemeConfig currentTheme) {
    final isSelected = _type == type;
    final typeColor = WorkoutTypeTheme.primary(type, isLight: currentTheme.isLight);
    final isDarkText = typeColor.computeLuminance() > 0.5;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          if (_type == WorkoutType.amrap) {
            for (final e in _exercises) {
              if (!_isStaticWorkout) {
                e.durationSeconds = null;
                if (e.reps == null || e.reps! <= 0) {
                  e.reps = 10;
                }
              }
            }
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? typeColor
                : WorkoutTypeTheme.backgroundTint(type, isLight: currentTheme.isLight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? typeColor
                  : WorkoutTypeTheme.border(type, isLight: currentTheme.isLight),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: WorkoutTypeTheme.glow(type, isLight: currentTheme.isLight),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                WorkoutTypeTheme.icon(type),
                size: 16,
                color: isSelected
                    ? (isDarkText ? Colors.black87 : Colors.white)
                    : typeColor,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.buttonLabel(
                  color: isSelected
                      ? (isDarkText ? Colors.black87 : Colors.white)
                      : typeColor,
                  fontSize: 14,
                ).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, AppThemeConfig currentTheme, AppLocalizations? l10n) {
    final isSelected = _selectedTags.contains(tag);
    final localizedLabel = _localizedTag(tag, l10n);
    final isDarkText = currentTheme.accent.computeLuminance() > 0.5;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _selectTag(tag);
      },
      onLongPress: () => _showManageTagDialog(context, tag, currentTheme),
      onSecondaryTap: () => _showManageTagDialog(context, tag, currentTheme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? currentTheme.accent : currentTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? currentTheme.accent : currentTheme.cardBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check,
                size: 14,
                color: isDarkText ? Colors.black87 : Colors.white,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              localizedLabel,
              style: TextStyle(
                color: isSelected
                    ? (isDarkText ? Colors.black87 : Colors.white)
                    : currentTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTagChip(AppThemeConfig currentTheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showAddTagDialog(context, currentTheme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: currentTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: currentTheme.cardBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: currentTheme.accent),
            const SizedBox(width: 4),
            Text(
              'Тег',
              style: TextStyle(
                color: currentTheme.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(List<String> availableTags, AppThemeConfig currentTheme, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Направление (теги):',
                style: TextStyle(
                  color: currentTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isTagsExpanded = !_isTagsExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isTagsExpanded ? 'Свернуть' : 'Все теги',
                      style: TextStyle(
                        color: currentTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _isTagsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: currentTheme.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isTagsExpanded
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...availableTags.map((tag) => _buildTagChip(tag, currentTheme, l10n)),
                    _buildAddTagChip(currentTheme),
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      ...availableTags.map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildTagChip(tag, currentTheme, l10n),
                          )),
                      _buildAddTagChip(currentTheme),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildVideoLinkSection(AppThemeConfig currentTheme, AppLocalizations? l10n) {
    final hasVideo = _videoUrlController.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasVideo ? currentTheme.accent.withValues(alpha: 0.6) : currentTheme.cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.ondemand_video_rounded,
                size: 18,
                color: hasVideo ? currentTheme.accent : currentTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Видео комплекса / упражнений',
                  style: TextStyle(
                    color: currentTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasVideo)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Смотреть видео',
                  icon: Icon(Icons.play_circle_fill_rounded, color: currentTheme.accent, size: 24),
                  onPressed: () => _playWorkoutVideo(_videoUrlController.text.trim()),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _videoUrlController,
                  style: TextStyle(color: currentTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ссылка на видео или файл на телефоне...',
                    hintStyle: TextStyle(color: currentTheme.textSecondary.withValues(alpha: 0.5), fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: currentTheme.surfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: currentTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: currentTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: currentTheme.accent),
                    ),
                    suffixIcon: hasVideo
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              setState(() {
                                _videoUrlController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Выбрать видео-файл на телефоне',
                child: InkWell(
                  onTap: _pickVideoFile,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: currentTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: currentTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 18, color: currentTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Файл',
                          style: TextStyle(
                            color: currentTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _videoUrlController.text = result.files.single.path!;
        });
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<void> _playWorkoutVideo(String rawUrl) async {
    await VideoLauncher.open(context, rawUrl);
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _exerciseController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }
}
