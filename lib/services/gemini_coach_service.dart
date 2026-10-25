import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../data/models/athlete_profile.dart';
import '../data/models/exercise_library.dart';
import '../data/models/workout.dart';
import '../data/models/workout_session.dart';
import 'recovery_analyzer.dart';

enum CoachPersona {
  fitnessCoach,
  productAdvisor,
}

class GeminiCoachService {
  final String? _apiKey;

  GeminiCoachService(this._apiKey);

  bool get hasApiKey => _apiKey != null && _apiKey.trim().isNotEmpty;

  static const List<String> _preferredModels = [
    'gemini-3.5-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-3-flash-preview',
    'gemini-2.5-flash',
    'gemini-1.5-flash',
  ];

  /// Tests if the provided API key works with Gemini
  static Future<bool> validateKey(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return false;

    for (final modelName in _preferredModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: cleanKey,
        );
        final response = await model.generateContent([
          Content.text('Ответь одним словом: ОК'),
        ]);
        if (response.text != null && response.text!.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // try next model
      }
    }
    return false;
  }

  /// Generates post-workout feedback with calorie and recovery tips
  Future<String> getWorkoutCompletionFeedback({
    required String workoutName,
    required WorkoutType type,
    required int durationSeconds,
    required int caloriesBurned,
    required int completedRounds,
    required List<String> tags,
    required AthleteProfile profile,
    String? userNote,
  }) async {
    if (!hasApiKey) {
      return _generateLocalFeedback(
        workoutName: workoutName,
        type: type,
        caloriesBurned: caloriesBurned,
        tags: tags,
        userNote: userNote,
      );
    }

    final cleanKey = _apiKey!.trim();
    final noteContext = (userNote != null && userNote.trim().isNotEmpty)
        ? '\n- Отзыв / самочувствие атлета: "$userNote"'
        : '';

    for (final modelName in _preferredModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: cleanKey,
        );

        final prompt = '''
Ты спортивный наставник и тренер. Атлет только что завершил тренировочный комплекс:
- Название: "$workoutName"
- Формат: ${type.name.toUpperCase()}
- Целевые зоны: ${tags.isEmpty ? "Базовые движения" : tags.join(', ')}
- Время работы: ${(durationSeconds / 60).toStringAsFixed(1)} мин
- Раундов: $completedRounds
- Сожжено: ~$caloriesBurned ккал
- Параметры атлета: ${profile.gender == 'male' ? 'Мужчина' : 'Женщина'}, ${profile.weightKg.round()} кг, ${profile.age} лет, уровень: ${profile.fitnessLevel.name}.$noteContext

Сформулируй свежий, живой и уникальный комментарий (ровно 2-3 предложения):
1. Отметь качество нагрузки или реакцию на отзыв атлета (если он есть).
2. Дай один полезный практический совет по коррекции следующих упражнений, растяжке конкретных мышечных групп или оптимальному отдыху.
Пиши простым понятным языком, без заумных терминов вроде "окно регидратации". Каждый раз давай разный, интересный совет.
''';

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (_) {
        // try next model
      }
    }

    return _generateLocalFeedback(
      workoutName: workoutName,
      type: type,
      caloriesBurned: caloriesBurned,
      tags: tags,
      userNote: userNote,
    );
  }

  /// Generates AI recommendation for the next workout based on recovery matrix
  Future<String> getNextWorkoutRecommendation({
    required RecoveryReport report,
    required List<Workout> availableWorkouts,
    required List<WorkoutSession> recentSessions,
    required AthleteProfile profile,
  }) async {
    if (!hasApiKey) {
      return report.recommendationReason;
    }

    final cleanKey = _apiKey!.trim();
    final statusesText = report.statuses.map((s) {
      return '${s.group.displayName}: ${(s.recoveryPercent * 100).round()}% готовности (${s.statusText})';
    }).join('\n');

    final prompt = '''
Ты спортивный врач и тренер. Проанализируй баланс восстановления атлета:
$statusesText

Рекомендованная мышечная группа: ${report.recommendedGroup.displayName}.
Предлагаемый комплекс: ${report.recommendedWorkout?.name ?? 'Отдых или легкая статика'}.
Параметры атлета: ${profile.weightKg.round()} кг, ${profile.age} лет, уровень: ${profile.fitnessLevel.name}.

Сформулируй краткую персональную рекомендацию на сегодня (2-3 предложения на русском языке). 
Объясни, почему именно эта группа мышц сейчас оптимальна и как это защитит от перетренированности.
''';

    for (final modelName in _preferredModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: cleanKey,
        );

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (_) {
        // try next model
      }
    }

    return report.recommendationReason;
  }

  /// Generates a customized Workout based on recovery status, target format, duration and preferences
  Future<Workout> generateWorkout({
    required WorkoutType targetType,
    required int targetDurationMinutes,
    required MuscleGroup? targetMuscleGroup,
    required ExerciseEquipment equipment,
    required RecoveryReport recoveryReport,
    required AthleteProfile profile,
    String? userPrompt,
  }) async {
    final effectiveMuscle = targetMuscleGroup ?? recoveryReport.recommendedGroup;

    if (hasApiKey) {
      final cleanKey = _apiKey!.trim();
      final availableCatalogStr = ExerciseLibrary.catalog.map((e) {
        return '- ID: "${e.id}", Название: "${e.name}", Группа: "${e.targetMuscle.name}", Статика: ${e.isStatic}, Инвентарь: "${e.equipment.name}"';
      }).join('\n');

      final prompt = '''
Ты профессиональный фитнес-методист. Сформируй тренировочный комплекс для атлета в формате JSON.
Параметры атлета: ${profile.weightKg.round()} кг, ${profile.age} лет, уровень: ${profile.fitnessLevel.name}.
Требования:
- Тип тренировки: ${targetType.name.toUpperCase()} (допустимые значения: "tabata", "emom", "amrap")
- Целевая длительность: $targetDurationMinutes минут
- Фокус мышечной группы: ${effectiveMuscle.displayName} (${effectiveMuscle.name})
- Доступный инвентарь: ${equipment.displayName}
У атлета в арсенале ДВЕ ГИРИ: 16 кг (тяжелая: для махов, становой тяги, кубковых приседаний, взрывной силы ног и спины) и 6 кг (легкая: для жимов, рывков, вращения вокруг головы/нимб, плеч, кора и многоповторной выносливости).
Если в тренировке задействованы гири, обязательно указывай конкретный вес гири (16 кг или 6 кг) в названии или описании каждого упражнения, распределяя нагрузку анатомически правильно!
${userPrompt != null && userPrompt.trim().isNotEmpty ? '- Дополнительные пожелания атлета: "$userPrompt"' : ''}

Каталог упражнений приложения (выбирай строго из этого списка или используй их названия):
$availableCatalogStr

Правила генерации:
1. Если упражнение статическое (планка, стульчик, лодочка), reps должно быть null, а durationSeconds установлено (например 30 или 40 сек).
2. Для упражнений с гирей явно пиши в названии или описании вес снаряда: 16 кг или 6 кг.
2. Для Табаты (tabata): количество раундов обычно 8 (или кратно 8 при нескольких кругах), workSeconds: 20, restSeconds: 10.
3. Для EMOM: emomRoundDurationSeconds: 60, emomRounds: $targetDurationMinutes (или общее число минут).
4. Для AMRAP: amrapDurationSeconds: ${targetDurationMinutes * 60}.
5. Ответ должен быть СТРОГО в формате JSON без markdown-кавычек ```json или сопроводительного текста:
{
  "name": "Название тренировки",
  "type": "${targetType.name}",
  "tags": ["${effectiveMuscle.displayName}", "${equipment.displayName}"],
  "tabataWorkSeconds": 20,
  "tabataRestSeconds": 10,
  "tabataRounds": 8,
  "emomRounds": $targetDurationMinutes,
  "emomRoundDurationSeconds": 60,
  "amrapDurationSeconds": ${targetDurationMinutes * 60},
  "exercises": [
    {
      "name": "Название упражнения",
      "description": "Краткая техника или фокус",
      "reps": 12,
      "durationSeconds": null
    }
  ]
}
''';

      for (final modelName in _preferredModels) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: cleanKey,
          );
          final response = await model.generateContent([Content.text(prompt)]);
          final rawText = response.text?.trim();
          if (rawText != null && rawText.isNotEmpty) {
            // Strip markdown wrapping if model included it
            String jsonStr = rawText;
            if (jsonStr.startsWith('```json')) {
              jsonStr = jsonStr.substring(7);
            } else if (jsonStr.startsWith('```')) {
              jsonStr = jsonStr.substring(3);
            }
            if (jsonStr.endsWith('```')) {
              jsonStr = jsonStr.substring(0, jsonStr.length - 3);
            }
            jsonStr = jsonStr.trim();

            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final parsedWorkout = _buildWorkoutFromMap(map, targetType, targetDurationMinutes, effectiveMuscle, equipment);
            if (parsedWorkout.exercises.isNotEmpty) {
              return parsedWorkout;
            }
          }
        } catch (_) {
          // fallback to next model or local
        }
      }
    }

    // Deterministic offline fallback generator
    return _generateLocalWorkout(
      targetType: targetType,
      targetDurationMinutes: targetDurationMinutes,
      effectiveMuscle: effectiveMuscle,
      equipment: equipment,
    );
  }

  Workout _buildWorkoutFromMap(
    Map<String, dynamic> map,
    WorkoutType fallbackType,
    int durationMinutes,
    MuscleGroup muscleGroup,
    ExerciseEquipment equipment,
  ) {
    final w = Workout();
    w.name = (map['name'] as String?)?.trim() ?? 'AI: ${muscleGroup.displayName}';
    final typeStr = (map['type'] as String?)?.toLowerCase();
    if (typeStr == 'tabata') {
      w.type = WorkoutType.tabata;
    } else if (typeStr == 'emom') {
      w.type = WorkoutType.emom;
    } else if (typeStr == 'amrap') {
      w.type = WorkoutType.amrap;
    } else {
      w.type = fallbackType;
    }

    w.tabataWorkSeconds = (map['tabataWorkSeconds'] as num?)?.toInt() ?? 20;
    w.tabataRestSeconds = (map['tabataRestSeconds'] as num?)?.toInt() ?? 10;
    w.tabataRounds = (map['tabataRounds'] as num?)?.toInt() ?? 8;
    w.emomRounds = (map['emomRounds'] as num?)?.toInt() ?? durationMinutes;
    w.emomRoundDurationSeconds = (map['emomRoundDurationSeconds'] as num?)?.toInt() ?? 60;
    w.amrapDurationSeconds = (map['amrapDurationSeconds'] as num?)?.toInt() ?? (durationMinutes * 60);

    final rawTags = map['tags'] as List<dynamic>?;
    if (rawTags != null && rawTags.isNotEmpty) {
      w.tags = rawTags.map((t) => t.toString()).toList();
    } else {
      w.tags = [muscleGroup.displayName, equipment.displayName];
    }

    final rawExercises = map['exercises'] as List<dynamic>?;
    if (rawExercises != null) {
      for (final item in rawExercises) {
        if (item is Map<String, dynamic>) {
          final e = Exercise();
          e.name = (item['name'] as String?)?.trim() ?? 'Упражнение';
          e.description = (item['description'] as String?)?.trim();
          e.reps = (item['reps'] as num?)?.toInt();
          e.durationSeconds = (item['durationSeconds'] as num?)?.toInt();
          w.exercises.add(e);
        }
      }
    }

    return w;
  }

  Workout _generateLocalWorkout({
    required WorkoutType targetType,
    required int targetDurationMinutes,
    required MuscleGroup effectiveMuscle,
    required ExerciseEquipment equipment,
  }) {
    final w = Workout();
    final typeName = targetType == WorkoutType.tabata
        ? 'Табата'
        : (targetType == WorkoutType.emom ? 'EMOM' : 'AMRAP');
    w.name = '$typeName: ${effectiveMuscle.displayName}';
    w.type = targetType;
    w.tags = [effectiveMuscle.displayName, equipment.displayName];
    if (effectiveMuscle == MuscleGroup.coreStatic) {
      w.tags.add('Статика');
    }
    if (equipment == ExerciseEquipment.kettlebell16) {
      w.tags.add('16 кг');
    } else if (equipment == ExerciseEquipment.kettlebell6) {
      w.tags.add('6 кг');
    }

    // Match exercises from catalog
    var matched = ExerciseLibrary.filter(
      muscleGroup: effectiveMuscle,
      equipment: equipment,
    );
    if (matched.isEmpty) {
      matched = ExerciseLibrary.filter(muscleGroup: effectiveMuscle);
    }
    if (matched.isEmpty) {
      matched = ExerciseLibrary.catalog;
    }

    final countNeeded = targetType == WorkoutType.tabata ? 4 : 5;
    final selectedDefinitions = matched.take(countNeeded).toList();

    w.exercises = selectedDefinitions.map((d) {
      return d.toExercise();
    }).toList();

    if (targetType == WorkoutType.tabata) {
      w.tabataWorkSeconds = 20;
      w.tabataRestSeconds = 10;
      final roundsCount = (targetDurationMinutes * 60 / 30).round();
      w.tabataRounds = roundsCount > 0 ? roundsCount : 8;
    } else if (targetType == WorkoutType.emom) {
      w.emomRoundDurationSeconds = 60;
      w.emomRounds = targetDurationMinutes;
    } else {
      w.amrapDurationSeconds = targetDurationMinutes * 60;
    }

    return w;
  }

  String _generateLocalFeedback({
    required String workoutName,
    required WorkoutType type,
    required int caloriesBurned,
    required List<String> tags,
    String? userNote,
  }) {
    final hasNote = userNote != null && userNote.trim().isNotEmpty;
    final noteReaction = hasNote
        ? 'Учли вашу заметку ("${userNote.trim()}"). '
        : '';

    final pool = <String>[];

    if (tags.contains('Статика')) {
      pool.add('$noteReactionОтличная изометрическая работа! Сожжено ~$caloriesBurned ккал. '
          'Глубокие мышцы-стабилизаторы получили мощный стимул. Сделайте легкую растяжку спины и попейте чистой воды.');
      pool.add('$noteReactionСтатика отлично развивает выносливость сухожилий и кор! Затрачено ~$caloriesBurned ккал. '
          'В следующий раз можно добавить 5-10 секунд к интервалам удержания.');
    } else if (type == WorkoutType.tabata) {
      pool.add('$noteReactionМощный интервальный взрыв! Вы сожгли ~$caloriesBurned ккал на высокой мощности. '
          'Восстановите дыхание, походите 2-3 минуты и сделайте заминку для нормализации пульса.');
      pool.add('$noteReactionТабата выполнена на максимальном темпе! Потрачено ~$caloriesBurned ккал. '
          'Если последние раунды дались тяжело, попробуйте чуть ровнее распределять силы со старта.');
    } else if (type == WorkoutType.amrap) {
      pool.add('$noteReactionПревосходная плотность работы! Сожжено ~$caloriesBurned ккал. '
          'Обязательно сделайте растяжку рабочих мышц и выпейте воды с лимоном для восстановления водно-солевого баланса.');
      pool.add('$noteReactionВысокая производительность в AMRAP! Затрачено ~$caloriesBurned ккал. '
          'Зафиксируйте этот результат — на следующей тренировке ориентируйтесь на этот темп.');
    } else {
      pool.add('$noteReactionОтличный тренировочный объем! Сожжено ~$caloriesBurned ккал в ритме EMOM. '
          'Выпейте воды, сделайте мягкую растяжку плеч и ног, чтобы снять мышечный тонус.');
      pool.add('$noteReactionРовный и дисциплинированный темп раундов! Потрачено ~$caloriesBurned ккал. '
          'Если остался запас сил, на следующей тренировке можно увеличить темп первых 30 секунд в раунде.');
    }

    // Pick pseudorandomly based on minutes or text length
    final index = (DateTime.now().minute + caloriesBurned) % pool.length;
    return pool[index];
  }

  /// Interactive Chat: sends conversation history + athletic context to Gemini
  Future<String> sendChatMessage({
    required List<Map<String, String>> messages, // [{'role': 'user'|'model', 'text': '...'}]
    required AthleteProfile profile,
    required RecoveryReport recoveryReport,
    required List<WorkoutSession> recentSessions,
    CoachPersona persona = CoachPersona.fitnessCoach,
  }) async {
    final userQuestion = messages.isNotEmpty ? messages.last['text'] ?? '' : '';

    if (!hasApiKey) {
      return _generateLocalChatAnswer(userQuestion, recoveryReport, profile, persona);
    }

    final cleanKey = _apiKey!.trim();
    final statusesSummary = recoveryReport.statuses.map((s) {
      return '- ${s.group.displayName}: ${(s.recoveryPercent * 100).round()}% готовности (${s.statusText})';
    }).join('\n');

    final lastSession = recentSessions.isNotEmpty ? recentSessions.first : null;
    final lastDurationMin = lastSession != null
        ? (lastSession.finishedAt?.difference(lastSession.startedAt).inMinutes ?? 0)
        : 0;
    final estCalories = (lastDurationMin * 8.5).round();
    final lastSessionStr = lastSession != null
        ? 'Последняя тренировка: "${lastSession.workoutName}" (${lastSession.completedRounds} раундов, ~$estCalories ккал, ${lastSession.startedAt.day}.${lastSession.startedAt.month})'
        : 'Ранее записанных тренировок пока нет.';

    final String systemInstruction;
    if (persona == CoachPersona.productAdvisor) {
      systemInstruction = '''
Ты — ведущий мобильный продуктовый архитектор и UX/UI эксперт фитнес-платформы Workout Timer (Flutter, Android, Desktop, Web).
Ты помогаешь создателю приложения проектировать новые функции, улучшать пользовательский опыт (UX/UI), готовить приложение к успешному релизу в Google Play Store, повышать конверсию, эргономику и удержание атлетов.

Контекст экосистемы приложения:
- Стек: Flutter, Dart, Riverpod, Hive, Firestore Sync, Gemini AI 2.5/3.5 Flash.
- Целевые устройства: Android (OnePlus 15 / 120Hz LTPO / O-Haptics), Web, Linux/macOS Desktop.
- Таймеры: EMOM, Табата (HIIT), AMRAP, база статических упражнений.
- Планируется релиз в Google Play Store для широкой аудитории спортсменов.

Правила ответа:
1. Отвечай как опытный продуктовый лидер (CPO / Senior Flutter Lead): ёмко, структурировано, профессионально.
2. Предлагай конкретные решения: сценарии интерфейса, идеи фич, рекомендации по прохождению модерации в Google Play (политика конфиденциальности, permissions, ASO-ключи, иконка, промо-скриншоты).
3. Давай практические советы по эргономике таймера (видимость цифр в зале, контрастность, жесты, звуки, виджеты рабочего стола).
''';
    } else {
      systemInstruction = '''
Ты — персональный спортивный тренер, наставник и физиолог в приложении Workout Timer.
Твоя цель: помогать атлету добиваться прогресса, предотвращать травмы, давать точные советы по технике, питанию, восстановлению и подбору упражнений (особенно Табата, EMOM, AMRAP и статическая изометрия).

Контекст атлета:
- Пол: ${profile.gender == 'male' ? 'Мужчина' : 'Женщина'}, Возраст: ${profile.age} года/лет, Вес: ${profile.weightKg.round()} кг, Уровень: ${profile.fitnessLevel.name}.
- Текущая готовность мышц:
$statusesSummary
- $lastSessionStr

Правила ответа:
1. Отвечай доброжелательно, по-спортивному, мотивирующе, но профессионально и ёмко (обычно 2-4 предложения или четкий список).
2. Опирайся на текущее состояние мышц атлета.
3. Если атлет просит составить или изменить комплекс, дай конкретные рекомендации по раундам и секундам/повторам.
4. Обязательно прямо отвечай на конкретный вопрос пользователя!
''';
    }

    // Build alternating message history for multi-turn chat
    final historyContents = <Content>[];
    String? lastRole;
    final buffer = StringBuffer();

    for (final m in messages) {
      final role = (m['role'] == 'user') ? 'user' : 'model';
      final text = (m['text'] ?? '').trim();
      if (text.isEmpty) continue;

      // Skip leading model message so history starts with 'user'
      if (historyContents.isEmpty && role == 'model' && lastRole == null) {
        continue;
      }

      if (lastRole == role) {
        buffer.writeln('\n$text');
      } else {
        if (lastRole != null) {
          final contentText = buffer.toString().trim();
          if (contentText.isNotEmpty) {
            historyContents.add(lastRole == 'user'
                ? Content.text(contentText)
                : Content.model([TextPart(contentText)]));
          }
          buffer.clear();
        }
        lastRole = role;
        buffer.write(text);
      }
    }

    if (lastRole != null) {
      final contentText = buffer.toString().trim();
      if (contentText.isNotEmpty) {
        historyContents.add(lastRole == 'user'
            ? Content.text(contentText)
            : Content.model([TextPart(contentText)]));
      }
    }

    if (historyContents.isEmpty) {
      historyContents.add(Content.text(userQuestion.isNotEmpty ? userQuestion : 'Привет!'));
    } else if (historyContents.last.role != 'user') {
      historyContents.add(Content.text(userQuestion.isNotEmpty ? userQuestion : 'Продолжи'));
    }

    String? lastErrorMsg;

    for (final modelName in _preferredModels) {
      // 1. First try: with systemInstruction parameter
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: cleanKey,
          systemInstruction: Content.system(systemInstruction),
        );
        final response = await model.generateContent(historyContents);
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (e) {
        lastErrorMsg = e.toString();
        debugPrint('GeminiCoachService with systemInstruction failed for $modelName: $e');

        // 2. Second try: without systemInstruction parameter (prepend to first user prompt)
        try {
          final modelFallback = GenerativeModel(
            model: modelName,
            apiKey: cleanKey,
          );
          final fallbackContents = <Content>[];
          for (int i = 0; i < historyContents.length; i++) {
            if (i == 0) {
              final originalText = historyContents[0].parts.whereType<TextPart>().map((p) => p.text).join('\n');
              fallbackContents.add(Content.text('ИНСТРУКЦИЯ:\n$systemInstruction\n\nВОПРОС:\n$originalText'));
            } else {
              fallbackContents.add(historyContents[i]);
            }
          }
          final response = await modelFallback.generateContent(fallbackContents);
          final text = response.text?.trim();
          if (text != null && text.isNotEmpty) {
            return text;
          }
        } catch (e2) {
          lastErrorMsg = e2.toString();
          debugPrint('GeminiCoachService fallback failed for $modelName: $e2');
        }
      }
    }

    String errorNotice = '';
    if (lastErrorMsg != null) {
      if (lastErrorMsg.contains('location') || lastErrorMsg.contains('User location is not supported')) {
        errorNotice = 'ℹ️ *Google Gemini API временно недоступен из вашего региона без VPN. Отвечает встроенный фитнес-модуль:*\n\n';
      } else if (lastErrorMsg.contains('API_KEY_INVALID') || lastErrorMsg.contains('API key not valid')) {
        errorNotice = '⚠️ *Ключ Gemini API недействителен. Проверьте ключ в настройках профиля. Отвечает встроенный модуль:*\n\n';
      } else if (lastErrorMsg.contains('RESOURCE_EXHAUSTED') || lastErrorMsg.contains('quota')) {
        errorNotice = '⏳ *Превышена квота запросов Gemini API. Отвечает встроенный модуль:*\n\n';
      }
    }

    final localAnswer = _generateLocalChatAnswer(userQuestion, recoveryReport, profile, persona);
    return errorNotice.isNotEmpty ? '$errorNotice$localAnswer' : localAnswer;
  }

  String _generateLocalChatAnswer(String query, RecoveryReport report, AthleteProfile profile, CoachPersona persona) {
    final q = query.toLowerCase();

    final now = DateTime.now();
    final weekdaysRu = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
    final monthsRu = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final weekdayName = weekdaysRu[now.weekday - 1];
    final monthName = monthsRu[now.month - 1];
    final dateStr = '$weekdayName, ${now.day} $monthName ${now.year} г.';

    // Ответ на вопросы о дате, дне недели, времени
    if (q.contains('дат') || q.contains('число') || q.contains('день недели') || q.contains('какой сегодня') || q.contains('врем')) {
      if (persona == CoachPersona.productAdvisor) {
        return '📅 Сегодня $dateStr.\n\n'
            'Отличный день для оптимизации кода и тестирования Workout Timer! Напоминаю: проверьте адаптивность на экранах 20:9 (OnePlus 15) и стабильность работы таймера.';
      } else {
        final recGroup = report.recommendedGroup.displayName;
        return '📅 Сегодня $dateStr.\n\n'
            'По вашему восстановительному балансу сегодня отличный день для тренировки мышечной зоны **$recGroup**! '
            'Рекомендую выполнить легкую суставную разминку и выбрать комплекс из «Базы» или AI-Конструктора.';
      }
    }

    if (persona == CoachPersona.productAdvisor) {
      if (q.contains('google') || q.contains('play') || q.contains('релиз') || q.contains('публикац')) {
        return '🚀 Стратегия запуска в Google Play Store:\n\n'
            '1. **Подготовка сборки**: Соберите подписанный Android App Bundle (`flutter build appbundle --release`) с targetSdk 34+.\n'
            '2. **Политика конфиденциальности (Privacy Policy)**: Обязательна ссылка в консоли. Укажите, что данные тренировок хранятся локально (Hive) с опциональной синхронизацией Google/Firestore.\n'
            '3. **Графика и ASO**: Сделайте 4-6 скриншотов с устройства OnePlus (430x932) с яркими заголовками («Умный таймер EMOM & Табата», «ИИ-тренер и баланс мышц», «120 FPS и O-Haptics»). Иконка 512x512 и баннер 1024x500.\n'
            '4. **Закрытое тестирование**: С 2023 года для новых разработчиков Google требует закрытый тест с 20 тестировщиками в течение 14 дней перед открытым релизом.';
      }
      if (q.contains('десктоп') || q.contains('ноутбук') || q.contains('веб') || q.contains('экран')) {
        return '🖥️ Рекомендации для десктопной и веб-версии:\n\n'
            '1. **Режим «Большой экран зала» (Gym TV Mode)**: Разверните экран таймера на полный дисплей ноутбука — гигантские контрастные неоновые цифры и список следующих упражнений видны с расстояния 5-7 метров.\n'
            '2. **Многоколоночный каталог**: Адаптивная сетка 3-4 карточки в ряд позволяет охватить всю библиотеку упражнений без лишнего скролла.\n'
            '3. **Двусторонний бэкап в 1 клик**: Используйте JSON-экспорт и импорт, чтобы создавать комплексы на клавиатуре ноутбука и переносить на телефон.';
      }
      if (q.contains('фич') || q.contains('улучш') || q.contains('идеи') || q.contains('интерфейс')) {
        return '💡 Топ фичи для масштабирования продукта:\n\n'
            '1. **Умная замена упражнения на лету**: Возможность во время раунда нажать «Заменить» при боли или занятом тренажере.\n'
            '2. **Звуковые подсказки голосом (TTS)**: Чтение названия следующего упражнения за 3 секунды до старта раунда.\n'
            '3. **Виджеты на рабочий стол**: Виджет с текущим страйком тренировок и быстрой кнопкой запуска последнего комплекса.';
      }
      return 'Как продуктовый архитектор Workout Timer, я рекомендую сфокусироваться на подготовке скриншотов для Google Play, проверке адаптивности на ноутбуке и тестировании замены упражнений вживую!';
    }

    final rec = report.recommendedGroup.displayName;

    // 1. Гимнастика и калистеника
    if (q.contains('гимнастик') || q.contains('воркаут') || q.contains('калистеник') || q.contains('свой вес') || q.contains('турник')) {
      return '🤸 Гимнастика и калистеника (собственный вес):\n\n'
          '• **База движений**: Отжимания, подтягивания, уголок на брусьях/полу, стойка на руках у стены и планка «лодочка» (hollow body).\n'
          '• **Преимущество**: Развивает функциональную силу, здоровье связок и нейромышечный контроль без осевой нагрузки на позвоночник.\n'
          '• **Теги в приложении**: Вы можете пометить такие упражнения тегом **«Гимнастика»** в библиотеке или редакторе, чтобы мгновенно отфильтровать комплекс!';
    }

    // 2. Лимфодренаж и снятие отёчности
    if (q.contains('лимф') || q.contains('отек') || q.contains('отёк') || q.contains('застой') || q.contains('дренаж')) {
      return '💧 Лимфодренажная активность и восстановление:\n\n'
          '• **Лучшие упражнения**: Мягкие пружинящие прыжки на носочках («микровибрации»), перекаты с пятки на носок (100 раз), суставная гимнастика и диафрагмальное дыхание.\n'
          '• **Принцип**: У лимфатической системы нет собственного «насоса», как у сердца — лимфа движется исключительно за счёт сокращения скелетных мышц и дыхания.\n'
          '• **Совет**: Для таких легких сессий используйте отдельный тег **«Лимфа»** в конструкторе и выполняйте их утром или в дни отдыха!';
    }

    // 3. Теги и организация библиотеки
    if (q.contains('тег') || q.contains('хештег') || q.contains('хэштег') || q.contains('категори') || q.contains('фильтр')) {
      return '🏷️ Управление тегами и категориями в приложении:\n\n'
          '• **Встроенные теги**: Верх, Низ, ВИТ, Статика, Full Body, Гимнастика, Лимфа.\n'
          '• **Создание своих тегов**: В библиотеке упражнений при редактировании или создании нажмите «+ Добавить тег», введите название — и новый тег станет доступен во всём приложении.\n'
          '• **Быстрая фильтрация**: На главном экране и в библиотеке нажимайте на чипы тегов вверху, чтобы в 1 клик скрыть лишнее.';
    }

    // 4. AMRAP специфика и правила
    if (q.contains('amrap') || q.contains('амрап')) {
      return '⏱️ Система AMRAP (As Many Rounds / Reps As Possible):\n\n'
          '• **Суть**: Закончить как можно больше раундов или повторений за фиксированное общее время (например, 15 или 20 минут).\n'
          '• **Время на упражнение**: В AMRAP **нет таймера на каждое упражнение** — вы выполняете фиксированное число повторений (reps) и сразу переходите к следующему.\n'
          '• **Стратегия**: Не начинайте спринтом! Держите ровный темп ~75-80% от максимума, чтобы не закислиться в первые 3 минуты.';
    }

    // 5. EMOM специфика
    if (q.contains('emom') || q.contains('емом')) {
      return '⏰ Система EMOM (Every Minute On the Minute):\n\n'
          '• **Суть**: В начале каждой минуты стартует новое упражнение. Вы делаете заданное число повторов (обычно за 30-45 секунд), а оставшиеся секунды минуты — ваш чистый отдых.\n'
          '• **Дисциплина темпа**: EMOM учит строго контролировать время под нагрузкой и восстанавливаться в условиях жесткого тайминга.';
    }

    // 6. Табата (HIIT)
    if (q.contains('табат') || q.contains('tabata') || q.contains('интервал') || q.contains('вит') || q.contains('hiit')) {
      return '🔥 Протокол ТАБАТА (HIIT 20/10):\n\n'
          '• **Формат**: 20 секунд работы на предельной мощности, 10 секунд отдыха, 8 раундов (ровно 4 минуты).\n'
          '• **Эффект**: Максимальный разгон метаболизма, улучшение VO2 max и мощный кислородный долг (EPOC), сжигающий калории даже после тренировки.';
    }

    // 7. Статика и планки
    if (q.contains('планк') || q.contains('статик') || q.contains('пресс') || q.contains('кор') || q.contains('изометр')) {
      return '🛡️ Статические и изометрические упражнения:\n\n'
          '• Укрепляют глубокие постуральные стабилизаторы (поперечная мышца живота, разгибатели позвоночника, ягодичные) без динамического износа суставов.\n'
          '• **Главное правило**: Не задерживайте дыхание! Дышите глубоко и равномерно. Держите нейтральное положение позвоночника.';
    }

    // 8. Боль, травмы и дискомфорт
    if (q.contains('болит') || q.contains('травм') || q.contains('сустав') || q.contains('тянет') || q.contains('спин') || q.contains('колен')) {
      return '⚠️ При дискомфорте или болевых ощущениях:\n\n'
          '1. Немедленно прекратите упражнение, вызывающее острую боль. Тренироваться через боль недопустимо.\n'
          '2. Замените осевую нагрузку на безопасную статику или растяжку.\n'
          '3. Сегодня рекомендую дать отдых перегруженной зоне и аккуратно поработать над свежей группой: **$rec**.';
    }

    // 9. Замена упражнений
    if (q.contains('замен') || q.contains('поменять') || q.contains('альтернатив') || q.contains('аналог')) {
      return '🔄 Быстрые альтернативы упражнениям:\n\n'
          '• **Вместо приседаний**: Ягодичный мостик или статический «стульчик» у стены (разгружает колени).\n'
          '• **Вместо берпи**: Махи гирей / гантелью или прыжки «Jumping Jacks» без падения на пол.\n'
          '• **Вместо отжиманий**: Планка на локтях или статический упор лежа.';
    }

    // 10. Калории и похудение
    if (q.contains('калори') || q.contains('похудет') || q.contains('жир') || q.contains('вес') || q.contains('сушк')) {
      return '⚡ Энергозатраты и жиросжигание:\n\n'
          '• При вашем весе ~${profile.weightKg.round()} кг за 15-20 минут высокоинтенсивного комплекса (Табата / AMRAP) сжигается около 130-220 ккал.\n'
          '• Главный жиросжигающий фактор — постоянство тренировок (3-4 раза в неделю) и умеренный дефицит калорий в рационе.';
    }

    // 11. Питание и вода
    if (q.contains('питан') || q.contains('вод') || q.contains('пит') || q.contains('белок') || q.contains('протеин')) {
      return '🥗 Водный баланс и восстановление:\n\n'
          '• Пейте 1.5-2.5 литра чистой воды в день (около 30 мл на 1 кг веса).\n'
          '• За 1 час до интенсивного комплекса выпейте стакан воды, а после тренировки восполните электролиты и белок для мышц.';
    }

    // 12. Разминка и заминка
    if (q.contains('разминк') || q.contains('заминк') || q.contains('растяжк') || q.contains('стретч')) {
      return '🧘 Важность разминки и заминки:\n\n'
          '• **Разминка (3-5 мин)**: Вращения в суставах, легкий бег на месте. Повышает температуру мышц и синовиальную жидкость в суставах.\n'
          '• **Заминка (3 мин)**: Плавное дыхание, вис на турнике или мягкая растяжка задней поверхности бедра и грудных мышц.';
    }

    // 13. Приветствие / общее знакомство
    if (q.contains('привет') || q.contains('здравствуй') || q.contains('кто ты') || q.contains('что умеешь')) {
      return 'Привет, чемпион! Я твой спортивный наставник и физиолог в Workout Timer. '
          'Я анализирую баланс восстановления твоих мышц, подсказываю оптимальную нагрузку, объясняю нюансы EMOM, Табата и AMRAP, а также помогаю настроить упражнения с тегами «Гимнастика», «Лимфа» и другими. Чем могу помочь сегодня?';
    }

    // 14. Динамический умный ответ по текущему статусу атлета
    return '📊 По вашему профилю (${profile.fitnessLevel.name}, ${profile.weightKg.round()} кг) наиболее отдохнувшая и готовая к нагрузке зона — **$rec**.\n\n'
        'Вы можете запустить готовый комплекс из библиотеки, отфильтровать по тегам или сгенерировать новую тренировку в AI-Конструкторе!';
  }
}

final geminiCoachServiceProvider = Provider<GeminiCoachService>((ref) {
  final profile = ref.watch(athleteProfileProvider);
  return GeminiCoachService(profile.geminiApiKey);
});
