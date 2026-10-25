/// Pluralization and declension helper with full grammatical support for Russian, English, German and Croatian.
class RussianPlural {
  static String plural(int count, String one, String few, String many) {
    final absCount = count.abs();
    final rem100 = absCount % 100;
    final rem10 = absCount % 10;
    if (rem100 >= 11 && rem100 <= 19) {
      return '$count $many';
    }
    if (rem10 == 1) {
      return '$count $one';
    }
    if (rem10 >= 2 && rem10 <= 4) {
      return '$count $few';
    }
    return '$count $many';
  }

  /// 1 круг, 2 круга, 5 кругов
  static String circuits(int count) => plural(count, 'круг', 'круга', 'кругов');

  /// 1 раунд, 2 раунда, 5 раундов
  static String rounds(int count) => plural(count, 'раунд', 'раунда', 'раундов');

  /// 1 упражнение, 2 упражнения, 5 упражнений
  static String exercises(int count) => plural(count, 'упражнение', 'упражнения', 'упражнений');

  /// 1 секунда, 2 секунды, 5 секунд
  static String seconds(int count) => plural(count, 'секунда', 'секунды', 'секунд');

  /// 1 минута, 2 минуты, 5 минут
  static String minutes(int count) => plural(count, 'минута', 'минуты', 'минут');

  /// 1 повторение, 2 повторения, 5 повторений
  static String reps(int count) => plural(count, 'повторение', 'повторения', 'повторений');

  /// 1 год, 2 года, 5 лет, 43 года
  static String years(int count) => plural(count, 'год', 'года', 'лет');

  /// Сегодня, Вчера, 2 дня назад, 5 дней назад
  static String daysAgo(int days, {bool short = false}) {
    if (days == 0) return 'Сегодня';
    if (days == 1) return 'Вчера';
    if (short) {
      return plural(days, 'день', 'дня', 'дней');
    }
    return plural(days, 'день назад', 'дня назад', 'дней назад');
  }
}

class PluralHelper {
  static String circuits(int count, [String? localeCode]) {
    final lang = localeCode ?? 'ru';
    if (lang == 'ru') {
      return RussianPlural.circuits(count);
    }
    if (lang == 'de') {
      return count == 1 ? '$count Runde' : '$count Runden';
    }
    if (lang == 'hr') {
      return RussianPlural.plural(count, 'krug', 'kruga', 'krugova');
    }
    return count == 1 ? '$count circuit' : '$count circuits';
  }

  static String rounds(int count, [String? localeCode]) {
    final lang = localeCode ?? 'ru';
    if (lang == 'ru') {
      return RussianPlural.rounds(count);
    }
    if (lang == 'de') {
      return count == 1 ? '$count Runde' : '$count Runden';
    }
    if (lang == 'hr') {
      return RussianPlural.plural(count, 'runda', 'runde', 'rundi');
    }
    return count == 1 ? '$count round' : '$count rounds';
  }

  static String exercises(int count, [String? localeCode]) {
    final lang = localeCode ?? 'ru';
    if (lang == 'ru') {
      return RussianPlural.exercises(count);
    }
    if (lang == 'de') {
      return count == 1 ? '$count Übung' : '$count Übungen';
    }
    if (lang == 'hr') {
      return RussianPlural.plural(count, 'vježba', 'vježbe', 'vježbi');
    }
    return count == 1 ? '$count exercise' : '$count exercises';
  }

  static String daysAgo(int days, {bool short = false, String? localeCode}) {
    final lang = localeCode ?? 'ru';
    if (lang == 'ru') {
      return RussianPlural.daysAgo(days, short: short);
    }
    if (lang == 'de') {
      if (days == 0) return 'Heute';
      if (days == 1) return 'Gestern';
      return 'vor $days Tagen';
    }
    if (lang == 'hr') {
      if (days == 0) return 'Danas';
      if (days == 1) return 'Jučer';
      return 'prije $days dana';
    }
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  static String years(int count, [String? localeCode]) {
    final lang = localeCode ?? 'ru';
    if (lang == 'ru') {
      return RussianPlural.years(count);
    }
    if (lang == 'de') {
      return count == 1 ? '$count Jahr' : '$count Jahre';
    }
    if (lang == 'hr') {
      return RussianPlural.plural(count, 'godina', 'godine', 'godina');
    }
    return count == 1 ? '$count year' : '$count years';
  }
}
