import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TagsRepository {
  static const String _kCustomTagsKey = 'custom_tags';
  static const String _kHiddenTagsKey = 'hidden_tags';
  static const List<String> defaultTags = [
    'Верх',
    'Низ',
    'Кор',
    'Статика',
    'ВИТ',
    'Full Body',
    'Свой вес',
    'Резинка',
    'Гимнастика',
    'Лимфа',
    '16 кг',
    '6 кг',
  ];

  final Box _box;

  TagsRepository(this._box);

  static String capitalize(String text) {
    var t = text.trim();
    while (t.startsWith('#')) {
      t = t.substring(1).trim();
    }
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  List<String> getTags() {
    final rawHidden = _box.get(_kHiddenTagsKey);
    final Set<String> hidden = {};
    if (rawHidden is List) {
      for (final item in rawHidden) {
        if (item is String) hidden.add(capitalize(item));
      }
    }

    final raw = _box.get(_kCustomTagsKey);
    final List<String> custom = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          final cap = capitalize(item);
          // If custom tag has old double tags like "Кор и статика" or "Только статика", normalize out
          if (cap == 'Кор и статика' || cap == 'Только статика' || cap == 'Кор и Статика') {
            continue;
          }
          custom.add(cap);
        }
      }
    }

    final Set<String> merged = {};
    for (final tag in defaultTags) {
      if (!hidden.contains(tag)) {
        merged.add(tag);
      }
    }
    for (final tag in custom) {
      if (!hidden.contains(tag)) {
        merged.add(tag);
      }
    }
    return merged.toList();
  }

  Future<void> addTag(String tag) async {
    final formatted = capitalize(tag);
    if (formatted.isEmpty) return;

    // Unhide if was hidden
    final rawHidden = _box.get(_kHiddenTagsKey);
    if (rawHidden is List && rawHidden.contains(formatted)) {
      final List<String> hidden = List<String>.from(rawHidden);
      hidden.remove(formatted);
      await _box.put(_kHiddenTagsKey, hidden);
    }

    final tags = getTags();
    if (!tags.contains(formatted)) {
      final raw = _box.get(_kCustomTagsKey);
      final List<String> custom = (raw is List) ? List<String>.from(raw) : [];
      if (!custom.contains(formatted)) {
        custom.add(formatted);
        await _box.put(_kCustomTagsKey, custom);
      }
    }
  }

  Future<void> renameTag(String oldTag, String newTag) async {
    final formattedOld = capitalize(oldTag);
    final formattedNew = capitalize(newTag);
    if (formattedNew.isEmpty || formattedOld == formattedNew) return;

    await deleteTag(formattedOld);
    await addTag(formattedNew);
  }

  Future<void> bulkAddTags(Iterable<String> tags) async {
    for (final tag in tags) {
      await addTag(tag);
    }
  }

  Future<void> deleteTag(String tag) async {
    final formatted = capitalize(tag);
    final raw = _box.get(_kCustomTagsKey);
    if (raw is List) {
      final List<String> custom = List<String>.from(raw);
      custom.remove(formatted);
      await _box.put(_kCustomTagsKey, custom);
    }
    // Also track in hidden tags so default tags can be deleted/hidden too!
    final rawHidden = _box.get(_kHiddenTagsKey);
    final List<String> hidden = (rawHidden is List) ? List<String>.from(rawHidden) : [];
    if (!hidden.contains(formatted)) {
      hidden.add(formatted);
      await _box.put(_kHiddenTagsKey, hidden);
    }
  }

  bool isDefaultTag(String tag) {
    return defaultTags.contains(capitalize(tag));
  }
}

class TagsNotifier extends StateNotifier<List<String>> {
  final TagsRepository _repo;

  TagsNotifier(this._repo) : super(_repo.getTags());

  void refresh() {
    state = _repo.getTags();
  }

  Future<void> addTag(String tag) async {
    await _repo.addTag(tag);
    state = _repo.getTags();
  }

  Future<void> bulkAddTags(Iterable<String> tags) async {
    await _repo.bulkAddTags(tags);
    state = _repo.getTags();
  }

  Future<void> renameTag(String oldTag, String newTag) async {
    await _repo.renameTag(oldTag, newTag);
    state = _repo.getTags();
  }

  Future<void> deleteTag(String tag) async {
    await _repo.deleteTag(tag);
    state = _repo.getTags();
  }

  bool isDefaultTag(String tag) => _repo.isDefaultTag(tag);
}

final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  final box = Hive.isBoxOpen('settings') ? Hive.box('settings') : null;
  return TagsRepository(box ?? Hive.box('settings'));
});

final tagsNotifierProvider = StateNotifierProvider<TagsNotifier, List<String>>((ref) {
  final repo = ref.watch(tagsRepositoryProvider);
  return TagsNotifier(repo);
});

final tagsProvider = Provider<List<String>>((ref) {
  return ref.watch(tagsNotifierProvider);
});
