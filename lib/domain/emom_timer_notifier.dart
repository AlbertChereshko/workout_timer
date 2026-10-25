import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'timer_state.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/models/workout.dart';
import '../data/models/workout_session.dart';
import '../data/repositories/history_repository.dart';

class TimerNotifier extends StateNotifier<TimerState> {
  final Ref ref;
  Timer? _timer;
  Workout? _workout;
  WorkoutSession? lastSession;
  DateTime? _startedAt;
  DateTime? _phaseEndTime;
  int? _lastAnnouncedSec;
  
  TimerNotifier(this.ref) : super(TimerState(
    phase: TimerPhase.countdown,
    currentRound: 1,
    totalRounds: 1,
    remainingSeconds: 3,
    totalPhaseSeconds: 3,
    isRunning: false,
  )) {
    AudioService().init();
  }

  void loadWorkout(Workout workout) {
    _timer?.cancel();
    _phaseEndTime = null;
    _lastAnnouncedSec = null;
    _workout = workout;
    _startedAt = null;
    AudioService().applyWorkoutTypeSoundProfile(workout.type);
    
    int totalRounds = 1;
    int initialRound = 1;
    if (workout.type == WorkoutType.emom) {
      totalRounds = workout.emomRounds;
    } else if (workout.type == WorkoutType.amrap) {
      totalRounds = 0; // In AMRAP, total completed rounds start at 0 and count up
      initialRound = 0;
    } else {
      totalRounds = workout.tabataRounds;
    }

    state = TimerState(
      phase: TimerPhase.countdown,
      currentRound: initialRound,
      totalRounds: totalRounds,
      remainingSeconds: 3,
      totalPhaseSeconds: 3,
      isRunning: false,
      currentExerciseIndex: 0,
      extraReps: 0,
    );
  }

  void start() {
    if (state.isRunning || state.phase == TimerPhase.finished) return;
    _startedAt ??= DateTime.now();
    _phaseEndTime = DateTime.now().add(Duration(seconds: state.remainingSeconds));
    state = state.copyWith(isRunning: true);
    _safeWakelock(true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), _tick);
  }

  void pause() {
    _timer?.cancel();
    _phaseEndTime = null;
    _lastAnnouncedSec = null;
    state = state.copyWith(isRunning: false);
    _safeWakelock(false);
  }

  void resume() => start();
  
  void toggle() {
    if (state.isRunning) {
      pause();
    } else {
      start();
    }
  }

  void restart() {
    if (_workout != null) {
      loadWorkout(_workout!);
      start();
    }
  }

  void skipNext() {
    if (state.phase == TimerPhase.finished) return;
    _nextPhase();
  }

  void skipPrevious() {
    if (state.phase == TimerPhase.finished || _workout == null) return;
    
    // Если прошло больше 3 секунд от текущей фазы, просто сбрасываем текущую фазу в начало
    final elapsedInPhase = state.totalPhaseSeconds - state.remainingSeconds;
    if (elapsedInPhase > 3 || state.currentRound <= 1) {
      _resetCurrentPhase();
      return;
    }

    // Иначе переходим на предыдущий раунд
    final prevRound = state.currentRound - 1;
    final workTime = _getWorkTime(prevRound);
    _lastAnnouncedSec = null;
    state = state.copyWith(
      phase: TimerPhase.work,
      currentRound: prevRound,
      remainingSeconds: workTime,
      totalPhaseSeconds: workTime,
    );
    if (state.isRunning) {
      _phaseEndTime = DateTime.now().add(Duration(seconds: workTime));
    }
  }

  void _resetCurrentPhase() {
    _lastAnnouncedSec = null;
    state = state.copyWith(remainingSeconds: state.totalPhaseSeconds);
    if (state.isRunning) {
      _phaseEndTime = DateTime.now().add(Duration(seconds: state.totalPhaseSeconds));
    }
  }

  void _tick(Timer timer) {
    if (_phaseEndTime == null) return;
    final diffMs = _phaseEndTime!.difference(DateTime.now()).inMilliseconds;
    final remaining = (diffMs / 1000).ceil();

    if (remaining <= 0) {
      _nextPhase();
    } else if (remaining != state.remainingSeconds) {
      state = state.copyWith(remainingSeconds: remaining);
      if (remaining <= 3 && _lastAnnouncedSec != remaining) {
        _lastAnnouncedSec = remaining;
        AudioService().announceCountdown(remaining);
      }
    }
  }

  Exercise? _getExercise(int round) {
    if (_workout == null || _workout!.exercises.isEmpty) return null;
    final index = (round - 1) % _workout!.exercises.length;
    return _workout!.exercises[index];
  }

  String? _getExerciseName(int round) {
    final ex = _getExercise(round);
    if (ex == null) return null;
    if (ex.reps != null && ex.reps! > 0) {
      return '${ex.name}, ${ex.reps} повторений';
    }
    return ex.name;
  }

  int _getWorkTime(int round) {
    if (_workout == null) return 30;
    if (_workout!.type == WorkoutType.amrap) {
      return _workout!.amrapDurationSeconds;
    }
    final ex = _getExercise(round);
    if (ex != null && ex.durationSeconds != null && ex.durationSeconds! > 0) {
      return ex.durationSeconds!;
    }
    return _workout!.type == WorkoutType.emom 
        ? _workout!.emomRoundDurationSeconds 
        : _workout!.tabataWorkSeconds;
  }

  void recordAmrapRound() {
    if (_workout?.type != WorkoutType.amrap || state.phase != TimerPhase.work) return;
    final nextRound = state.currentRound + 1;
    state = state.copyWith(
      currentRound: nextRound,
      currentExerciseIndex: 0,
      extraReps: 0,
    );
    HapticFeedback.heavyImpact();
    AudioService().speak('Раунд $nextRound');
  }

  void recordAmrapExercise() {
    if (_workout?.type != WorkoutType.amrap || state.phase != TimerPhase.work) return;
    final exercises = _workout?.exercises ?? [];
    if (exercises.isEmpty) {
      recordAmrapRound();
      return;
    }
    
    final nextIdx = state.currentExerciseIndex + 1;
    if (nextIdx >= exercises.length) {
      // Loop finished, round completed
      final nextRound = state.currentRound + 1;
      state = state.copyWith(
        currentRound: nextRound,
        currentExerciseIndex: 0,
        extraReps: 0,
      );
      HapticFeedback.heavyImpact();
      AudioService().speak('Раунд $nextRound');
    } else {
      state = state.copyWith(
        currentExerciseIndex: nextIdx,
        extraReps: nextIdx,
      );
      HapticFeedback.mediumImpact();
      final ex = exercises[nextIdx];
      AudioService().speak(ex.name);
    }
  }

  void _nextPhase() {
    if (_workout == null) return;
    _lastAnnouncedSec = null;

    if (state.phase == TimerPhase.countdown) {
      final workTime = _getWorkTime(1);
      final exerciseName = _workout!.type == WorkoutType.amrap
          ? (_workout!.exercises.isNotEmpty ? _workout!.exercises.first.name : null)
          : _getExerciseName(1);

      AudioService().announceStart(exerciseName);
      NotificationService().showPhaseTransitionNotification(
        title: '🔥 Работа началась!',
        body: exerciseName ?? 'Раунд 1',
      );
          
      state = state.copyWith(
        phase: TimerPhase.work,
        remainingSeconds: workTime,
        totalPhaseSeconds: workTime,
        currentExerciseIndex: 0,
        extraReps: 0,
      );
      if (state.isRunning) {
        _phaseEndTime = DateTime.now().add(Duration(seconds: workTime));
      }
    } else if (state.phase == TimerPhase.work) {
      if (_workout!.type == WorkoutType.amrap) {
        _finish();
      } else if (_workout!.type == WorkoutType.tabata) {
        AudioService().announceRest();
        AudioService().announceRoundComplete(state.currentRound);
        NotificationService().showPhaseTransitionNotification(
          title: '🧘 Отдых!',
          body: 'Раунд ${state.currentRound} из ${state.totalRounds} завершён',
        );
        final restTime = _workout!.tabataRestSeconds;
        state = state.copyWith(
          phase: TimerPhase.rest,
          remainingSeconds: restTime,
          totalPhaseSeconds: restTime,
        );
        if (state.isRunning) {
          _phaseEndTime = DateTime.now().add(Duration(seconds: restTime));
        }
      } else {
        if (state.currentRound < state.totalRounds) {
          final nextRound = state.currentRound + 1;
          final exerciseName = _getExerciseName(nextRound);
          AudioService().announceStart(exerciseName);
          AudioService().announceRoundComplete(state.currentRound);
          NotificationService().showPhaseTransitionNotification(
            title: '🔥 Раунд $nextRound!',
            body: exerciseName ?? 'Интервал начался',
          );
          final workTime = _getWorkTime(nextRound);
          state = state.copyWith(
            phase: TimerPhase.work,
            currentRound: nextRound,
            remainingSeconds: workTime,
            totalPhaseSeconds: workTime,
          );
          if (state.isRunning) {
            _phaseEndTime = DateTime.now().add(Duration(seconds: workTime));
          }
        } else {
          _finish();
        }
      }
    } else if (state.phase == TimerPhase.rest) {
      if (state.currentRound < state.totalRounds) {
        final nextRound = state.currentRound + 1;
        final exerciseName = _getExerciseName(nextRound);
        AudioService().announceStart(exerciseName);
        NotificationService().showPhaseTransitionNotification(
          title: '🔥 Раунд $nextRound!',
          body: exerciseName ?? 'Работа началась',
        );
        final workTime = _getWorkTime(nextRound);
        state = state.copyWith(
          phase: TimerPhase.work,
          currentRound: nextRound,
          remainingSeconds: workTime,
          totalPhaseSeconds: workTime,
        );
        if (state.isRunning) {
          _phaseEndTime = DateTime.now().add(Duration(seconds: workTime));
        }
      } else {
        _finish();
      }
    }
  }

  Future<void> _finish() async {
    AudioService().announceFinish();
    NotificationService().showPhaseTransitionNotification(
      title: '🏆 Тренировка завершена!',
      body: 'Отличная работа! Все раунды выполнены.',
    );
    _timer?.cancel();
    _phaseEndTime = null;
    _lastAnnouncedSec = null;
    state = state.copyWith(
      phase: TimerPhase.finished,
      remainingSeconds: 0,
      isRunning: false,
    );
    _safeWakelock(false);
    
    // Save to history
    if (_workout != null && _startedAt != null) {
      final key = (_workout!.key is int) ? (_workout!.key as int) : 0;
      final snapshots = _workout?.exercises.map((e) {
        final repsStr = (e.reps != null && e.reps! > 0) ? ' (${e.reps} повт.)' : '';
        final timeStr = (e.durationSeconds != null && e.durationSeconds! > 0) ? ' • ${e.durationSeconds}с' : '';
        return '${e.name}$repsStr$timeStr';
      }).toList() ?? [];

      final completedRounds = _workout!.type == WorkoutType.amrap
          ? state.currentRound
          : state.totalRounds;
      final totalRounds = _workout!.type == WorkoutType.amrap
          ? state.currentRound
          : state.totalRounds;

      lastSession = WorkoutSession()
        ..workoutId = key
        ..workoutName = _workout!.name
        ..workoutType = _workout!.type
        ..startedAt = _startedAt!
        ..finishedAt = DateTime.now()
        ..completedRounds = completedRounds
        ..totalRounds = totalRounds
        ..extraReps = state.extraReps
        ..tags = _workout!.tags
        ..exerciseSnapshots = snapshots
        ..isCompleted = true;
        
      try {
        await ref.read(historyRepositoryProvider).saveSession(lastSession!);
      } catch (_) {
        // Box not opened in test environment
      }
    }
  }

  Future<void> finishEarly() async {
    _timer?.cancel();
    _phaseEndTime = null;
    _lastAnnouncedSec = null;
    _safeWakelock(false);

    if (_workout != null && _startedAt != null) {
      final key = (_workout!.key is int) ? (_workout!.key as int) : 0;
      final snapshots = _workout?.exercises.map((e) {
        final repsStr = (e.reps != null && e.reps! > 0) ? ' (${e.reps} повт.)' : '';
        final timeStr = (e.durationSeconds != null && e.durationSeconds! > 0) ? ' • ${e.durationSeconds}с' : '';
        return '${e.name}$repsStr$timeStr';
      }).toList() ?? [];

      final isAmrap = _workout!.type == WorkoutType.amrap;
      final completedRounds = state.currentRound;
      final totalRounds = isAmrap ? state.currentRound : state.totalRounds;

      lastSession = WorkoutSession()
        ..workoutId = key
        ..workoutName = _workout!.name
        ..workoutType = _workout!.type
        ..startedAt = _startedAt!
        ..finishedAt = DateTime.now()
        ..completedRounds = completedRounds
        ..totalRounds = totalRounds
        ..extraReps = state.extraReps
        ..tags = _workout!.tags
        ..exerciseSnapshots = snapshots
        ..isCompleted = isAmrap ? true : (state.currentRound >= state.totalRounds);

      try {
        await ref.read(historyRepositoryProvider).saveSession(lastSession!);
      } catch (_) {
        // Box not opened in test environment
      }
    }

    state = state.copyWith(
      phase: TimerPhase.finished,
      remainingSeconds: 0,
      isRunning: false,
    );
  }
  
  void _safeWakelock(bool enable) {
    try {
      if (enable) {
        WakelockPlus.enable().catchError((_) {});
      } else {
        WakelockPlus.disable().catchError((_) {});
      }
    } catch (_) {
      // Ignored in test/headless environments
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phaseEndTime = null;
    _safeWakelock(false);
    super.dispose();
  }
}

final activeTimerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(ref);
});
