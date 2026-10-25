import '../../services/recovery_analyzer.dart';
import 'workout.dart';

/// Equipment required for an exercise
enum ExerciseEquipment {
  bodyweight('Свой вес'),
  kettlebell('Гиря'),
  kettlebell16('Гиря 16 кг'),
  kettlebell6('Гиря 6 кг'),
  dumbbell('Гантели'),
  pullupBar('Турник'),
  resistanceBand('Резинки'),
  mat('Коврик');

  final String displayName;
  const ExerciseEquipment(this.displayName);

  bool get isKettlebell =>
      this == ExerciseEquipment.kettlebell ||
      this == ExerciseEquipment.kettlebell16 ||
      this == ExerciseEquipment.kettlebell6;

  int? get kettlebellWeightKg {
    if (this == ExerciseEquipment.kettlebell16) return 16;
    if (this == ExerciseEquipment.kettlebell6) return 6;
    return null;
  }
}

/// Difficulty level of an exercise
enum ExerciseDifficulty {
  beginner('Начальный'),
  intermediate('Средний'),
  advanced('Продвинутый');

  final String displayName;
  const ExerciseDifficulty(this.displayName);
}

/// Canonical definition of an exercise in the library
class ExerciseDefinition {
  final String id;
  final String name;
  final String description;
  final MuscleGroup targetMuscle;
  final MuscleSubgroup? subgroup;
  final bool isStatic;
  final int defaultDurationSeconds;
  final int defaultReps;
  final ExerciseEquipment equipment;
  final ExerciseDifficulty difficulty;
  final List<String> tags;
  final String? videoUrl;
  final String? notes;
  final DateTime? updatedAt;

  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.targetMuscle,
    this.subgroup,
    this.isStatic = false,
    this.defaultDurationSeconds = 30,
    this.defaultReps = 12,
    this.equipment = ExerciseEquipment.bodyweight,
    this.difficulty = ExerciseDifficulty.intermediate,
    this.tags = const [],
    this.videoUrl,
    this.notes,
    this.updatedAt,
  });

  /// Converts this definition into an instance of [Exercise] ready for a [Workout]
  Exercise toExercise({int? customReps, int? customDurationSeconds}) {
    final e = Exercise();
    e.name = name;
    e.description = description;
    e.videoUrl = videoUrl;
    e.notes = notes;
    if (isStatic) {
      e.durationSeconds = customDurationSeconds ?? defaultDurationSeconds;
      e.reps = null;
    } else {
      e.reps = customReps ?? defaultReps;
      e.durationSeconds = customDurationSeconds;
    }
    return e;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetMuscle': targetMuscle.name,
      if (subgroup != null) 'subgroup': subgroup!.name,
      'isStatic': isStatic,
      'defaultDurationSeconds': defaultDurationSeconds,
      'defaultReps': defaultReps,
      'equipment': equipment.name,
      'difficulty': difficulty.name,
      'tags': tags,
      if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory ExerciseDefinition.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = <String, dynamic>{
      for (final entry in rawJson.entries) entry.key.toString(): entry.value,
    };

    // Parse targetMuscle with aliases (Russian and English)
    MuscleGroup muscle = MuscleGroup.metabolicFullBody;
    final rawMuscle = json['targetMuscle']?.toString().trim().toLowerCase();
    if (rawMuscle != null && rawMuscle.isNotEmpty) {
      if (rawMuscle == 'upperbody' || rawMuscle == 'upper_body' || rawMuscle.contains('верх')) {
        muscle = MuscleGroup.upperBody;
      } else if (rawMuscle == 'lowerbody' || rawMuscle == 'lower_body' || rawMuscle.contains('низ')) {
        muscle = MuscleGroup.lowerBody;
      } else if (rawMuscle == 'corestatic' || rawMuscle == 'core_static' || rawMuscle.contains('кор') || rawMuscle.contains('статик')) {
        muscle = MuscleGroup.coreStatic;
      } else if (rawMuscle == 'metabolicfullbody' || rawMuscle == 'fullbody' || rawMuscle.contains('вит') || rawMuscle.contains('full') || rawMuscle.contains('кардио')) {
        muscle = MuscleGroup.metabolicFullBody;
      } else {
        for (final m in MuscleGroup.values) {
          if (m.name.toLowerCase() == rawMuscle || m.displayName.toLowerCase() == rawMuscle) {
            muscle = m;
            break;
          }
        }
      }
    }

    // Parse subgroup with aliases (Russian and English)
    MuscleSubgroup? subgroup;
    final rawSub = json['subgroup']?.toString().trim().toLowerCase();
    if (rawSub != null && rawSub.isNotEmpty) {
      for (final s in MuscleSubgroup.values) {
        if (s.name.toLowerCase() == rawSub || s.displayName.toLowerCase() == rawSub) {
          subgroup = s;
          break;
        }
      }
      if (subgroup == null) {
        if (rawSub.contains('груд')) {
          subgroup = MuscleSubgroup.chest;
        } else if (rawSub.contains('спин')) {
          subgroup = MuscleSubgroup.back;
        } else if (rawSub.contains('плеч')) {
          subgroup = MuscleSubgroup.shoulders;
        } else if (rawSub.contains('рук') || rawSub.contains('бицеп') || rawSub.contains('трицеп')) {
          subgroup = MuscleSubgroup.arms;
        } else if (rawSub.contains('трапец')) {
          subgroup = MuscleSubgroup.traps;
        } else if (rawSub.contains('квадрицеп')) {
          subgroup = MuscleSubgroup.quads;
        } else if (rawSub.contains('бедр') || rawSub.contains('хамстринг')) {
          subgroup = MuscleSubgroup.hamstrings;
        } else if (rawSub.contains('икр')) {
          subgroup = MuscleSubgroup.calves;
        } else if (rawSub.contains('ягодиц') || rawSub.contains('поп')) {
          subgroup = MuscleSubgroup.glutes;
        } else if (rawSub.contains('пресс') || rawSub.contains('живот')) {
          subgroup = MuscleSubgroup.abs;
        } else if (rawSub.contains('косы')) {
          subgroup = MuscleSubgroup.obliques;
        } else if (rawSub.contains('поясниц')) {
          subgroup = MuscleSubgroup.lowerBack;
        } else if (rawSub.contains('всё тело') || rawSub.contains('все тело')) {
          subgroup = MuscleSubgroup.fullBody;
        }
      }
    }

    // If subgroup is known and muscle wasn't explicitly set, infer from subgroup
    if (subgroup != null && (rawMuscle == null || rawMuscle.isEmpty)) {
      muscle = subgroup.parentGroup;
    }

    // Parse equipment
    ExerciseEquipment eq = ExerciseEquipment.bodyweight;
    final rawEq = json['equipment']?.toString().trim().toLowerCase();
    final exactEq = rawEq == null || rawEq.isEmpty
        ? null
        : ExerciseEquipment.values
            .where((e) => e.name.toLowerCase() == rawEq || e.displayName.toLowerCase() == rawEq)
            .firstOrNull;
    if (exactEq != null) {
      eq = exactEq;
    } else if (rawEq != null && rawEq.isNotEmpty) {
      if (rawEq.contains('свой вес') || rawEq.contains('bodyweight') || rawEq.contains('без инвентар')) {
        eq = ExerciseEquipment.bodyweight;
      } else if (rawEq.contains('гантел') || rawEq.contains('dumbbell')) {
        eq = ExerciseEquipment.dumbbell;
      } else if (rawEq.contains('гир') || rawEq.contains('kettlebell')) {
        eq = ExerciseEquipment.kettlebell;
      } else if (rawEq.contains('резин') || rawEq.contains('эспандер') || rawEq.contains('band')) {
        eq = ExerciseEquipment.resistanceBand;
      } else if (rawEq.contains('турник') || rawEq.contains('перекладин') || rawEq.contains('pullup') || rawEq.contains('pull_up')) {
        eq = ExerciseEquipment.pullupBar;
      } else if (rawEq.contains('коврик') || rawEq.contains('mat')) {
        eq = ExerciseEquipment.mat;
      } else {
        for (final e in ExerciseEquipment.values) {
          if (e.name.toLowerCase() == rawEq || e.displayName.toLowerCase() == rawEq) {
            eq = e;
            break;
          }
        }
      }
    }

    // Parse difficulty
    ExerciseDifficulty diff = ExerciseDifficulty.intermediate;
    final rawDiff = json['difficulty']?.toString().trim().toLowerCase();
    if (rawDiff != null && rawDiff.isNotEmpty) {
      if (rawDiff.contains('легк') || rawDiff.contains('начат') || rawDiff.contains('начальн') || rawDiff.contains('beginner') || rawDiff.contains('нович')) {
        diff = ExerciseDifficulty.beginner;
      } else if (rawDiff.contains('сложн') || rawDiff.contains('продвинут') || rawDiff.contains('advanced') || rawDiff.contains('профи')) {
        diff = ExerciseDifficulty.advanced;
      } else {
        diff = ExerciseDifficulty.intermediate;
      }
    }

    // Parse isStatic
    bool isStatic = false;
    final rawStatic = json['isStatic'];
    if (rawStatic is bool) {
      isStatic = rawStatic;
    } else if (rawStatic != null) {
      final s = rawStatic.toString().trim().toLowerCase();
      isStatic = (s == 'true' || s == '1' || s == 'да' || s == 'статика');
    }

    // Parse numbers safely
    final rawDuration = json['defaultDurationSeconds'] ?? json['duration'] ?? json['defaultDuration'];
    int duration = 30;
    if (rawDuration is num) {
      duration = rawDuration.toInt();
    } else if (rawDuration != null) {
      final digits = rawDuration.toString().replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(digits);
      if (parsed != null && parsed > 0) duration = parsed;
    }

    final rawReps = json['defaultReps'] ?? json['reps'] ?? json['default_reps'];
    int reps = 12;
    if (rawReps is num) {
      reps = rawReps.toInt();
    } else if (rawReps != null) {
      final digits = rawReps.toString().replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(digits);
      if (parsed != null && parsed > 0) reps = parsed;
    }

    // Parse tags safely
    final tags = <String>[];
    final rawTags = json['tags'];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null) {
          final s = t.toString().trim();
          if (s.contains(',')) {
            for (final part in s.split(',')) {
              final cp = _formatTag(part);
              if (cp.isNotEmpty && !tags.contains(cp)) tags.add(cp);
            }
          } else {
            final cp = _formatTag(s);
            if (cp.isNotEmpty && !tags.contains(cp)) tags.add(cp);
          }
        }
      }
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      final parts = rawTags.contains(',')
          ? rawTags.split(',')
          : (rawTags.contains(';') ? rawTags.split(';') : rawTags.split(' '));
      for (final part in parts) {
        final cp = _formatTag(part);
        if (cp.isNotEmpty && !tags.contains(cp)) tags.add(cp);
      }
    }

    if (isStatic && !tags.contains('Статика')) {
      tags.add('Статика');
    }

    final name = (json['name']?.toString() ?? 'Без названия').trim();
    final rawId = json['id']?.toString().trim();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'ex_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]'), '_')}_${DateTime.now().microsecondsSinceEpoch}';

    DateTime? updatedAt;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated is String) {
      updatedAt = DateTime.tryParse(rawUpdated);
    } else if (rawUpdated is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdated);
    }

    return ExerciseDefinition(
      id: id,
      name: name.isNotEmpty ? name : 'Без названия',
      description: (json['description']?.toString() ?? '').trim(),
      targetMuscle: muscle,
      subgroup: subgroup,
      isStatic: isStatic,
      defaultDurationSeconds: duration,
      defaultReps: reps,
      equipment: eq,
      difficulty: diff,
      tags: tags,
      videoUrl: json['videoUrl']?.toString().trim(),
      notes: json['notes']?.toString().trim(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static String _formatTag(String text) {
    var t = text.trim();
    while (t.startsWith('#')) {
      t = t.substring(1).trim();
    }
    if (t.isEmpty) return t;
    if (t == 'Кор и статика' || t == 'Кор и Статика' || t == 'Только статика') {
      return 'Статика';
    }
    return t[0].toUpperCase() + t.substring(1);
  }
}

/// In-app repository and catalog of canonical exercises
class ExerciseLibrary {
  static const List<ExerciseDefinition> catalog = [
    // --- КОР И СТАТИКА ---
    ExerciseDefinition(
      id: 'plank_classic',
      name: 'Планка на локтях',
      description: 'Изометрическое удержание ровной линии тела',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: true,
      defaultDurationSeconds: 40,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Статика', 'Кор', 'Пресс'],
    ),
    ExerciseDefinition(
      id: 'side_plank',
      name: 'Боковая планка',
      description: 'Изометрия косых мышц пресса и стабилизаторов',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: true,
      defaultDurationSeconds: 30,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Статика', 'Кор', 'Косые'],
    ),
    ExerciseDefinition(
      id: 'wall_sit',
      name: 'Стульчик у стены',
      description: 'Статическое удержание бедер параллельно полу',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: true,
      defaultDurationSeconds: 45,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Статика', 'Ноги', 'Изометрия'],
    ),
    ExerciseDefinition(
      id: 'hollow_body',
      name: 'Лодочка (Холлоу боди)',
      description: 'Статическое натяжение кора с прижатой поясницей',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: true,
      defaultDurationSeconds: 30,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Статика', 'Кор', 'Пресс'],
    ),
    ExerciseDefinition(
      id: 'superman',
      name: 'Лодочка на животе (Супермен)',
      description: 'Удержание прогиба для укрепления разгибателей спины',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: true,
      defaultDurationSeconds: 35,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Статика', 'Спина', 'Поясница'],
    ),
    ExerciseDefinition(
      id: 'crunches',
      name: 'Скручивания на пресс',
      description: 'Контролируемый подъем корпуса с акцентом на прямой мышце',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 20,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Кор', 'Пресс'],
    ),
    ExerciseDefinition(
      id: 'russian_twists',
      name: 'Русские скручивания',
      description: 'Динамические повороты корпуса с поднятыми стопами',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 24,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Кор', 'Косые'],
    ),
    ExerciseDefinition(
      id: 'mountain_climbers',
      name: 'Скалолаз (Mountain Climbers)',
      description: 'Попеременное подтягивание коленей к груди в планке',
      targetMuscle: MuscleGroup.coreStatic,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 30,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Кор', 'Кардио', 'ВИТ'],
    ),

    // --- ВЕРХ ТЕЛА ---
    ExerciseDefinition(
      id: 'pushups_classic',
      name: 'Классические отжимания',
      description: 'Базовое движение для груди, трицепса и передних дельт',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 15,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Верх тела', 'Грудь', 'Трицепс'],
    ),
    ExerciseDefinition(
      id: 'pushups_wide',
      name: 'Широкие отжимания',
      description: 'Акцент на грудные мышцы и плечевой пояс',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 12,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Верх тела', 'Грудь'],
    ),
    ExerciseDefinition(
      id: 'pushups_diamond',
      name: 'Алмазные отжимания',
      description: 'Постановка ладоней треугольником с акцентом на трицепс',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 10,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Верх тела', 'Трицепс'],
    ),
    ExerciseDefinition(
      id: 'pike_pushups',
      name: 'Отжимания «домиком» (Пайк)',
      description: 'Вертикальный жим собственным весом с акцентом на плечи',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 10,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Верх тела', 'Плечи'],
    ),
    ExerciseDefinition(
      id: 'dips_bench',
      name: 'Обратные отжимания от скамьи/стула',
      description: 'Изолирующая проработка трехглавой мышцы плеча',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 15,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Верх тела', 'Трицепс'],
    ),

    // --- НИЗ ТЕЛА ---
    ExerciseDefinition(
      id: 'air_squats',
      name: 'Воздушные приседания',
      description: 'Классические глубокие приседания с ровной спиной',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 20,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Низ тела', 'Квадрицепс', 'Ягодицы'],
    ),
    ExerciseDefinition(
      id: 'lunges',
      name: 'Выпады на месте',
      description: 'Попеременные шаги вперед с прямым углом в коленях',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 16,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Низ тела', 'Квадрицепс', 'Ягодицы'],
    ),
    ExerciseDefinition(
      id: 'jump_squats',
      name: 'Приседания с выпрыгиванием',
      description: 'Взрывные плиометрические приседания',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 15,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Низ тела', 'Плиометрика', 'ВИТ'],
    ),
    ExerciseDefinition(
      id: 'glute_bridge',
      name: 'Ягодичный мостик',
      description: 'Подъем таза лежа на спине с фиксацией в верхней точке',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 20,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Низ тела', 'Ягодицы', 'Бицепс бедра'],
    ),
    ExerciseDefinition(
      id: 'calf_raises',
      name: 'Подъемы на носки',
      description: 'Изолированная нагрузка на икроножные мышцы',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 25,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Низ тела', 'Икры'],
    ),

    // --- ВИТ / FULL BODY ---
    ExerciseDefinition(
      id: 'burpees',
      name: 'Бёрпи классические',
      description: 'Упор лежа, отжимание, поднос ног и выпрыгивание с хлопком',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 10,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['ВИТ на всё тело', 'Full Body', 'Кардио'],
    ),
    ExerciseDefinition(
      id: 'jumping_jacks',
      name: 'Прыжки «Джампинг Джек»',
      description: 'Прыжки с разведением рук и ног для активного пульса',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 35,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['ВИТ на всё тело', 'Кардио', 'Разминка'],
    ),
    ExerciseDefinition(
      id: 'high_knees',
      name: 'Бег с высоким подниманием колен',
      description: 'Интенсивный спринт на месте с акцентом на темп',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 40,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['ВИТ на всё тело', 'Кардио'],
    ),
    ExerciseDefinition(
      id: 'skater_hops',
      name: 'Прыжки конькобежца',
      description: 'Латеральные взрывные прыжки из стороны в сторону',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 20,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['ВИТ на всё тело', 'Баланс', 'Плиометрика'],
    ),

    // --- ГИРЯ (Kettlebell) ---
    ExerciseDefinition(
      id: 'kb_swings',
      name: 'Махи гирей (Kettlebell Swings)',
      description: 'Взрывной тазовый толчок с выносом гири до уровня груди',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 15,
      equipment: ExerciseEquipment.kettlebell,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Гиря', 'Full Body', 'Спина', 'Ягодицы'],
    ),
    ExerciseDefinition(
      id: 'kb_swings_16',
      name: 'Махи гирей 16 кг',
      description: 'Взрывной тазовый толчок с тяжелой гирей 16 кг для силы и мощности',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 15,
      equipment: ExerciseEquipment.kettlebell16,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Гиря', '16 кг', 'Full Body', 'Спина', 'Ягодицы'],
    ),
    ExerciseDefinition(
      id: 'kb_swings_6',
      name: 'Махи гирей 6 кг',
      description: 'Высокоинтенсивные аэробные махи с легкой гирей 6 кг на выносливость',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 20,
      equipment: ExerciseEquipment.kettlebell6,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Гиря', '6 кг', 'ВИТ', 'Full Body'],
    ),
    ExerciseDefinition(
      id: 'kb_goblet_squats',
      name: 'Кубковые приседания с гирей',
      description: 'Приседания с удержанием гири у груди двумя руками',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 12,
      equipment: ExerciseEquipment.kettlebell,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Гиря', 'Низ тела', 'Квадрицепс'],
    ),
    ExerciseDefinition(
      id: 'kb_goblet_squats_16',
      name: 'Кубковые приседания 16 кг',
      description: 'Глубокие силовые приседания с удержанием тяжелой гири 16 кг у груди',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 12,
      equipment: ExerciseEquipment.kettlebell16,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Гиря', '16 кг', 'Низ тела', 'Квадрицепс'],
    ),
    ExerciseDefinition(
      id: 'kb_clean_and_press',
      name: 'Взятие и жим гири',
      description: 'Комплексный подъем снаряда на плечо и фиксация над головой',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 8,
      equipment: ExerciseEquipment.kettlebell,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Гиря', 'Верх тела', 'Плечи'],
    ),
    ExerciseDefinition(
      id: 'kb_clean_and_press_16',
      name: 'Взятие и жим гири 16 кг',
      description: 'Тяжелый силовой подъем и жим гири 16 кг над головой',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 8,
      equipment: ExerciseEquipment.kettlebell16,
      difficulty: ExerciseDifficulty.advanced,
      tags: ['Гиря', '16 кг', 'Верх тела', 'Плечи'],
    ),
    ExerciseDefinition(
      id: 'kb_clean_and_press_6',
      name: 'Взятие и жим гири 6 кг',
      description: 'Скоростной многоповторный жим гири 6 кг в темпе',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 12,
      equipment: ExerciseEquipment.kettlebell6,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Гиря', '6 кг', 'Верх тела', 'Плечи'],
    ),
    ExerciseDefinition(
      id: 'kb_halo_6',
      name: 'Вращение гири вокруг головы (Нимб) 6 кг',
      description: 'Круговые движения легкой гирей 6 кг для здоровья плеч и кора',
      targetMuscle: MuscleGroup.upperBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 10,
      equipment: ExerciseEquipment.kettlebell6,
      difficulty: ExerciseDifficulty.beginner,
      tags: ['Гиря', '6 кг', 'Плечи', 'Кор'],
    ),
    ExerciseDefinition(
      id: 'kb_snatch_6',
      name: 'Рывок гири 6 кг',
      description: 'Быстрый непрерывный взрывной подъем легкой гири 6 кг',
      targetMuscle: MuscleGroup.metabolicFullBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 14,
      equipment: ExerciseEquipment.kettlebell6,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Гиря', '6 кг', 'ВИТ', 'Full Body'],
    ),
    ExerciseDefinition(
      id: 'kb_deadlift_16',
      name: 'Становая тяга с гирей 16 кг',
      description: 'Классическая тяга тяжелой гири 16 кг с акцентом на заднюю цепочку',
      targetMuscle: MuscleGroup.lowerBody,
      isStatic: false,
      defaultDurationSeconds: 30,
      defaultReps: 12,
      equipment: ExerciseEquipment.kettlebell16,
      difficulty: ExerciseDifficulty.intermediate,
      tags: ['Гиря', '16 кг', 'Низ тела', 'Спина'],
    ),
  ];

  /// Finds exercises matching target muscle, equipment and static preference
  static List<ExerciseDefinition> filter({
    MuscleGroup? muscleGroup,
    ExerciseEquipment? equipment,
    bool? isStatic,
  }) {
    return catalog.where((item) {
      if (muscleGroup != null && item.targetMuscle != muscleGroup) {
        return false;
      }
      if (equipment != null) {
        if (equipment == ExerciseEquipment.kettlebell) {
          if (!item.equipment.isKettlebell) return false;
        } else if (item.equipment != equipment && item.equipment != ExerciseEquipment.kettlebell) {
          return false;
        }
      }
      if (isStatic != null && item.isStatic != isStatic) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Looks up exercise by id or case-insensitive name
  static ExerciseDefinition? findByNameOrId(String query) {
    final q = query.trim().toLowerCase();
    for (final item in catalog) {
      if (item.id.toLowerCase() == q || item.name.toLowerCase() == q) {
        return item;
      }
    }
    for (final item in catalog) {
      if (item.name.toLowerCase().contains(q)) {
        return item;
      }
    }
    return null;
  }
}
