import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/core/pluralization.dart';

void main() {
  group('RussianPlural tests', () {
    test('circuits declension', () {
      expect(RussianPlural.circuits(1), '1 круг');
      expect(RussianPlural.circuits(2), '2 круга');
      expect(RussianPlural.circuits(3), '3 круга');
      expect(RussianPlural.circuits(4), '4 круга');
      expect(RussianPlural.circuits(5), '5 кругов');
      expect(RussianPlural.circuits(11), '11 кругов');
      expect(RussianPlural.circuits(12), '12 кругов');
      expect(RussianPlural.circuits(21), '21 круг');
      expect(RussianPlural.circuits(22), '22 круга');
      expect(RussianPlural.circuits(25), '25 кругов');
    });

    test('rounds declension', () {
      expect(RussianPlural.rounds(1), '1 раунд');
      expect(RussianPlural.rounds(2), '2 раунда');
      expect(RussianPlural.rounds(4), '4 раунда');
      expect(RussianPlural.rounds(5), '5 раундов');
      expect(RussianPlural.rounds(10), '10 раундов');
      expect(RussianPlural.rounds(12), '12 раундов');
      expect(RussianPlural.rounds(21), '21 раунд');
    });

    test('exercises declension', () {
      expect(RussianPlural.exercises(1), '1 упражнение');
      expect(RussianPlural.exercises(2), '2 упражнения');
      expect(RussianPlural.exercises(3), '3 упражнения');
      expect(RussianPlural.exercises(4), '4 упражнения');
      expect(RussianPlural.exercises(5), '5 упражнений');
      expect(RussianPlural.exercises(11), '11 упражнений');
      expect(RussianPlural.exercises(21), '21 упражнение');
    });

    test('workouts declension', () {
      expect(RussianPlural.workouts(1), '1 комплекс');
      expect(RussianPlural.workouts(2), '2 комплекса');
      expect(RussianPlural.workouts(4), '4 комплекса');
      expect(RussianPlural.workouts(5), '5 комплексов');
      expect(RussianPlural.workouts(11), '11 комплексов');
      expect(RussianPlural.workouts(21), '21 комплекс');
      expect(RussianPlural.workouts(25), '25 комплексов');
    });

    test('daysAgo declension', () {
      expect(RussianPlural.daysAgo(0), 'Сегодня');
      expect(RussianPlural.daysAgo(1), 'Вчера');
      expect(RussianPlural.daysAgo(2), '2 дня назад');
      expect(RussianPlural.daysAgo(5), '5 дней назад');
      expect(RussianPlural.daysAgo(2, short: true), '2 дня');
      expect(RussianPlural.daysAgo(5, short: true), '5 дней');
    });

    test('years declension', () {
      expect(RussianPlural.years(1), '1 год');
      expect(RussianPlural.years(2), '2 года');
      expect(RussianPlural.years(3), '3 года');
      expect(RussianPlural.years(4), '4 года');
      expect(RussianPlural.years(5), '5 лет');
      expect(RussianPlural.years(11), '11 лет');
      expect(RussianPlural.years(14), '14 лет');
      expect(RussianPlural.years(21), '21 год');
      expect(RussianPlural.years(43), '43 года');
      expect(RussianPlural.years(55), '55 лет');
    });
  });

  group('PluralHelper tests', () {
    test('English and Russian locale support', () {
      expect(PluralHelper.circuits(3, 'ru'), '3 круга');
      expect(PluralHelper.circuits(3, 'en'), '3 circuits');
      expect(PluralHelper.rounds(4, 'ru'), '4 раунда');
      expect(PluralHelper.rounds(4, 'en'), '4 rounds');
      expect(PluralHelper.exercises(4, 'ru'), '4 упражнения');
      expect(PluralHelper.exercises(4, 'en'), '4 exercises');
    });
  });
}
