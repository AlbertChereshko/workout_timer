import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/video_launcher.dart';
import '../../core/theme.dart';
import '../../data/models/exercise_library.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/recovery_analyzer.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  MuscleGroup? _selectedGroup;
  String? _selectedTag;
  bool _onlyStatic = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tagsScrollController = ScrollController();
  bool _isTagsExpanded = false;
  final Set<String> _selectedIds = <String>{};

  void _toggleSelected(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _deleteExercises(List<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить упражнения?'),
        content: Text('Будет удалено: ${ids.length}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in ids) {
      await ref.read(allExercisesProvider.notifier).deleteExercise(id);
    }
    if (!mounted) return;
    setState(() => _selectedIds.removeAll(ids));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagsScrollController.dispose();
    super.dispose();
  }

  Future<void> _launchVideo(String urlStr) async {
    await VideoLauncher.open(context, urlStr);
  }

  Future<void> _exportExercises() async {
    HapticFeedback.lightImpact();
    final allExercises = ref.read(allExercisesProvider);
    final list = allExercises.map((e) => e.toJson()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: jsonStr,
          subject: 'База упражнений (${allExercises.length} упр.)',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('База упражнений скопирована в буфер обмена'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openBulkImportDialog(AppThemeConfig theme) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => _BulkImportDialog(
        theme: theme,
        onImport: (exercises, replaceBase) async {
          if (replaceBase) {
            await ref.read(allExercisesProvider.notifier).replaceAll(exercises);
          } else {
            await ref.read(allExercisesProvider.notifier).bulkSaveExercises(exercises);
          }
          final tagsSet = <String>{};
          for (final e in exercises) {
            tagsSet.addAll(e.tags);
          }
          if (tagsSet.isNotEmpty) {
            await ref.read(tagsNotifierProvider.notifier).bulkAddTags(tagsSet);
          }
          try {
            await CloudSyncService().triggerAutoBackgroundSync();
          } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  replaceBase
                      ? 'База заменена: импортировано ${exercises.length} упр.'
                      : 'Успешно импортировано: ${exercises.length} упр.',
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmClearAllExercises(AppThemeConfig theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Очистить базу?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Все упражнения будут удалены из базы. Вы сможете восстановить стандартный каталог (36 упражнений) или импортировать свои в любой момент.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(allExercisesProvider.notifier).clearAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Все упражнения удалены')),
                );
              }
            },
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
  }

  void _confirmRestoreDefaultCatalog(AppThemeConfig theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.restore, color: theme.accent),
            const SizedBox(width: 8),
            const Text('Восстановить каталог?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'База упражнений будет сброшена к исходному встроенному каталогу (36 упражнений). Все пользовательские изменения будут сброшены.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
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
              Navigator.pop(ctx);
              await ref.read(allExercisesProvider.notifier).restoreDefaultCatalog();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Восстановлен стандартный каталог (36 упражнений)')),
                );
              }
            },
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
  }

  void _openExerciseDialog([ExerciseDefinition? exercise]) {
    HapticFeedback.lightImpact();
    final width = MediaQuery.of(context).size.width;
    final messenger = ScaffoldMessenger.of(context);
    if (width >= 650) {
      showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _ExerciseEditSheet(
            exercise: exercise,
            onSave: (saved) async {
              await ref.read(allExercisesProvider.notifier).saveExercise(saved);
              try {
                await CloudSyncService().triggerAutoBackgroundSync();
              } catch (_) {}
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(exercise == null ? 'Упражнение добавлено' : 'Упражнение обновлено'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            onDelete: exercise == null ? null : () async {
              await ref.read(allExercisesProvider.notifier).deleteExercise(exercise.id);
              try {
                await CloudSyncService().triggerAutoBackgroundSync();
              } catch (_) {}
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Упражнение удалено / сброшено'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _ExerciseEditSheet(
          exercise: exercise,
          onSave: (saved) async {
            await ref.read(allExercisesProvider.notifier).saveExercise(saved);
            try {
              await CloudSyncService().triggerAutoBackgroundSync();
            } catch (_) {}
            if (sheetCtx.mounted) {
              Navigator.pop(sheetCtx);
            }
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(exercise == null ? 'Упражнение добавлено' : 'Упражнение обновлено'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onDelete: exercise == null ? null : () async {
            await ref.read(allExercisesProvider.notifier).deleteExercise(exercise.id);
            try {
              await CloudSyncService().triggerAutoBackgroundSync();
            } catch (_) {}
            if (sheetCtx.mounted) {
              Navigator.pop(sheetCtx);
            }
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Упражнение удалено / сброшено'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final isLight = theme.isLight;
    final allExercises = ref.watch(allExercisesProvider);
    final allTags = ref.watch(tagsProvider);

    final filtered = allExercises.where((e) {
      if (_selectedGroup != null && e.targetMuscle != _selectedGroup) {
        return false;
      }
      if ((_onlyStatic || _selectedTag == 'Статика') && !e.isStatic && !e.tags.any((t) => TagsRepository.capitalize(t) == 'Статика')) {
        return false;
      }
      if (_selectedTag != null && _selectedTag != 'Все' && _selectedTag != 'Статика') {
        final normSel = TagsRepository.capitalize(_selectedTag!);
        if (normSel == 'Верх') {
          final matches = e.targetMuscle == MuscleGroup.upperBody ||
              e.tags.any((t) {
                final ct = TagsRepository.capitalize(t);
                return ct == 'Верх' || ct == 'Верх тела';
              });
          if (!matches) return false;
        } else if (normSel == 'Низ') {
          final matches = e.targetMuscle == MuscleGroup.lowerBody ||
              e.tags.any((t) {
                final ct = TagsRepository.capitalize(t);
                return ct == 'Низ' || ct == 'Низ тела';
              });
          if (!matches) return false;
        } else if (normSel == 'Кор') {
          final matches = e.targetMuscle == MuscleGroup.coreStatic ||
              e.tags.any((t) => TagsRepository.capitalize(t) == 'Кор');
          if (!matches) return false;
        } else if (normSel == 'ВИТ') {
          final matches = e.targetMuscle == MuscleGroup.metabolicFullBody ||
              e.tags.any((t) {
                final ct = TagsRepository.capitalize(t);
                return ct == 'ВИТ' || ct == 'Full Body';
              });
          if (!matches) return false;
        } else if (normSel == 'Свой вес') {
          final isBw = e.equipment == ExerciseEquipment.bodyweight ||
              e.tags.any((t) => TagsRepository.capitalize(t) == 'Свой вес');
          if (!isBw) return false;
        } else if (normSel == 'Резинка') {
          final isBand = e.equipment == ExerciseEquipment.resistanceBand ||
              e.tags.any((t) => t.toLowerCase().contains('резин')) ||
              e.name.toLowerCase().contains('резин') ||
              e.description.toLowerCase().contains('резин');
          if (!isBand) return false;
        } else if (normSel == '16 кг' || normSel == '6 кг') {
          final matches = e.tags.any((t) => t.toLowerCase().contains(normSel.toLowerCase())) ||
              e.name.toLowerCase().contains(normSel.toLowerCase());
          if (!matches) return false;
        } else if (!e.tags.any((t) => TagsRepository.capitalize(t) == normSel)) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = e.name.toLowerCase().contains(q);
        final matchesDesc = e.description.toLowerCase().contains(q);
        final matchesTags = e.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchesName && !matchesDesc && !matchesTags) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'База',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${allExercises.length} упр. • База для AI и комплексов',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Управление базой',
                    icon: Icon(Icons.more_vert, color: theme.textSecondary, size: 22),
                    color: theme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (val) {
                      if (val == 'add') {
                        _openExerciseDialog();
                      } else if (val == 'export') {
                        _exportExercises();
                      } else if (val == 'import') {
                        _openBulkImportDialog(theme);
                      } else if (val == 'clear_all') {
                        _confirmClearAllExercises(theme);
                      } else if (val == 'restore_default') {
                        _confirmRestoreDefaultCatalog(theme);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 18, color: theme.accent),
                            const SizedBox(width: 10),
                            Text('Добавить упражнение', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18, color: theme.accent),
                            const SizedBox(width: 10),
                            Text('Экспорт', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'import',
                            child: Row(
                              children: [
                                Icon(Icons.file_upload_outlined, size: 18, color: theme.accent),
                                const SizedBox(width: 10),
                                Text('Импорт', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'restore_default',
                            child: Row(
                              children: [
                                Icon(Icons.restore, size: 18, color: theme.textPrimary),
                                const SizedBox(width: 10),
                                Text('Сбросить к исходным (36 упр.)', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),

                          const PopupMenuItem(
                            value: 'clear_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                                SizedBox(width: 10),
                                Text('Очистить всю базу', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: TextStyle(color: theme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Поиск по названию или технике...',
                  hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: theme.accent, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: theme.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isLight ? theme.surface : const Color(0xFF131D31),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.accent, width: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Filter Chips (Muscle Groups & Static) - Expandable Wrap without '#'
            _buildExpandableTags(theme, allTags),

            const SizedBox(height: 10),

            // Exercises List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fitness_center_outlined, size: 54, color: theme.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              allExercises.isEmpty ? 'База упражнений пуста' : 'Упражнения не найдены',
                              style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              allExercises.isEmpty
                                  ? 'Импортируйте свой каталог или восстановите стандартный набор'
                                  : 'Попробуйте изменить поисковый запрос или фильтры',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.textSecondary, fontSize: 13),
                            ),
                            if (allExercises.isEmpty) ...[
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.accent,
                                      foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _openBulkImportDialog(theme),
                                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                                    label: const Text('Импортировать'),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.textPrimary,
                                      side: BorderSide(color: theme.cardBorder),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _confirmRestoreDefaultCatalog(theme),
                                    icon: const Icon(Icons.restore, size: 18),
                                    label: const Text('Восстановить (36 упр.)'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 720) {
                          return GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 440,
                              mainAxisExtent: 185,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final ex = filtered[idx];
                              return _buildExerciseCard(
                                ex: ex,
                                isLight: isLight,
                                theme: theme,
                              );
                            },
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final ex = filtered[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildExerciseCard(
                                ex: ex,
                                isLight: isLight,
                                theme: theme,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog(AppThemeConfig theme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Новый тег', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Например: Гимнастика, Лимфа...',
            hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5)),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.accent),
            ),
          ),
          onSubmitted: (val) async {
            final t = val.trim();
            if (t.isNotEmpty) {
              await ref.read(tagsNotifierProvider.notifier).addTag(t);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
            ),
            onPressed: () async {
              final t = controller.text.trim();
              if (t.isNotEmpty) {
                await ref.read(tagsNotifierProvider.notifier).addTag(t);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _showManageTagDialog(String rawTag, AppThemeConfig theme) {
    var tag = rawTag.trim();
    while (tag.startsWith('#')) {
      tag = tag.substring(1).trim();
    }
    if (tag == 'Все' || tag.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Управление тегом «$tag»',
          style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: theme.accent),
              title: Text('Переименовать', style: TextStyle(color: theme.textPrimary)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameTagDialog(tag, theme);
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Удалить / Скрыть', style: TextStyle(color: Colors.redAccent)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (cctx) => AlertDialog(
                    backgroundColor: theme.surface,
                    title: Text('Удалить тег «$tag»?', style: TextStyle(color: theme.textPrimary)),
                    content: Text(
                      'Тег будет убран из списка тегов и фильтров.',
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
                  if (_selectedTag == tag) {
                    setState(() => _selectedTag = null);
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showRenameTagDialog(String oldTag, AppThemeConfig theme) {
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
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.accent),
            ),
          ),
          onSubmitted: (val) async {
            final t = val.trim();
            if (t.isNotEmpty && t != oldTag) {
              await ref.read(tagsNotifierProvider.notifier).renameTag(oldTag, t);
              if (_selectedTag == oldTag) {
                setState(() => _selectedTag = t);
              }
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
              final t = controller.text.trim();
              if (t.isNotEmpty && t != oldTag) {
                await ref.read(tagsNotifierProvider.notifier).renameTag(oldTag, t);
                if (_selectedTag == oldTag) {
                  setState(() => _selectedTag = t);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeConfig theme,
    VoidCallback? onLongPress,
    VoidCallback? onSecondaryTap,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent : theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.accent : theme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                : theme.textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableTags(AppThemeConfig theme, List<String> allTags) {
    final orderedBase = [
      'Статика',
      'Верх',
      'Низ',
      'Кор',
      'ВИТ',
      'Свой вес',
      'Резинка',
      '16 кг',
      '6 кг',
      'Гимнастика',
      'Лимфа',
    ];

    final Set<String> tagSet = {};
    final List<String> displayTags = [];

    for (final t in orderedBase) {
      final cap = TagsRepository.capitalize(t);
      if (tagSet.add(cap)) {
        displayTags.add(cap);
      }
    }

    for (final t in allTags) {
      final cap = TagsRepository.capitalize(t);
      if (cap == 'Верх тела' ||
          cap == 'Низ тела' ||
          cap == 'Резинки' ||
          cap == 'Кор и статика' ||
          cap == 'Кор и Статика' ||
          cap == 'Только статика') {
        continue;
      }
      if (tagSet.add(cap)) {
        displayTags.add(cap);
      }
    }

    final chips = <Widget>[
      _buildChip(
        label: 'Все',
        isSelected: _selectedGroup == null && !_onlyStatic && _selectedTag == null,
        onTap: () => setState(() {
          _selectedGroup = null;
          _onlyStatic = false;
          _selectedTag = null;
        }),
        theme: theme,
      ),
      ...displayTags.map((tag) {
        final isSel = (_selectedTag == tag) || (tag == 'Статика' && _onlyStatic);
        return _buildChip(
          label: tag,
          isSelected: isSel,
          onTap: () => setState(() {
            if (isSel) {
              _selectedTag = null;
              _onlyStatic = false;
              _selectedGroup = null;
            } else {
              _selectedTag = tag;
              _onlyStatic = (tag == 'Статика');
              _selectedGroup = null;
            }
          }),
          onLongPress: () => _showManageTagDialog(tag, theme),
          onSecondaryTap: () => _showManageTagDialog(tag, theme),
          theme: theme,
        );
      }),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showAddTagDialog(theme),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: theme.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: theme.accent),
              const SizedBox(width: 4),
              Text(
                'Тег',
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ];

    Widget buildToggle(bool isExpanded) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _isTagsExpanded = !_isTagsExpanded;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isExpanded
                ? theme.accent.withValues(alpha: 0.15)
                : theme.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpanded ? theme.accent : theme.cardBorder,
              width: 1,
            ),
          ),
          child: Icon(
            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: isExpanded ? theme.accent : theme.textPrimary,
          ),
        ),
      );
    }

    if (_isTagsExpanded) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 280),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorder.withValues(alpha: 0.5)),
          ),
          child: Scrollbar(
            controller: _tagsScrollController,
            thumbVisibility: true,
            thickness: 5,
            radius: const Radius.circular(8),
            child: SingleChildScrollView(
              controller: _tagsScrollController,
              padding: const EdgeInsets.all(10),
              physics: const BouncingScrollPhysics(),
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...chips,
                  buildToggle(true),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: chips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => chips[i],
                ),
              ),
            ),
            const SizedBox(width: 8),
            buildToggle(false),
          ],
        ),
      ),
    );
  }

  void _showExerciseDetailDialog(ExerciseDefinition ex, AppThemeConfig theme) {
    final repo = ref.read(exerciseRepositoryProvider);
    final isCustom = repo.isCustom(ex.id);
    final isOverridden = repo.isOverridden(ex.id);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  ex.isStatic ? Icons.timer_outlined : Icons.fitness_center,
                  color: theme.accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: TextStyle(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ex.targetMuscle.displayName} • ${ex.equipment.displayName}',
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ТЕХНИКА И РЕКОМЕНДАЦИИ', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)),
                const SizedBox(height: 6),
                Text(
                  ex.description.isNotEmpty ? ex.description : 'Выполняйте в контролируемом темпе, удерживая ровное дыхание и нейтральное положение позвоночника.',
                  style: TextStyle(color: theme.textPrimary, fontSize: 14.5, height: 1.45),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ex.isStatic ? Icons.timer_outlined : Icons.repeat, size: 15, color: theme.accent),
                          const SizedBox(width: 6),
                          Text(
                            ex.isStatic ? '${ex.defaultDurationSeconds} секунд' : '${ex.defaultReps} повторений',
                            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed, size: 15, color: theme.accent),
                          const SizedBox(width: 6),
                          Text(
                            ex.difficulty.displayName,
                            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (isOverridden)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(allExercisesProvider.notifier).deleteExercise(ex.id);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Сброшено к исходным настройкам'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt, size: 18, color: Colors.orangeAccent),
                label: const Text('Сбросить', style: TextStyle(color: Colors.orangeAccent)),
              )
            else if (isCustom)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(allExercisesProvider.notifier).deleteExercise(ex.id);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Упражнение удалено'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                label: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Закрыть', style: TextStyle(color: theme.textSecondary, fontSize: 14)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openExerciseDialog(ex);
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Редактировать', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExerciseCard({
    required ExerciseDefinition ex,
    required bool isLight,
    required AppThemeConfig theme,
  }) {
    final repo = ref.read(exerciseRepositoryProvider);
    final isCustom = repo.isCustom(ex.id);
    final isOverridden = repo.isOverridden(ex.id);
    final messenger = ScaffoldMessenger.of(context);

    final selected = _selectedIds.contains(ex.id);
    return InkWell(
      onTap: () {
        if (_selectedIds.isNotEmpty) {
          _toggleSelected(ex.id);
        } else {
          _showExerciseDetailDialog(ex, theme);
        }
      },
      onLongPress: () => _toggleSelected(ex.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: 0.14)
              : (isLight ? theme.surface : const Color(0xFF131D31)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.accent
                : isOverridden
                    ? Colors.amber.withValues(alpha: 0.6)
                    : isCustom
                        ? theme.accent.withValues(alpha: 0.5)
                        : theme.cardBorder,
            width: (selected || isCustom || isOverridden) ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ex.isStatic
                              ? theme.accent.withValues(alpha: 0.15)
                              : theme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ex.isStatic ? theme.accent : theme.cardBorder,
                          ),
                        ),
                        child: Text(
                          ex.isStatic ? 'СТАТИКА' : 'ДИНАМИКА',
                          style: TextStyle(
                            color: ex.isStatic ? theme.accent : theme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ex.targetMuscle.shortTag,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (ex.subgroup != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            ex.subgroup!.displayName,
                            style: const TextStyle(
                              color: Color(0xFF06B6D4),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isOverridden) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'ИЗМЕНЕНО',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ex.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (ex.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ex.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (ex.notes != null && ex.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.surfaceSubtle.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.cardBorder.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 12, color: theme.accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              ex.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        ex.isStatic ? Icons.timer_outlined : Icons.repeat_rounded,
                        size: 14,
                        color: theme.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ex.isStatic
                            ? '${ex.defaultDurationSeconds} сек по умолчанию'
                            : '${ex.defaultReps} повт по умолчанию',
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        ex.equipment.displayName,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ex.videoUrl != null && ex.videoUrl!.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'Смотреть видео техники',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                    iconSize: 42,
                    icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 40),
                    onPressed: () => _launchVideo(ex.videoUrl!),
                  ),
                  const SizedBox(height: 6),
                ],
                IconButton(
                  tooltip: 'Редактировать',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.edit_outlined, color: theme.textSecondary, size: 20),
                  onPressed: () => _openExerciseDialog(ex),
                ),
                if (isOverridden) ...[
                  const SizedBox(height: 6),
                  IconButton(
                    tooltip: 'Сбросить к исходным',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.restart_alt, color: Colors.orangeAccent, size: 20),
                    onPressed: () async {
                      await ref.read(allExercisesProvider.notifier).deleteExercise(ex.id);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Сброшено к исходным настройкам'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 6),
                IconButton(
                  tooltip: 'Удалить упражнение',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _deleteExercises([ex.id]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseEditSheet extends ConsumerStatefulWidget {
  final ExerciseDefinition? exercise;
  final ValueChanged<ExerciseDefinition> onSave;
  final VoidCallback? onDelete;

  const _ExerciseEditSheet({
    this.exercise,
    required this.onSave,
    this.onDelete,
  });

  @override
  ConsumerState<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends ConsumerState<_ExerciseEditSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _videoUrlController;
  late TextEditingController _notesController;
  late MuscleGroup _muscle;
  MuscleSubgroup? _subgroup;
  late bool _isStatic;
  late int _duration;
  late int _reps;
  late ExerciseEquipment _equipment;
  late ExerciseDifficulty _difficulty;
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _videoUrlController = TextEditingController(text: e?.videoUrl ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _muscle = e?.targetMuscle ?? MuscleGroup.coreStatic;
    _subgroup = e?.subgroup;
    _isStatic = e?.isStatic ?? false;
    _duration = e?.defaultDurationSeconds ?? 30;
    _reps = e?.defaultReps ?? 12;
    _equipment = e?.equipment ?? ExerciseEquipment.bodyweight;
    _difficulty = e?.difficulty ?? ExerciseDifficulty.intermediate;
    _selectedTags = e?.tags != null ? List<String>.from(e!.tags) : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _videoUrlController.dispose();
    _notesController.dispose();
    super.dispose();
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
            hintText: 'Например: Гимнастика, Лимфа, Кардио...',
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
            child: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showManageTagDialog(BuildContext context, String rawTag, AppThemeConfig theme) {
    var tag = rawTag.trim();
    while (tag.startsWith('#')) {
      tag = tag.substring(1).trim();
    }
    if (tag.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Управление тегом «$tag»',
          style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: theme.accent),
              title: Text('Переименовать', style: TextStyle(color: theme.textPrimary)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameTagDialog(context, tag, theme);
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (cctx) => AlertDialog(
                    backgroundColor: theme.surface,
                    title: Text('Удалить тег «$tag»?', style: TextStyle(color: theme.textPrimary)),
                    content: Text(
                      'Тег будет удалён из списка доступных тегов.',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
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
          Widget _buildSectionCard({
    required AppThemeConfig theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.isLight ? Colors.grey.shade50 : const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final isLight = theme.isLight;
    final isNew = widget.exercise == null;
    final allTags = ref.watch(tagsProvider);
    final availableSubgroups = MuscleSubgroup.forParent(_muscle);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: isLight ? theme.surface : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.cardBorder),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isNew ? 'Новое упражнение' : 'Редактировать упражнение',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Card 1: Основная информация
                _buildSectionCard(
                  theme: theme,
                  title: '1. ОСНОВНАЯ ИНФОРМАЦИЯ',
                  icon: Icons.info_outline,
                  children: [
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: theme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Название упражнения *',
                        labelStyle: TextStyle(color: theme.textSecondary),
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
                          borderSide: BorderSide(color: theme.accent, width: 2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      style: TextStyle(color: theme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Описание техники или фокус',
                        labelStyle: TextStyle(color: theme.textSecondary),
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
                          borderSide: BorderSide(color: theme.accent, width: 2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _videoUrlController,
                            keyboardType: TextInputType.url,
                            style: TextStyle(color: theme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Ссылка на видео (YouTube / Shorts / Reels)',
                              labelStyle: TextStyle(color: theme.textSecondary),
                              prefixIcon: Icon(Icons.link, color: theme.accent, size: 20),
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
                                borderSide: BorderSide(color: theme.accent, width: 2.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Проверить ссылку',
                          icon: const Icon(Icons.play_arrow, size: 20),
                          onPressed: () {
                            final url = _videoUrlController.text.trim();
                            if (url.isNotEmpty) {
                              VideoLauncher.open(context, url);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // Card 2: Мышечная группа и подгруппа
                _buildSectionCard(
                  theme: theme,
                  title: '2. ЦЕЛЕВЫЕ МЫШЦЫ И ПОДГРУППЫ',
                  icon: Icons.accessibility_new,
                  children: [
                    Text('Основная группа:', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: MuscleGroup.values.map((mg) {
                        return ChoiceChip(
                          label: Text(mg.displayName, style: const TextStyle(fontSize: 12)),
                          selected: _muscle == mg,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _muscle = mg;
                                final newSub = MuscleSubgroup.forParent(mg);
                                if (!newSub.contains(_subgroup)) {
                                  _subgroup = newSub.isNotEmpty ? newSub.first : null;
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (availableSubgroups.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Анатомическая подгруппа (фокус):', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: availableSubgroups.map((sg) {
                          return ChoiceChip(
                            label: Text(sg.displayName, style: const TextStyle(fontSize: 12)),
                            selected: _subgroup == sg,
                            onSelected: (val) {
                              setState(() => _subgroup = val ? sg : null);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),

                // Card 3: Инвентарь и сложность
                _buildSectionCard(
                  theme: theme,
                  title: '3. ИНВЕНТАРЬ И СЛОЖНОСТЬ',
                  icon: Icons.fitness_center,
                  children: [
                    Text('Необходимый инвентарь:', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: ExerciseEquipment.values.map((eq) {
                        return ChoiceChip(
                          label: Text(eq.displayName, style: const TextStyle(fontSize: 12)),
                          selected: _equipment == eq,
                          onSelected: (val) => setState(() => _equipment = eq),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text('Уровень сложности:', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: ExerciseDifficulty.values.map((df) {
                        return ChoiceChip(
                          label: Text(df.displayName, style: const TextStyle(fontSize: 12)),
                          selected: _difficulty == df,
                          onSelected: (val) => setState(() => _difficulty = df),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Card 4: Параметры нагрузки
                _buildSectionCard(
                  theme: theme,
                  title: '4. ПАРАМЕТРЫ НАГРУЗКИ',
                  icon: Icons.timer_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Динамика')),
                            selected: !_isStatic,
                            onSelected: (val) => setState(() => _isStatic = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Статика')),
                            selected: _isStatic,
                            onSelected: (val) => setState(() => _isStatic = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isStatic)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Время удержания:', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: theme.accent),
                                onPressed: () => setState(() => _duration = (_duration - 5).clamp(10, 180)),
                              ),
                              Text('$_duration сек', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, color: theme.accent),
                                onPressed: () => setState(() => _duration = (_duration + 5).clamp(10, 180)),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Повторы по умолчанию:', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: theme.accent),
                                onPressed: () => setState(() => _reps = (_reps - 2).clamp(2, 100)),
                              ),
                              Text('$_reps повт', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, color: theme.accent),
                                onPressed: () => setState(() => _reps = (_reps + 2).clamp(2, 100)),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),

                // Card 5: Заметки тренера / атлета
                _buildSectionCard(
                  theme: theme,
                  title: '5. МЕТОДИЧЕСКИЕ УКАЗАНИЯ',
                  icon: Icons.note_alt_outlined,
                  children: [
                    TextField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      style: TextStyle(color: theme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ощущения, положение таза, контроль дыхания, дыхательный цикл...',
                        hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5)),
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
                          borderSide: BorderSide(color: theme.accent, width: 2.0),
                        ),
                      ),
                    ),
                  ],
                ),

                // Card 6: Теги и категории
                _buildSectionCard(
                  theme: theme,
                  title: '6. ТЕГИ И КАТЕГОРИИ',
                  icon: Icons.tag,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Теги упражнения:', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          onPressed: () => _showAddTagDialog(context, theme),
                          icon: Icon(Icons.add_rounded, size: 16, color: theme.accent),
                          label: Text('Новый тег', style: TextStyle(color: theme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: allTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onLongPress: () => _showManageTagDialog(context, tag, theme),
                          onSecondaryTap: () => _showManageTagDialog(context, tag, theme),
                          child: FilterChip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  if (!_selectedTags.contains(tag)) _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Action Buttons in a single row
                Row(
                  children: [
                    if (widget.onDelete != null) ...[
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Удалить', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (cctx) => AlertDialog(
                                  backgroundColor: theme.surface,
                                  title: Text('Удалить упражнение?', style: TextStyle(color: theme.textPrimary)),
                                  content: Text(
                                    'Вы уверены, что хотите удалить упражнение «${_nameController.text.trim()}»?',
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
                                widget.onDelete!();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: () {
                            final rawName = _nameController.text.trim();
                            if (rawName.isEmpty) return;
                            final name = rawName[0].toUpperCase() + rawName.substring(1);

                            final id = widget.exercise?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
                            final tagsSet = Set<String>.from(_selectedTags);
                            tagsSet.remove('Кор и Статика');
                            tagsSet.remove('Только статика');
                            tagsSet.add(_muscle.displayName);
                            if (_isStatic) tagsSet.add('Статика');

                            final def = ExerciseDefinition(
                              id: id,
                              name: name,
                              description: _descController.text.trim(),
                              targetMuscle: _muscle,
                              subgroup: _subgroup,
                              isStatic: _isStatic,
                              defaultDurationSeconds: _duration,
                              defaultReps: _reps,
                              equipment: _equipment,
                              difficulty: _difficulty,
                              tags: tagsSet.toList(),
                              videoUrl: _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim(),
                              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                              updatedAt: DateTime.now(),
                            );

                            widget.onSave(def);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BulkImportDialog extends StatefulWidget {
  final AppThemeConfig theme;
  final void Function(List<ExerciseDefinition> exercises, bool replaceBase) onImport;

  const _BulkImportDialog({
    required this.theme,
    required this.onImport,
  });

  @override
  State<_BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<_BulkImportDialog> {
  final TextEditingController _textController = TextEditingController();
  List<ExerciseDefinition> _parsedExercises = [];
  String? _statusMessage;
  bool _isValidated = false;
  bool _replaceBase = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final raw = _textController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _statusMessage = 'Пожалуйста, вставьте текст JSON/Markdown или выберите файл.';
        _parsedExercises = [];
        _isValidated = false;
      });
      return;
    }

    try {
      final list = <ExerciseDefinition>[];
      // Try parsing as JSON first
      if (raw.startsWith('[') || raw.startsWith('{')) {
        dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('exercises') && decoded['exercises'] is List) {
            decoded = decoded['exercises'];
          } else {
            decoded = [decoded];
          }
        }
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              list.add(_parseExerciseJson(item));
            }
          }
        }
      } else {
        // Markdown / Plain text parser (bullet lists or headings)
        final lines = raw.split('\n');
        for (final l in lines) {
          var clean = l.trim();
          if (clean.isEmpty) continue;
          if (clean.startsWith('- ') || clean.startsWith('* ') || clean.startsWith('• ')) {
            clean = clean.substring(2).trim();
          }
          if (clean.isNotEmpty) {
            list.add(ExerciseDefinition(
              id: 'bulk_${DateTime.now().microsecondsSinceEpoch}_${list.length}',
              name: clean[0].toUpperCase() + clean.substring(1),
              description: '',
              targetMuscle: MuscleGroup.metabolicFullBody,
              updatedAt: DateTime.now(),
            ));
          }
        }
      }

      setState(() {
        _parsedExercises = list;
        _isValidated = true;
        _statusMessage = 'Успешно распознано: ${list.length} упражнений';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка разбора: $e';
        _parsedExercises = [];
        _isValidated = false;
      });
    }
  }

  ExerciseDefinition _parseExerciseJson(Map<String, dynamic> json) {
    MuscleGroup muscle = MuscleGroup.metabolicFullBody;
    final muscleStr = json['targetMuscle'] as String?;
    if (muscleStr != null) {
      muscle = MuscleGroup.values.firstWhere(
        (m) => m.name == muscleStr || m.displayName == muscleStr,
        orElse: () => MuscleGroup.metabolicFullBody,
      );
    }

    MuscleSubgroup? subgroup;
    final subStr = json['subgroup'] as String?;
    if (subStr != null) {
      for (final s in MuscleSubgroup.values) {
        if (s.name == subStr || s.displayName == subStr) {
          subgroup = s;
          break;
        }
      }
    }

    ExerciseEquipment eq = ExerciseEquipment.bodyweight;
    final eqStr = json['equipment'] as String?;
    if (eqStr != null) {
      eq = ExerciseEquipment.values.firstWhere(
        (e) => e.name == eqStr || e.displayName == eqStr,
        orElse: () => ExerciseEquipment.bodyweight,
      );
    }

    ExerciseDifficulty diff = ExerciseDifficulty.intermediate;
    final diffStr = json['difficulty'] as String?;
    if (diffStr != null) {
      diff = ExerciseDifficulty.values.firstWhere(
        (d) => d.name == diffStr || d.displayName == diffStr,
        orElse: () => ExerciseDifficulty.intermediate,
      );
    }

    final id = json['id'] as String? ?? 'bulk_${DateTime.now().microsecondsSinceEpoch}';
    final name = json['name'] as String? ?? 'Без названия';
    final desc = json['description'] as String? ?? '';
    final isStatic = json['isStatic'] as bool? ?? false;
    final duration = json['defaultDurationSeconds'] as int? ?? 30;
    final reps = json['defaultReps'] as int? ?? 12;
    final videoUrl = json['videoUrl'] as String?;
    final notes = json['notes'] as String?;
    final tags = (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];

    return ExerciseDefinition(
      id: id,
      name: name,
      description: desc,
      targetMuscle: muscle,
      subgroup: subgroup,
      isStatic: isStatic,
      defaultDurationSeconds: duration,
      defaultReps: reps,
      equipment: eq,
      difficulty: diff,
      tags: tags,
      videoUrl: videoUrl,
      notes: notes,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'md', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        _textController.text = content;
        _validateInput();
      }
    } catch (e) {
      setState(() => _statusMessage = 'Ошибка выбора файла: $e');
    }
  }

  void _copyAiExercisePrompt() {
    HapticFeedback.lightImpact();
    const promptText = '''
Ты профессиональный методист и тренер по фитнесу.
Сформируй список упражнений для мобильного приложения "Workout Timer" в строгом формате JSON:

```json
[
  {
    "name": "Название упражнения",
    "description": "Краткая правильная биомеханика и техника выполнения",
    "targetMuscle": "upperBody",
    "subgroup": "chest",
    "equipment": "bodyweight",
    "difficulty": "intermediate",
    "isStatic": false,
    "defaultDurationSeconds": 30,
    "defaultReps": 12,
    "tags": ["Верх", "Свой вес"]
  }
]
```

СПРАВОЧНИК ПОЛЕЙ И ДОПУСТИМЫХ ЗНАЧЕНИЙ:
1. targetMuscle (основная мышечная группа):
   - "upperBody" (Верх тела)
   - "lowerBody" (Низ тела)
   - "coreStatic" (Кор и статика)
   - "metabolicFullBody" (ВИТ / Всё тело)
2. subgroup (анатомическая подгруппа, опционально):
   - Для upperBody: "chest", "back", "shoulders", "biceps", "triceps", "forearms"
   - Для lowerBody: "quadriceps", "hamstrings", "glutes", "calves"
   - Для coreStatic: "abs", "obliques", "lowerBack", "posture"
   - Для metabolicFullBody: "hiitFull", "agilityPlyo", "cardioConditioning"
3. equipment (инвентарь):
   - "bodyweight" (Свой вес)
   - "kettlebell" (Гиря: если гиря, укажи 16 кг или 6 кг в названии/описании)
   - "resistanceBand" (Резинка)
   - "dumbbells" (Гантели)
   - "pullUpBar" (Турник)
4. difficulty: "beginner", "intermediate", "advanced"
5. isStatic: true для статических упражнений (планка, стульчик), false для динамических.
6. tags (выбирай из стандартизированных тегов):
   "Верх", "Низ", "Кор", "Full Body", "Статика", "ВИТ", "Свой вес", "Резинка", "Гимнастика", "Лимфа", "16 кг", "6 кг"
''';

    Clipboard.setData(const ClipboardData(text: promptText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Промпт для ИИ скопирован в буфер обмена!'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return AlertDialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.file_upload_outlined, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Пакетный импорт',
              style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вставьте массив JSON или список упражнений Markdown, либо выберите файл с устройства:',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textController,
                onChanged: (v) {
                  if (v.trim().isEmpty) {
                    setState(() {
                      _statusMessage = null;
                      _parsedExercises = [];
                      _isValidated = false;
                    });
                  } else {
                    _validateInput();
                  }
                },
                maxLines: 7,
                style: TextStyle(color: theme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '[\n  {\n    "name": "Отжимания",\n    "targetMuscle": "upperBody",\n    "subgroup": "chest",\n    "equipment": "bodyweight",\n    "tags": ["Верх", "Свой вес"]\n  }\n]',
                  hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: theme.surfaceSubtle,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textPrimary,
                        side: BorderSide(color: theme.cardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Выбрать файл')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent.withValues(alpha: 0.15),
                        foregroundColor: theme.accent,
                        elevation: 0,
                        side: BorderSide(color: theme.accent),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: _copyAiExercisePrompt,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Промпт для ИИ')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Import Mode Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Режим импорта:',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (final replace in const [false, true]) ...[
                          if (replace) const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _replaceBase = replace),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _replaceBase == replace
                                      ? theme.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _replaceBase == replace
                                        ? theme.accent
                                        : theme.cardBorder,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    replace ? 'Заменить' : 'Добавить',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _replaceBase == replace
                                          ? (theme.accent.computeLuminance() > 0.5
                                              ? Colors.black87
                                              : Colors.white)
                                          : theme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isValidated
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isValidated ? Colors.green : Colors.redAccent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isValidated ? Icons.check_circle_outline : Icons.error_outline,
                        color: _isValidated ? Colors.green : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _isValidated ? Colors.green : Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_parsedExercises.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Предпросмотр (${_parsedExercises.length}):',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  // Не ListView: AlertDialog запрашивает intrinsic-размеры,
                  // а вьюпорты их не поддерживают (белый экран + ошибка).
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (int idx = 0; idx < _parsedExercises.length; idx++) ...[
                          if (idx > 0) Divider(height: 1, color: theme.cardBorder),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_parsedExercises[idx].name,
                                      style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                                  Text(
                                    '${_parsedExercises[idx].targetMuscle.displayName}${_parsedExercises[idx].subgroup != null ? " • ${_parsedExercises[idx].subgroup!.displayName}" : ""}',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textSecondary,
                  side: BorderSide(color: theme.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.accent.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isValidated && _parsedExercises.isNotEmpty
                    ? () {
                        widget.onImport(_parsedExercises, _replaceBase);
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(
                  _replaceBase ? 'Заменить базу' : 'Импортировать',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
