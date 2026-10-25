import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'workout_list/workout_list_screen.dart';
import 'history/history_screen.dart';
import 'exercise_library/exercise_library_screen.dart';
import 'settings/settings_screen.dart';
import 'timer/timer_screen.dart';
import '../core/theme.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../services/widget_sync_service.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<Uri?>? _widgetClickSubscription;

  final _screens = const [
    WorkoutListScreen(),
    ExerciseLibraryScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Обработка клика по виджету на мобильных устройствах
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
      _widgetClickSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    }

    // Первичная фоновая синхронизация данных виджетов
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWidgets();
    });
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  void _syncWidgets() {
    try {
      final sessions = ref.read(historyRepositoryProvider).getSessions();
      final workouts = ref.read(workoutRepositoryProvider).getWorkouts();
      WidgetSyncService.syncAll(sessions: sessions, workouts: workouts);
    } catch (_) {}
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    if (uri.scheme != 'workout') return;

    if (uri.host == 'open_history') {
      setState(() => _currentIndex = 1);
    } else if (uri.host == 'open_home') {
      setState(() => _currentIndex = 0);
    } else if (uri.host == 'launch') {
      final idStr = uri.queryParameters['id'];
      if (idStr != null) {
        final id = int.tryParse(idStr);
        final workouts = ref.read(workoutRepositoryProvider).getWorkouts();
        final workout = workouts.where((w) => w.key == id).firstOrNull ?? workouts.firstOrNull;
        if (workout != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TimerScreen(workout: workout)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          // ДЕСКТОПНЫЙ / ВЕБ РЕЖИМ (Широкий экран): Боковая панель NavigationRail
          return Scaffold(
            backgroundColor: theme.background,
            body: Row(
              children: [
                LayoutBuilder(builder: (context, rc) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: rc.maxHeight),
                    child: IntrinsicHeight(child: NavigationRail(
                  backgroundColor: theme.surface,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: theme.accent.withValues(alpha: theme.isLight ? 0.18 : 0.2),
                  leading: Padding(
                    padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height < 500 ? 6 : 20),
                    child: CircleAvatar(
                      backgroundColor: theme.accent.withValues(alpha: 0.15),
                      child: Icon(Icons.flash_on_rounded, color: theme.accent),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.timer_outlined),
                      selectedIcon: Icon(Icons.timer),
                      label: Text('Тренировки'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.fitness_center_outlined),
                      selectedIcon: Icon(Icons.fitness_center),
                      label: Text('База'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: Text('История'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Настройки'),
                    ),
                  ],
                ))),
                )),
                VerticalDivider(thickness: 1, width: 1, color: theme.cardBorder),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }

        // МОБИЛЬНЫЙ РЕЖИМ (Смартфон): Нижняя панель с 5 вкладками
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: theme.accent.withValues(alpha: theme.isLight ? 0.18 : 0.2),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: theme.accent);
                  }
                  return IconThemeData(color: theme.isLight ? const Color(0xFF475569) : theme.textSecondary);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(color: theme.accent, fontSize: 10.5, fontWeight: FontWeight.bold);
                  }
                  return TextStyle(
                    color: theme.isLight ? const Color(0xFF334155) : theme.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  );
                }),
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) => setState(() => _currentIndex = index),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.timer_outlined),
                    selectedIcon: Icon(Icons.timer, color: theme.accent),
                    label: AppLocalizations.of(context)?.workouts ?? 'Тренировки',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.fitness_center_outlined),
                    selectedIcon: Icon(Icons.fitness_center, color: theme.accent),
                    label: 'База',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month, color: theme.accent),
                    label: AppLocalizations.of(context)?.history ?? 'История',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings, color: theme.accent),
                    label: AppLocalizations.of(context)?.settings ?? 'Настройки',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
