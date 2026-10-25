import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/audio_service.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_loadInitialLocale());

  static Locale _loadInitialLocale() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final saved = Hive.box('settings').get(_kLocaleKey) as String?;
        if (saved != null) return Locale(saved);
      }
    } catch (_) {}
    return const Locale('ru');
  }

  Future<void> setLocale(Locale locale) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').put(_kLocaleKey, locale.languageCode);
      }
    } catch (_) {}
    AudioService().updateLanguage(locale.languageCode);
    state = locale;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
