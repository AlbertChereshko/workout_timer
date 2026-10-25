import os

files = {
    "lib/domain/timer_state.dart": """enum TimerPhase { countdown, work, rest, finished }

class TimerState {
  final TimerPhase phase;
  final int currentRound;
  final int totalRounds;
  final int remainingSeconds;
  final int totalPhaseSeconds;
  final bool isRunning;

  TimerState({
    required this.phase,
    required this.currentRound,
    required this.totalRounds,
    required this.remainingSeconds,
    required this.totalPhaseSeconds,
    required this.isRunning,
  });

  TimerState copyWith({
    TimerPhase? phase,
    int? currentRound,
    int? totalRounds,
    int? remainingSeconds,
    int? totalPhaseSeconds,
    bool? isRunning,
  }) {
    return TimerState(
      phase: phase ?? this.phase,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalPhaseSeconds: totalPhaseSeconds ?? this.totalPhaseSeconds,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}
""",
    "lib/features/timer/animated_background.dart": """import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../domain/timer_state.dart';

class AnimatedBackground extends StatelessWidget {
  final TimerPhase phase;
  final double progress; // 0.0 to 1.0

  const AnimatedBackground({
    super.key,
    required this.phase,
    required this.progress,
  });

  Color _getPhaseColor() {
    switch (phase) {
      case TimerPhase.countdown:
        return AppTheme.countdownPhase;
      case TimerPhase.work:
        return AppTheme.workPhase;
      case TimerPhase.rest:
        return AppTheme.restPhase;
      case TimerPhase.finished:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetColor = _getPhaseColor();
    // Invert progress so it fills bottom up as time passes
    // progress is remaining / total, so we want (1 - progress) to be the fill amount
    final fillAmount = 1.0 - progress; 

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 300),
      tween: ColorTween(end: targetColor),
      builder: (context, color, child) {
        return Stack(
          children: [
            Container(color: AppTheme.background), // Base background
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100), // smooth ticking
                height: MediaQuery.of(context).size.height * fillAmount,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: (color ?? targetColor).withOpacity(0.30), // Max 30% opacity
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
""",
    "lib/features/timer/timer_screen.dart": """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/timer_state.dart';
import 'animated_background.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Dummy provider for UI testing
final dummyTimerProvider = StateProvider<TimerState>((ref) {
  return TimerState(
    phase: TimerPhase.work,
    currentRound: 1,
    totalRounds: 10,
    remainingSeconds: 45,
    totalPhaseSeconds: 60,
    isRunning: true,
  );
});

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dummyTimerProvider);
    final progress = state.remainingSeconds / state.totalPhaseSeconds;
    
    // final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(
            phase: state.phase,
            progress: progress.clamp(0.0, 1.0),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.phase.name.toUpperCase(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 15,
                          backgroundColor: Colors.white12,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${state.remainingSeconds}',
                        style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'ROUND ${state.currentRound} / ${state.totalRounds}',
                  style: const TextStyle(fontSize: 24, color: Colors.white70),
                ),
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                         // toggle
                         ref.read(dummyTimerProvider.notifier).update((s) => s.copyWith(isRunning: !s.isRunning));
                      },
                      child: Icon(state.isRunning ? Icons.pause : Icons.play_arrow),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
"""
}

for path, content in files.items():
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else '.', exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)

print("Timer features created!")
