import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workout_timer/data/models/athlete_profile.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/data/repositories/tags_repository.dart';
import 'package:workout_timer/services/gemini_coach_service.dart';
import 'package:workout_timer/services/recovery_analyzer.dart';

class FakeBox implements Box {
  final Map<dynamic, dynamic> _storage = {};

  @override
  dynamic get(key, {defaultValue}) => _storage.containsKey(key) ? _storage[key] : defaultValue;

  @override
  Future<void> put(key, value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(key) async {
    _storage.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TagsRepository Tests', () {
    late FakeBox fakeBox;
    late TagsRepository repository;

    setUp(() {
      fakeBox = FakeBox();
      repository = TagsRepository(fakeBox);
    });

    test('default tags include Гимнастика and Лимфа', () {
      final tags = repository.getTags();
      expect(tags, contains('Верх'));
      expect(tags, contains('Низ'));
      expect(tags, contains('Гимнастика'));
      expect(tags, contains('Лимфа'));
      expect(repository.isDefaultTag('гимнастика'), isTrue);
      expect(repository.isDefaultTag('лимфа'), isTrue);
    });

    test('addTag capitalizes and persists new tag', () async {
      await repository.addTag('кардио');
      final tags = repository.getTags();
      expect(tags, contains('Кардио'));
      expect(repository.isDefaultTag('Кардио'), isFalse);
    });

    test('renameTag updates custom tag', () async {
      await repository.addTag('пилатес');
      await repository.renameTag('Пилатес', 'Стретчинг');
      final tags = repository.getTags();
      expect(tags, contains('Стретчинг'));
      expect(tags, isNot(contains('Пилатес')));
    });

    test('deleteTag removes custom tag', () async {
      await repository.addTag('йога');
      expect(repository.getTags(), contains('Йога'));
      await repository.deleteTag('Йога');
      expect(repository.getTags(), isNot(contains('Йога')));
    });
  });

  group('GeminiCoachService Local Expert Tests', () {
    late GeminiCoachService service;
    late RecoveryReport dummyReport;
    late AthleteProfile dummyProfile;

    setUp(() {
      service = GeminiCoachService(null); // Offline mode
      dummyReport = RecoveryAnalyzer.analyze(
        recentSessions: [],
        availableWorkouts: [],
        now: DateTime(2026, 10, 19, 12, 0),
      );
      dummyProfile = const AthleteProfile(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        fitnessLevel: FitnessLevel.intermediate,
        gender: 'male',
      );
    });

    test('answers gymnastics query with clean tag advice', () async {
      final response = await service.sendChatMessage(
        messages: [{'role': 'user', 'text': 'Расскажи про гимнастику и турник'}],
        profile: dummyProfile,
        recoveryReport: dummyReport,
        recentSessions: [],
      );
      expect(response, contains('Гимнастика'));
      expect(response, contains('«Гимнастика»'));
    });

    test('answers lymph query with clean tag advice', () async {
      final response = await service.sendChatMessage(
        messages: [{'role': 'user', 'text': 'Как разогнать лимфу и снять отёки?'}],
        profile: dummyProfile,
        recoveryReport: dummyReport,
        recentSessions: [],
      );
      expect(response, contains('Лимфодренаж'));
      expect(response, contains('«Лимфа»'));
    });

    test('answers date query with current day and formatted date', () async {
      final response = await service.sendChatMessage(
        messages: [{'role': 'user', 'text': 'какая сегодня дата'}],
        profile: dummyProfile,
        recoveryReport: dummyReport,
        recentSessions: [],
      );
      expect(response, contains('Сегодня'));
      expect(response, contains('202'));
    });

    test('answers AMRAP rules query explaining no per-exercise timer', () async {
      final response = await service.sendChatMessage(
        messages: [{'role': 'user', 'text': 'Какие правила в amrap?'}],
        profile: dummyProfile,
        recoveryReport: dummyReport,
        recentSessions: [],
      );
      expect(response, contains('AMRAP'));
      expect(response, contains('нет таймера на каждое упражнение'));
    });

    test('answers tags query explaining management', () async {
      final response = await service.sendChatMessage(
        messages: [{'role': 'user', 'text': 'Как работают теги и категории?'}],
        profile: dummyProfile,
        recoveryReport: dummyReport,
        recentSessions: [],
      );
      expect(response, contains('Управление тегами'));
      expect(response, contains('Гимнастика'));
      expect(response, contains('Лимфа'));
    });
  });

  group('AMRAP Workout Exercise Logic Tests', () {
    test('AMRAP dynamic exercises have no duration and default reps', () {
      final workout = Workout()
        ..name = 'Тест AMRAP'
        ..type = WorkoutType.amrap
        ..amrapDurationSeconds = 900
        ..exercises = [
          Exercise()..name = 'Подтягивания'..reps = 10..durationSeconds = null,
          Exercise()..name = 'Отжимания'..reps = 15..durationSeconds = null,
        ];

      expect(workout.type, equals(WorkoutType.amrap));
      for (final e in workout.exercises) {
        expect(e.durationSeconds, isNull);
        expect(e.reps, isNotNull);
        expect(e.reps! > 0, isTrue);
      }
    });
  });
}
