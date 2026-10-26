import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/workout.dart';

class WarmupExercise {
  final String title;
  final String description;
  final String backProtectionTip;
  final int durationSeconds;
  final IconData icon;

  const WarmupExercise({
    required this.title,
    required this.description,
    required this.backProtectionTip,
    this.durationSeconds = 30,
    required this.icon,
  });

  WarmupExercise copyWith({
    String? title,
    String? description,
    String? backProtectionTip,
    int? durationSeconds,
    IconData? icon,
  }) {
    return WarmupExercise(
      title: title ?? this.title,
      description: description ?? this.description,
      backProtectionTip: backProtectionTip ?? this.backProtectionTip,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'backProtectionTip': backProtectionTip,
    'durationSeconds': durationSeconds,
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
  };

  static IconData _resolveIcon(int? codePoint) {
    if (codePoint == Icons.sync_rounded.codePoint) return Icons.sync_rounded;
    if (codePoint == Icons.waves_rounded.codePoint) return Icons.waves_rounded;
    if (codePoint == Icons.pan_tool_alt_rounded.codePoint) return Icons.pan_tool_alt_rounded;
    if (codePoint == Icons.directions_walk_rounded.codePoint) return Icons.directions_walk_rounded;
    if (codePoint == Icons.self_improvement_rounded.codePoint) return Icons.self_improvement_rounded;
    if (codePoint == Icons.sports_gymnastics_rounded.codePoint) return Icons.sports_gymnastics_rounded;
    if (codePoint == Icons.fitness_center_rounded.codePoint) return Icons.fitness_center_rounded;
    if (codePoint == Icons.airline_seat_legroom_extra_rounded.codePoint) return Icons.airline_seat_legroom_extra_rounded;
    if (codePoint == Icons.replay_circle_filled_rounded.codePoint) return Icons.replay_circle_filled_rounded;
    return Icons.accessibility_rounded;
  }

  factory WarmupExercise.fromJson(Map<String, dynamic> json) {
    return WarmupExercise(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      backProtectionTip: json['backProtectionTip'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 30,
      icon: _resolveIcon(json['iconCodePoint'] as int?),
    );
  }
}

class WarmupService {
  static const List<WarmupExercise> warmup3Min = [
    WarmupExercise(
      title: 'Вращения плеч и шеи',
      description: 'Плавные круговые движения плечами назад и вперед, мягкие наклоны головы.',
      backProtectionTip: 'Держите спину ровной, не запрокидывайте шею резко назад.',
      icon: Icons.accessibility_rounded,
    ),
    WarmupExercise(
      title: 'Вращения таза и бёдер',
      description: 'Широкие круговые движения тазом по часовой и против часовой стрелки.',
      backProtectionTip: 'Снимает компрессию с пояснично-крестцового отдела позвоночника.',
      icon: Icons.sync_rounded,
    ),
    WarmupExercise(
      title: '«Кошка — Собака» (волна позвоночника)',
      description: 'В наклоне с упором на колени или бедра: мягкое прогибание на вдохе и округление на выдохе.',
      backProtectionTip: 'Ключевое упражнение: бережно питает межпозвонковые диски.',
      icon: Icons.waves_rounded,
    ),
    WarmupExercise(
      title: 'Наклоны «Гудморнинг» с прямой спиной',
      description: 'Руки за головой или на груди, колени чуть согнуты, отводим таз назад, сгибаясь в тазобедренных суставах.',
      backProtectionTip: 'Спина строго прямая! Разогревает мышцы-разгибатели поясницы.',
      icon: Icons.pan_tool_alt_rounded,
    ),
    WarmupExercise(
      title: 'Вращения коленей и голеностопов',
      description: 'Ноги вместе, руки на коленях — мягкие круговые вращения. Затем круговые движения стопой.',
      backProtectionTip: 'Вырабатывает суставную смазку перед ударной нагрузкой.',
      icon: Icons.directions_walk_rounded,
    ),
    WarmupExercise(
      title: 'Мягкие приседания с вытяжением',
      description: 'Неглубокий присед, на подъеме — потянуться руками вверх, расправляя грудной отдел.',
      backProtectionTip: 'Колени сонаправлены носкам, не круглите поясницу внизу.',
      icon: Icons.self_improvement_rounded,
    ),
  ];

  static const List<WarmupExercise> warmup5Min = [
    ...warmup3Min,
    WarmupExercise(
      title: 'Выпад с раскрытием грудного отдела',
      description: 'Широкий шаг назад, раскрываем руки в стороны и мягко скручиваем корпус в сторону передней ноги.',
      backProtectionTip: 'Растягивает подвздошно-поясничную мышцу, из-за спазма которой болит поясница.',
      icon: Icons.open_in_full_rounded,
    ),
    WarmupExercise(
      title: '«Мельница» (динамические скручивания)',
      description: 'Широкая стойка, поочередное касание рукой противоположной стопы с поворотом корпуса.',
      backProtectionTip: 'Вращение за счет грудного отдела, поясницу держите стабильной.',
      icon: Icons.loop_rounded,
    ),
    WarmupExercise(
      title: 'Активация ягодичных мышц',
      description: 'Отведение бедра назад с паузой и напряжением ягодицы (или ягодичный мостик стоя/на коврике).',
      backProtectionTip: 'Включенные ягодицы разгружают поясницу на 50% во время основных сетов.',
      icon: Icons.fitness_center_rounded,
    ),
    WarmupExercise(
      title: 'Легкий бег / переступания на месте',
      description: 'Мягкий бег на носках с расслабленными руками и дыханием для прогрева связок.',
      backProtectionTip: 'Приземляйтесь мягко на переднюю часть стопы без удара в позвоночник.',
      icon: Icons.directions_run_rounded,
    ),
  ];

  static List<WarmupExercise> getExercisesForDuration(int totalSeconds) {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final key = totalSeconds <= 180 ? 'custom_warmup_3min' : 'custom_warmup_5min';
        final raw = box.get(key);
        if (raw is List && raw.isNotEmpty) {
          return raw.map((item) => WarmupExercise.fromJson(Map<String, dynamic>.from(item as Map))).toList();
        }
      }
    } catch (_) {}
    if (totalSeconds <= 180) {
      return List<WarmupExercise>.from(warmup3Min);
    }
    return List<WarmupExercise>.from(warmup5Min);
  }

  static Future<void> saveCustomExercises(int totalSeconds, List<WarmupExercise> exercises) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final key = totalSeconds <= 180 ? 'custom_warmup_3min' : 'custom_warmup_5min';
        final data = exercises.map((e) => e.toJson()).toList();
        await box.put(key, data);
      }
    } catch (_) {}
  }

  static Future<void> resetToDefaults(int totalSeconds) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final key = totalSeconds <= 180 ? 'custom_warmup_3min' : 'custom_warmup_5min';
        await box.delete(key);
      }
    } catch (_) {}
  }

  static Workout toWorkout(int totalSeconds) {
    final exercises = getExercisesForDuration(totalSeconds);
    final is3Min = totalSeconds <= 180;
    return Workout()
      ..name = is3Min ? 'Разминка 3 минуты (спина и суставы)' : 'Разминка 5 минут (полная защита спины)'
      ..type = WorkoutType.tabata
      ..tabataWorkSeconds = 30
      ..tabataRestSeconds = 0
      ..tabataRounds = exercises.length
      ..tags = ['Разминка', 'Без инвентаря', 'Спина', 'Суставы']
      ..exercises = exercises.map((e) => Exercise()
        ..name = e.title
        ..description = '${e.description}\n🛡️ Защита: ${e.backProtectionTip}'
        ..durationSeconds = e.durationSeconds
      ).toList();
  }
}
