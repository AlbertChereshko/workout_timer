enum TimerPhase { countdown, work, rest, finished }

class TimerState {
  final TimerPhase phase;
  final int currentRound;
  final int totalRounds;
  final int remainingSeconds;
  final int totalPhaseSeconds;
  final bool isRunning;
  final int currentExerciseIndex;
  final int extraReps;

  TimerState({
    required this.phase,
    required this.currentRound,
    required this.totalRounds,
    required this.remainingSeconds,
    required this.totalPhaseSeconds,
    required this.isRunning,
    this.currentExerciseIndex = 0,
    this.extraReps = 0,
  });

  TimerState copyWith({
    TimerPhase? phase,
    int? currentRound,
    int? totalRounds,
    int? remainingSeconds,
    int? totalPhaseSeconds,
    bool? isRunning,
    int? currentExerciseIndex,
    int? extraReps,
  }) {
    return TimerState(
      phase: phase ?? this.phase,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalPhaseSeconds: totalPhaseSeconds ?? this.totalPhaseSeconds,
      isRunning: isRunning ?? this.isRunning,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      extraReps: extraReps ?? this.extraReps,
    );
  }
}
