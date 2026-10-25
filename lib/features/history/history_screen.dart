import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/models/workout.dart';
import '../../data/models/workout_session.dart';
import '../../l10n/app_localizations.dart';

final historyProvider = Provider<List<WorkoutSession>>((ref) {
  return ref.watch(historyRepositoryProvider).getSessions();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  bool _analyticsWeekly = true;
  bool _favoritesExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  String _getMonthName(int month, AppLocalizations? l10n) {
    switch (month) {
      case 1:
        return l10n?.monthJan ?? 'Январь';
      case 2:
        return l10n?.monthFeb ?? 'Февраль';
      case 3:
        return l10n?.monthMar ?? 'Март';
      case 4:
        return l10n?.monthApr ?? 'Апрель';
      case 5:
        return l10n?.monthMay ?? 'Май';
      case 6:
        return l10n?.monthJun ?? 'Июнь';
      case 7:
        return l10n?.monthJul ?? 'Июль';
      case 8:
        return l10n?.monthAug ?? 'Август';
      case 9:
        return l10n?.monthSep ?? 'Сентябрь';
      case 10:
        return l10n?.monthOct ?? 'Октябрь';
      case 11:
        return l10n?.monthNov ?? 'Ноябрь';
      case 12:
        return l10n?.monthDec ?? 'Декабрь';
      default:
        return '';
    }
  }

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
  Widget build(BuildContext context) {
    final allSessions = ref.watch(historyProvider);
    final workoutRepo = ref.watch(workoutRepositoryProvider);
    final currentTheme = ref.watch(appThemeProvider);
    final l10n = AppLocalizations.of(context);

    final filteredSessions = _selectedDate == null
        ? allSessions
        : allSessions
            .where((s) =>
                s.startedAt.year == _selectedDate!.year &&
                s.startedAt.month == _selectedDate!.month &&
                s.startedAt.day == _selectedDate!.day)
            .toList();

    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      return Scaffold(
        backgroundColor: currentTheme.background,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Левая колонка: Календарь нормального размера + Месячная статистика (460px)
              SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.history ?? 'История',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: currentTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Календарь
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: currentTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: currentTheme.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.chevron_left,
                                      color: currentTheme.textSecondary,
                                      size: 28),
                                  onPressed: () {
                                    setState(() {
                                      _currentMonth = DateTime(
                                          _currentMonth.year,
                                          _currentMonth.month - 1);
                                    });
                                  },
                                ),
                                Text(
                                  '${_getMonthName(_currentMonth.month, l10n)} ${_currentMonth.year}',
                                  style: TextStyle(
                                      color: currentTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: Icon(Icons.chevron_right,
                                      color: currentTheme.textSecondary,
                                      size: 28),
                                  onPressed: () {
                                    setState(() {
                                      _currentMonth = DateTime(
                                          _currentMonth.year,
                                          _currentMonth.month + 1);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildCalendarGrid(allSessions, currentTheme, l10n),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Сводка за месяц
                      _buildMonthlyOverviewCard(
                          allSessions, currentTheme, l10n),
                      const SizedBox(height: 16),
                      _buildTopExercisesCard(
                          allSessions, workoutRepo, currentTheme, l10n),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // Правая колонка: Детали выбранного дня / Список сессий
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate != null
                                ? '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month, l10n)} ${_selectedDate!.year}'
                                : '${_getMonthName(_currentMonth.month, l10n)} ${_currentMonth.year}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: currentTheme.textPrimary,
                            ),
                          ),
                          if (_selectedDate != null)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedDate = null),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Сбросить фильтр'),
                              style: TextButton.styleFrom(
                                  foregroundColor: currentTheme.accent),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredSessions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedDate != null
                                          ? Icons.hotel_outlined
                                          : Icons.calendar_month,
                                      size: 56,
                                      color: Colors.white24,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _selectedDate != null
                                          ? 'В этот день тренировок не было (${_selectedDate!.day} ${_getMonthName(_selectedDate!.month, l10n)}) 😴'
                                          : 'В этом месяце пока нет завершенных тренировок',
                                      style: TextStyle(
                                          color: currentTheme.textSecondary,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Выберите день с отметкой 🔥 в календаре слева',
                                      style: TextStyle(
                                          color: currentTheme.accent
                                              .withValues(alpha: 0.8),
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: filteredSessions.length,
                                itemBuilder: (context, index) {
                                  final session = filteredSessions[index];
                                  final workout = workoutRepo
                                          .getWorkout(session.workoutId) ??
                                      workoutRepo
                                          .getWorkouts()
                                          .where((w) =>
                                              w.name.trim().toLowerCase() ==
                                              session.workoutName
                                                  .trim()
                                                  .toLowerCase())
                                          .firstOrNull;
                                  return _buildSessionCard(
                                      session, workout, currentTheme, l10n);
                                },
                              ),
                      ),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  l10n?.history ?? 'История',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: currentTheme.textPrimary,
                  ),
                ),
              ),
            ),

            // Calendar Section
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Navigation Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left,
                              color: currentTheme.textSecondary, size: 28),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(
                                  _currentMonth.year, _currentMonth.month - 1);
                            });
                          },
                        ),
                        Text(
                          '${_getMonthName(_currentMonth.month, l10n)} ${_currentMonth.year}',
                          style: TextStyle(
                              color: currentTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right,
                              color: currentTheme.textSecondary, size: 28),
                          onPressed: () {
                            setState(() {
                              _currentMonth = DateTime(
                                  _currentMonth.year, _currentMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Calendar Grid
                    _buildCalendarGrid(allSessions, currentTheme, l10n),
                    const SizedBox(height: 16),

                    // Сводка за месяц (Monthly Overview Card)
                    _buildMonthlyOverviewCard(allSessions, currentTheme, l10n),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildTopExercisesCard(
                    allSessions, workoutRepo, currentTheme, l10n),
              ),
            ),

            // Section header: selected date or all sessions of month
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month, l10n)}'
                            : '${_getMonthName(_currentMonth.month, l10n)} ${_currentMonth.year}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: currentTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _selectedDate = null),
                        icon: const Icon(Icons.close, size: 16),
                        label: Text(l10n?.allDates ?? 'Все даты'),
                        style: TextButton.styleFrom(
                          foregroundColor: currentTheme.accent,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Sessions List or Empty State
            if (filteredSessions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 28.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedDate != null
                              ? Icons.hotel_outlined
                              : Icons.calendar_month,
                          size: 64,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedDate != null
                              ? '${l10n?.noWorkoutsOnDay ?? "В этот день тренировок не было"} (${_selectedDate!.day} ${_getMonthName(_selectedDate!.month, l10n)}) 😴'
                              : (l10n?.noWorkoutsHistoryEmpty ??
                                  'Здесь появится твоя история,\nкогда ты завершишь первую тренировку'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 15),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            l10n?.selectDateTip ??
                                'Выберите дату с отметкой 🔥, чтобы посмотреть отчет',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color:
                                    currentTheme.accent.withValues(alpha: 0.8),
                                fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentTheme.accent,
                            foregroundColor:
                                currentTheme.accent.computeLuminance() > 0.5
                                    ? Colors.black87
                                    : Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text(
                            'Начать тренировку',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5),
                          ),
                          onPressed: () {
                            DefaultTabController.maybeOf(context)?.animateTo(0);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final session = filteredSessions[index];
                    final workout = workoutRepo.getWorkout(session.workoutId) ??
                        workoutRepo
                            .getWorkouts()
                            .where((w) =>
                                w.name.trim().toLowerCase() ==
                                session.workoutName.trim().toLowerCase())
                            .firstOrNull;
                    return _buildSessionCard(
                        session, workout, currentTheme, l10n);
                  },
                  childCount: filteredSessions.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    WorkoutSession session,
    Workout? workout,
    AppThemeConfig currentTheme,
    AppLocalizations? l10n,
  ) {
    final duration =
        session.finishedAt?.difference(session.startedAt) ?? Duration.zero;
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: currentTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: currentTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Icon, Name, Date/Time
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: currentTheme.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: currentTheme.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.workoutName,
                        style: TextStyle(
                            color: currentTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.startedAt.day} ${_getMonthName(session.startedAt.month, l10n)} • ${_formatTime(session.startedAt)}',
                        style: TextStyle(
                            color: currentTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (session.workoutType == WorkoutType.amrap
                            ? const Color(0xFF8B5CF6)
                            : currentTheme.accent)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.workoutType.name.toUpperCase(),
                    style: TextStyle(
                      color: session.workoutType == WorkoutType.amrap
                          ? const Color(0xFF8B5CF6)
                          : currentTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats Row: Rounds, Duration
            Row(
              children: [
                _buildMiniStat(
                  session.workoutType == WorkoutType.amrap
                      ? Icons.bolt_rounded
                      : Icons.repeat,
                  session.workoutType == WorkoutType.amrap
                      ? (session.extraReps > 0
                          ? '${session.completedRounds} ${l10n?.rounds ?? "раундов"} + ${session.extraReps} ${l10n?.repsShort ?? "повт."}'
                          : '${session.completedRounds} ${l10n?.rounds ?? "раундов"}')
                      : '${session.completedRounds}/${session.totalRounds} ${(l10n?.rounds ?? "раундов").toLowerCase()}',
                  currentTheme,
                ),
                const SizedBox(width: 16),
                _buildMiniStat(
                    Icons.timer_outlined,
                    '$mins${l10n?.minShort ?? "м"} $secs${l10n?.secShort ?? "с"}',
                    currentTheme),
              ],
            ),

            // Exercises List from the complex (Snapshots or Workout definition)
            if (session.exerciseSnapshots.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fitness_center,
                            size: 14, color: currentTheme.accent),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.completedComplex ?? 'Выполненный комплекс:',
                          style: TextStyle(
                              color: currentTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < session.exerciseSnapshots.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${i + 1}. ${session.exerciseSnapshots[i]}',
                          style: TextStyle(
                              color: currentTheme.textPrimary, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (workout != null && workout.exercises.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fitness_center,
                            size: 14, color: currentTheme.accent),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.completedComplex ?? 'Выполненный комплекс:',
                          style: TextStyle(
                              color: currentTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < workout.exercises.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${i + 1}. ${workout.exercises[i].name}${workout.exercises[i].reps != null && workout.exercises[i].reps! > 0 ? " (${workout.exercises[i].reps} ${l10n?.repsShort ?? "повт."})" : ""}${workout.exercises[i].durationSeconds != null ? " • ${workout.exercises[i].durationSeconds}${l10n?.secShort ?? "с"}" : ""}',
                          style: TextStyle(
                              color: currentTheme.textPrimary, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Tags
            if (session.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: session.tags
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: currentTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_localizedTag(tag, l10n),
                              style: TextStyle(
                                  color: currentTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
              ),
            ],

            // User's Comment / Note (Interactive View, Add, and Edit)
            const SizedBox(height: 12),
            if (session.note != null && session.note!.trim().isNotEmpty) ...[
              InkWell(
                onTap: () =>
                    _showEditCommentDialog(context, session, currentTheme),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: currentTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: currentTheme.cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 16, color: currentTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.note!,
                          style: TextStyle(
                              color: currentTheme.textPrimary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit_note_rounded,
                          size: 20, color: currentTheme.accent),
                    ],
                  ),
                ),
              ),
            ] else ...[
              InkWell(
                onTap: () =>
                    _showEditCommentDialog(context, session, currentTheme),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: currentTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: currentTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_comment_outlined,
                          size: 15, color: currentTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.addCommentHint ?? 'Добавить заметку к тренировке',
                        style: TextStyle(
                            color: currentTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCommentDialog(
    BuildContext context,
    WorkoutSession session,
    AppThemeConfig theme,
  ) async {
    final textController = TextEditingController(text: session.note ?? '');
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          children: [
            Icon(Icons.rate_review_outlined, color: theme.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Заметка к тренировке',
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
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
                session.workoutName,
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 3,
                autofocus: true,
                style: TextStyle(color: theme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'Как прошла тренировка? Самочувствие, веса, пульс...',
                  hintStyle: TextStyle(
                      color: theme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 13),
                  filled: true,
                  fillColor: theme.surfaceSubtle,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.accent, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textSecondary,
                      side: BorderSide(color: theme.cardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      l10n?.cancel ?? 'Отмена',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () async {
                      final text = textController.text.trim();
                      session.note = text.isEmpty ? null : text;
                      await ref
                          .read(historyRepositoryProvider)
                          .saveSession(session);
                      ref.invalidate(historyProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      l10n?.save ?? 'Сохранить',
                      style: TextStyle(
                        color: theme.accent.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildMiniStat(
      IconData icon, String label, AppThemeConfig currentTheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: currentTheme.textSecondary),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: currentTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildCalendarGrid(List<WorkoutSession> sessions,
      AppThemeConfig currentTheme, AppLocalizations? l10n) {
    final now = DateTime.now();
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun

    // Count sessions per day for current month
    final Map<int, int> sessionsCountPerDay = {};
    for (var session in sessions) {
      if (session.startedAt.year == _currentMonth.year &&
          session.startedAt.month == _currentMonth.month) {
        sessionsCountPerDay[session.startedAt.day] =
            (sessionsCountPerDay[session.startedAt.day] ?? 0) + 1;
      }
    }

    List<Widget> dayWidgets = [];

    // Weekday headers
    final weekdays = [
      l10n?.weekdayMon ?? 'Пн',
      l10n?.weekdayTue ?? 'Вт',
      l10n?.weekdayWed ?? 'Ср',
      l10n?.weekdayThu ?? 'Чт',
      l10n?.weekdayFri ?? 'Пт',
      l10n?.weekdaySat ?? 'Сб',
      l10n?.weekdaySun ?? 'Вс',
    ];
    for (int i = 0; i < 7; i++) {
      final isWeekend = i >= 5;
      dayWidgets.add(
        Center(
          child: Text(
            weekdays[i],
            style: TextStyle(
              color: isWeekend
                  ? Colors.redAccent.shade100
                  : currentTheme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // Empty padding slots before 1st weekday
    for (int i = 1; i < startingWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Days in Month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isWeekend = date.weekday >= 6;
      final count = sessionsCountPerDay[day] ?? 0;
      final isToday = day == now.day &&
          _currentMonth.month == now.month &&
          _currentMonth.year == now.year;
      final isSelected = _selectedDate != null &&
          _selectedDate!.year == date.year &&
          _selectedDate!.month == date.month &&
          _selectedDate!.day == date.day;

      dayWidgets.add(
        InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDate = null; // Toggle off to view all
              } else {
                _selectedDate = date;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? currentTheme.accent.withValues(alpha: 0.3)
                  : (isToday
                      ? currentTheme.surfaceSubtle
                      : currentTheme.surface.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: currentTheme.accent, width: 2)
                  : (isToday
                      ? Border.all(color: currentTheme.cardBorder, width: 1.5)
                      : null),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: currentTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected
                          ? (currentTheme.accent.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white)
                          : (isWeekend
                              ? Colors.redAccent
                              : currentTheme.textPrimary),
                      fontWeight: isSelected || isToday || count > 0
                          ? FontWeight.w900
                          : FontWeight.bold,
                      fontSize: 18,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                if (count > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      count == 1 ? '🔥' : (count == 2 ? '🔥🔥' : '🔥🔥🔥'),
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                    ),
                  )
                else
                  const SizedBox(height: 14), // uniform height placeholder
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 0.80,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }

  Widget _buildMonthlyOverviewCard(
    List<WorkoutSession> allSessions,
    AppThemeConfig currentTheme,
    AppLocalizations? l10n,
  ) {
    final sessionsThisMonth = allSessions
        .where((s) =>
            s.startedAt.year == _currentMonth.year &&
            s.startedAt.month == _currentMonth.month)
        .toList();

    int totalDurationMins = 0;
    for (final s in sessionsThisMonth) {
      if (s.finishedAt != null) {
        totalDurationMins += s.finishedAt!.difference(s.startedAt).inMinutes;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: currentTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded,
                  color: currentTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Статистика за ${_getMonthName(_currentMonth.month, l10n)}',
                style: TextStyle(
                    color: currentTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${sessionsThisMonth.length}',
                    style: TextStyle(
                        color: currentTheme.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text('Тренировок',
                      style: TextStyle(
                          color: currentTheme.textSecondary, fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  Text(
                    totalDurationMins > 60
                        ? '${totalDurationMins ~/ 60} ч ${totalDurationMins % 60} мин'
                        : '$totalDurationMins мин',
                    style: TextStyle(
                        color: currentTheme.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text('Времени',
                      style: TextStyle(
                          color: currentTheme.textSecondary, fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  Text(
                    '~${totalDurationMins * 9}',
                    style: TextStyle(
                        color: currentTheme.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text('ккал',
                      style: TextStyle(
                          color: currentTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopExercisesCard(
    List<WorkoutSession> allSessions,
    WorkoutRepository workoutRepo,
    AppThemeConfig currentTheme,
    AppLocalizations? l10n,
  ) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final periodSessions = _analyticsWeekly
        ? allSessions
            .where((s) =>
                !s.startedAt.isBefore(startOfWeek) &&
                s.startedAt.isBefore(endOfWeek))
            .toList()
        : allSessions
            .where((s) =>
                s.startedAt.year == _currentMonth.year &&
                s.startedAt.month == _currentMonth.month)
            .toList();

    // Map of exercise name -> stats
    final Map<String, _ExerciseStat> statsMap = {};
    for (final session in periodSessions) {
      final workout = workoutRepo.getWorkout(session.workoutId) ??
          workoutRepo
              .getWorkouts()
              .where((w) =>
                  w.name.trim().toLowerCase() ==
                  session.workoutName.trim().toLowerCase())
              .firstOrNull;

      if (session.exerciseSnapshots.isNotEmpty) {
        final numSnapshots = session.exerciseSnapshots.length;
        int circuits = 1;
        if (session.completedRounds > 0 && numSnapshots > 0) {
          if (session.completedRounds >= numSnapshots) {
            circuits = (session.completedRounds / numSnapshots).floor();
            if (circuits < 1) circuits = 1;
          } else {
            circuits = 1;
          }
        }

        for (int i = 0; i < session.exerciseSnapshots.length; i++) {
          final raw = session.exerciseSnapshots[i];
          String cleanName = raw.trim();
          cleanName = cleanName.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '');

          int itemReps = 0;
          int itemSec = 0;
          final repsMatch = RegExp(r'\((\d+)\s*повт\.\)').firstMatch(cleanName);
          final secMatch = RegExp(r'\((\d+)\s*сек\)').firstMatch(cleanName);
          if (repsMatch != null) {
            itemReps = int.tryParse(repsMatch.group(1)!) ?? 0;
            cleanName = cleanName.replaceAll(repsMatch.group(0)!, '').trim();
          } else if (secMatch != null) {
            itemSec = int.tryParse(secMatch.group(1)!) ?? 0;
            cleanName = cleanName.replaceAll(secMatch.group(0)!, '').trim();
          }

          int exerciseOccurrences = circuits;
          if (session.completedRounds > numSnapshots) {
            final remainder = session.completedRounds % numSnapshots;
            if (i < remainder) {
              exerciseOccurrences += 1;
            }
          }

          final stat =
              statsMap.putIfAbsent(cleanName, () => _ExerciseStat(cleanName));
          stat.reps += (itemReps > 0 ? itemReps * exerciseOccurrences : 0);
          stat.durationSeconds +=
              (itemSec > 0 ? itemSec * exerciseOccurrences : 0);
          stat.setsCount += exerciseOccurrences;
          stat.sessionsCount += 1;
          if (itemSec > 0) stat.isStatic = true;
        }
      } else if (workout != null && workout.exercises.isNotEmpty) {
        final numEx = workout.exercises.length;
        int circuits = 1;
        if (session.completedRounds > 0 && numEx > 0) {
          if (session.completedRounds >= numEx) {
            circuits = (session.completedRounds / numEx).floor();
            if (circuits < 1) circuits = 1;
          } else {
            circuits = 1;
          }
        }

        for (int i = 0; i < workout.exercises.length; i++) {
          final ex = workout.exercises[i];
          final cleanName = ex.name.trim();

          int exerciseOccurrences = circuits;
          if (session.completedRounds > numEx) {
            final remainder = session.completedRounds % numEx;
            if (i < remainder) {
              exerciseOccurrences += 1;
            }
          }

          final stat =
              statsMap.putIfAbsent(cleanName, () => _ExerciseStat(cleanName));
          if (ex.reps != null && ex.reps! > 0) {
            stat.reps += ex.reps! * exerciseOccurrences;
          } else if (ex.durationSeconds != null && ex.durationSeconds! > 0) {
            stat.durationSeconds += ex.durationSeconds! * exerciseOccurrences;
            stat.isStatic = true;
          }
          stat.setsCount += exerciseOccurrences;
          stat.sessionsCount += 1;
        }
      }
    }

    final sortedStats = statsMap.values.toList()
      ..sort((a, b) {
        final metricA = a.reps > 0 ? a.reps : a.setsCount * 10;
        final metricB = b.reps > 0 ? b.reps : b.setsCount * 10;
        return metricB.compareTo(metricA);
      });

    final topExercises = sortedStats.take(5).toList();
    final maxMetric = topExercises.isNotEmpty
        ? (topExercises.first.reps > 0
            ? topExercises.first.reps
            : topExercises.first.setsCount * 10)
        : 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: currentTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: currentTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _favoritesExpanded = !_favoritesExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: currentTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Избранное',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: currentTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Переключатель Неделя / Месяц
                  if (_favoritesExpanded)
                    Container(
                      decoration: BoxDecoration(
                        color: currentTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: currentTheme.cardBorder),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                setState(() => _analyticsWeekly = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _analyticsWeekly
                                    ? currentTheme.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Неделя',
                                style: TextStyle(
                                  color: _analyticsWeekly
                                      ? (currentTheme.accent
                                                  .computeLuminance() >
                                              0.5
                                          ? Colors.black87
                                          : Colors.white)
                                      : currentTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                setState(() => _analyticsWeekly = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_analyticsWeekly
                                    ? currentTheme.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Месяц',
                                style: TextStyle(
                                  color: !_analyticsWeekly
                                      ? (currentTheme.accent
                                                  .computeLuminance() >
                                              0.5
                                          ? Colors.black87
                                          : Colors.white)
                                      : currentTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_favoritesExpanded)
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: currentTheme.textSecondary),
                ],
              )),
          if (_favoritesExpanded) ...[
            const SizedBox(height: 14),
            if (topExercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.fitness_center_outlined,
                          color:
                              currentTheme.textSecondary.withValues(alpha: 0.4),
                          size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _analyticsWeekly
                            ? 'На этой неделе пока нет завершённых упражнений'
                            : 'В этом месяце пока нет завершённых упражнений',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: currentTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(topExercises.length, (idx) {
                final item = topExercises[idx];
                final itemMetric =
                    item.reps > 0 ? item.reps : item.setsCount * 10;
                final double ratio = maxMetric > 0
                    ? (itemMetric / maxMetric).clamp(0.12, 1.0)
                    : 1.0;
                final int percent = maxMetric > 0
                    ? ((itemMetric / maxMetric) * 100).round()
                    : 100;

                Color rankColor = currentTheme.accent;
                if (idx == 0) {
                  rankColor = const Color(0xFFFFD700);
                } else if (idx == 1) {
                  rankColor = const Color(0xFFC0C0C0);
                } else if (idx == 2) {
                  rankColor = const Color(0xFFCD7F32);
                }

                final isKettlebell16 =
                    item.name.contains('16 кг') || item.name.contains('16кг');
                final isKettlebell6 =
                    item.name.contains('6 кг') || item.name.contains('6кг');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: rankColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '#${idx + 1}',
                              style: TextStyle(
                                  color: rankColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      color: currentTheme.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isKettlebell16) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.amber
                                              .withValues(alpha: 0.6)),
                                    ),
                                    child: const Text('16 кг',
                                        style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ] else if (isKettlebell6) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.cyanAccent
                                              .withValues(alpha: 0.6)),
                                    ),
                                    child: const Text('6 кг',
                                        style: TextStyle(
                                            color: Colors.cyanAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.reps > 0
                                ? '${item.reps} повт.'
                                : (item.durationSeconds > 0
                                    ? (item.durationSeconds >= 60
                                        ? '${item.durationSeconds ~/ 60}м ${item.durationSeconds % 60}с'
                                        : '${item.durationSeconds}с')
                                    : '${item.setsCount} подх.'),
                            style: TextStyle(
                              color: currentTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: currentTheme.surfaceSubtle,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    currentTheme.accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '$percent%',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: currentTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _ExerciseStat {
  final String name;
  int reps = 0;
  int durationSeconds = 0;
  int setsCount = 0;
  int sessionsCount = 0;
  bool isStatic = false;

  _ExerciseStat(this.name);
}
