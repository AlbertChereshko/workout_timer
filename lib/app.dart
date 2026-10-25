import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/locale_provider.dart';
import 'features/home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

class WorkoutTimerApp extends ConsumerStatefulWidget {
  const WorkoutTimerApp({super.key});

  @override
  ConsumerState<WorkoutTimerApp> createState() => _WorkoutTimerAppState();
}

class _WorkoutTimerAppState extends ConsumerState<WorkoutTimerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    ref.read(appThemeProvider.notifier).updateForSystemBrightness(brightness);
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(appThemeProvider);
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Workout Timer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getThemeData(themeConfig),
      locale: currentLocale,
      home: const HomeScreen(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
        Locale('de'),
        Locale('hr'),
      ],
    );
  }
}
