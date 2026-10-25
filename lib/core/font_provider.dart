import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AppFontFamily {
  roboto('Roboto', 'Классический Roboto'),
  system('System', 'Системный шрифт устройства'),
  sansSerif('Sans-Serif', 'Современный гротеск');

  final String fontFamilyName;
  final String label;
  const AppFontFamily(this.fontFamilyName, this.label);
}

class FontNotifier extends StateNotifier<AppFontFamily> {
  FontNotifier() : super(_loadSavedFont());

  static AppFontFamily _loadSavedFont() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final saved = box.get('app_font', defaultValue: 'roboto') as String;
        return AppFontFamily.values.firstWhere(
          (f) => f.name == saved,
          orElse: () => AppFontFamily.roboto,
        );
      }
    } catch (_) {}
    return AppFontFamily.roboto; // Roboto по умолчанию
  }

  void setFont(AppFontFamily font) {
    state = font;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('app_font', font.name);
      }
    } catch (_) {}
  }
}

final fontProvider = StateNotifierProvider<FontNotifier, AppFontFamily>((ref) {
  return FontNotifier();
});
