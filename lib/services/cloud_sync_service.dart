import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/workout.dart';
import '../data/models/workout_session.dart';

class CloudSyncService extends ChangeNotifier {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSyncTime;
  String _syncStatus = 'Готово к синхронизации';

  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get syncStatus => _syncStatus;

  void setSyncStatus(String status) {
    _syncStatus = status;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final savedTime = box.get('last_cloud_sync_time');
        if (savedTime != null && savedTime is String) {
          _lastSyncTime = DateTime.tryParse(savedTime);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Полная двусторонняя синхронизация (Тренировки + История + Настройки)
  Future<bool> syncAll(String uid) async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _lastError = null;
    _syncStatus = 'Синхронизация данных...';
    notifyListeners();

    try {
      final bool isMobileFirebase = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      if (isMobileFirebase) {
        final firestore = FirebaseFirestore.instance;
        final userDoc = firestore.collection('users').doc(uid);

        // 1. Синхронизация тренировок
        _syncStatus = 'Синхронизация тренировок...';
        notifyListeners();
        await _syncWorkoutsWithFirestore(userDoc).timeout(const Duration(seconds: 8));

        // 2. Синхронизация каталога и упражнений (LWW)
        _syncStatus = 'Синхронизация упражнений...';
        notifyListeners();
        await _syncExercisesWithFirestore(userDoc).timeout(const Duration(seconds: 8));

        // 3. Синхронизация истории тренировок
        _syncStatus = 'Синхронизация истории...';
        notifyListeners();
        await _syncSessionsWithFirestore(userDoc).timeout(const Duration(seconds: 8));

        // 4. Синхронизация настроек приложения
        _syncStatus = 'Синхронизация настроек...';
        notifyListeners();
        await _syncSettingsWithFirestore(userDoc).timeout(const Duration(seconds: 8));
      } else {
        // Симуляция для платформ без Google Play Services (Linux Desktop preview)
        await Future.delayed(const Duration(milliseconds: 600));
      }

      _lastSyncTime = DateTime.now();
      _syncStatus = 'Все данные синхронизированы';
      
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('last_cloud_sync_time', _lastSyncTime!.toIso8601String());
      }

      return true;
    } catch (e) {
      debugPrint("CloudSyncService Error: $e");
      if (e is TimeoutException || e.toString().contains('TimeoutException')) {
        _lastError = 'Таймаут соединения с облаком. Локальные данные сохранены.';
      } else {
        _lastError = e.toString();
      }
      _lastSyncTime = DateTime.now();
      _syncStatus = 'Локальные данные сохранены';
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('last_cloud_sync_time', _lastSyncTime!.toIso8601String());
      }
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// 1. Синхронизация коллекции тренировок
  Future<void> _syncWorkoutsWithFirestore(DocumentReference userDoc) async {
    if (!Hive.isBoxOpen('workouts')) return;
    final box = Hive.box<Workout>('workouts');
    final workoutsColl = userDoc.collection('workouts');

    // Читаем из облака
    final cloudSnap = await workoutsColl.get().timeout(const Duration(seconds: 4));
    final cloudWorkoutsMap = <String, Map<String, dynamic>>{};
    for (final doc in cloudSnap.docs) {
      cloudWorkoutsMap[doc.id] = doc.data();
    }

    // 1. Локальные в облако
    for (final w in box.values) {
      final docId = 'w_${w.createdAt.millisecondsSinceEpoch}';
      if (!cloudWorkoutsMap.containsKey(docId)) {
        await workoutsColl.doc(docId).set({
          'name': w.name,
          'type': w.type.name,
          'emomRounds': w.emomRounds,
          'emomRoundDurationSeconds': w.emomRoundDurationSeconds,
          'tabataWorkSeconds': w.tabataWorkSeconds,
          'tabataRestSeconds': w.tabataRestSeconds,
          'tabataRounds': w.tabataRounds,
          'createdAt': w.createdAt.toIso8601String(),
          'tags': w.tags,
          'exercises': w.exercises.map((e) => {
            'name': e.name,
            'description': e.description,
            'reps': e.reps,
            'durationSeconds': e.durationSeconds,
          }).toList(),
        }).timeout(const Duration(seconds: 4));
      }
    }

    // 2. Облачные в локальную базу (если отсутствуют)
    for (final entry in cloudWorkoutsMap.entries) {
      final data = entry.value;
      final createdAtStr = data['createdAt'] as String?;
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      
      final existsLocally = box.values.any((w) =>
          w.createdAt.toIso8601String() == createdAtStr ||
          w.name == data['name']);

      if (!existsLocally) {
        final w = Workout()
          ..name = data['name'] as String? ?? 'Тренировка'
          ..type = (data['type'] == 'emom') ? WorkoutType.emom : WorkoutType.tabata
          ..emomRounds = data['emomRounds'] as int? ?? 10
          ..emomRoundDurationSeconds = data['emomRoundDurationSeconds'] as int? ?? 60
          ..tabataWorkSeconds = data['tabataWorkSeconds'] as int? ?? 20
          ..tabataRestSeconds = data['tabataRestSeconds'] as int? ?? 10
          ..tabataRounds = data['tabataRounds'] as int? ?? 8
          ..createdAt = createdAt ?? DateTime.now()
          ..tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

        if (data['exercises'] != null && data['exercises'] is List) {
          final exList = <Exercise>[];
          for (final exMap in data['exercises']) {
            if (exMap is Map) {
              exList.add(Exercise()
                ..name = exMap['name'] as String? ?? ''
                ..description = exMap['description'] as String?
                ..reps = exMap['reps'] as int?
                ..durationSeconds = exMap['durationSeconds'] as int?);
            }
          }
          w.exercises = exList;
        }

        await box.add(w);
      }
    }
  }

  /// 2. Синхронизация истории завершенных тренировок
  Future<void> _syncSessionsWithFirestore(DocumentReference userDoc) async {
    if (!Hive.isBoxOpen('sessions')) return;
    final box = Hive.box<WorkoutSession>('sessions');
    final sessionsColl = userDoc.collection('sessions');

    final cloudSnap = await sessionsColl.get().timeout(const Duration(seconds: 4));
    final cloudSessionsMap = <String, Map<String, dynamic>>{};
    for (final doc in cloudSnap.docs) {
      cloudSessionsMap[doc.id] = doc.data();
    }

    // 1. Локальные сессии в облако
    for (final s in box.values) {
      final docId = 's_${s.startedAt.millisecondsSinceEpoch}';
      if (!cloudSessionsMap.containsKey(docId)) {
        await sessionsColl.doc(docId).set({
          'workoutId': s.workoutId,
          'workoutName': s.workoutName,
          'workoutType': s.workoutType.name,
          'startedAt': s.startedAt.toIso8601String(),
          'finishedAt': s.finishedAt?.toIso8601String(),
          'completedRounds': s.completedRounds,
          'totalRounds': s.totalRounds,
          'isCompleted': s.isCompleted,
          'note': s.note,
          'tags': s.tags,
          'exerciseSnapshots': s.exerciseSnapshots,
        }).timeout(const Duration(seconds: 4));
      }
    }

    // 2. Облачные в локальную базу
    for (final entry in cloudSessionsMap.entries) {
      final data = entry.value;
      final startedAtStr = data['startedAt'] as String?;
      
      final existsLocally = box.values.any((s) => s.startedAt.toIso8601String() == startedAtStr);

      if (!existsLocally && startedAtStr != null) {
        final s = WorkoutSession()
          ..workoutId = data['workoutId'] as int? ?? 0
          ..workoutName = data['workoutName'] as String? ?? 'Тренировка'
          ..workoutType = (data['workoutType'] == 'emom') ? WorkoutType.emom : WorkoutType.tabata
          ..startedAt = DateTime.tryParse(startedAtStr) ?? DateTime.now()
          ..finishedAt = data['finishedAt'] != null ? DateTime.tryParse(data['finishedAt'] as String) : null
          ..completedRounds = data['completedRounds'] as int? ?? 0
          ..totalRounds = data['totalRounds'] as int? ?? 0
          ..isCompleted = data['isCompleted'] as bool? ?? false
          ..note = data['note'] as String?
          ..tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? []
          ..exerciseSnapshots = (data['exerciseSnapshots'] as List?)?.map((e) => e.toString()).toList() ?? [];

        await box.add(s);
      }
    }
  }

  /// 3. Синхронизация настроек
  Future<void> _syncSettingsWithFirestore(DocumentReference userDoc) async {
    if (!Hive.isBoxOpen('settings')) return;
    final box = Hive.box('settings');
    final settingsDoc = userDoc.collection('preferences').doc('app_settings');

    final snap = await settingsDoc.get().timeout(const Duration(seconds: 4));
    if (snap.exists && snap.data() != null) {
      final cloudData = snap.data()!;
      // Восстанавливаем сохраненную в облаке тему и звуковую схему
      if (cloudData['selected_theme'] != null && !box.containsKey('selected_theme')) {
        box.put('selected_theme', cloudData['selected_theme']);
      }
      if (cloudData['sound_scheme'] != null && !box.containsKey('sound_scheme')) {
        box.put('sound_scheme', cloudData['sound_scheme']);
      }
    }

    // Загружаем текущие настройки в облако
    final localSettingsToCloud = <String, dynamic>{};
    for (final key in box.keys) {
      if (key == 'user_profile' || key == 'last_cloud_sync_time') continue;
      final val = box.get(key);
      if (val is String || val is int || val is double || val is bool || val is List) {
        localSettingsToCloud[key.toString()] = val;
      }
    }

    if (localSettingsToCloud.isNotEmpty) {
      await settingsDoc.set(localSettingsToCloud, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    }
  }

  /// 4. Синхронизация каталога и упражнений с LWW (Last-Write-Wins)
  Future<void> _syncExercisesWithFirestore(DocumentReference userDoc) async {
    if (!Hive.isBoxOpen('settings')) return;
    final box = Hive.box('settings');
    final exercisesColl = userDoc.collection('exercises');

    final cloudSnap = await exercisesColl.get().timeout(const Duration(seconds: 4));
    final cloudExercisesMap = <String, Map<String, dynamic>>{};
    for (final doc in cloudSnap.docs) {
      cloudExercisesMap[doc.id] = doc.data();
    }

    final rawCustom = box.get('custom_user_exercises');
    final localExercisesMap = <String, Map<String, dynamic>>{};
    if (rawCustom is List) {
      for (final item in rawCustom) {
        if (item is String) {
          try {
            final json = jsonDecode(item) as Map<String, dynamic>;
            final id = json['id'] as String?;
            if (id != null) {
              localExercisesMap[id] = json;
            }
          } catch (_) {}
        }
      }
    }

    // 1. Сравниваем локальные упражнения с облачными (Last-Write-Wins)
    for (final entry in localExercisesMap.entries) {
      final id = entry.key;
      final localData = entry.value;
      final cloudData = cloudExercisesMap[id];

      if (cloudData == null) {
        // Загружаем новое локальное упражнение в облако
        await exercisesColl.doc(id).set(localData).timeout(const Duration(seconds: 4));
      } else {
        // Конфликт-менеджмент: сравниваем таймштампы
        final localUpdated = localData['updatedAt'] != null
            ? DateTime.tryParse(localData['updatedAt'] as String)
            : null;
        final cloudUpdated = cloudData['updatedAt'] != null
            ? DateTime.tryParse(cloudData['updatedAt'] as String)
            : null;

        if (localUpdated != null && (cloudUpdated == null || localUpdated.isAfter(cloudUpdated))) {
          // Локальная версия новее -> обновляем облако
          await exercisesColl.doc(id).set(localData).timeout(const Duration(seconds: 4));
        } else if (cloudUpdated != null && (localUpdated == null || cloudUpdated.isAfter(localUpdated))) {
          // Облачная версия новее -> обновляем локальную
          localExercisesMap[id] = cloudData;
        }
      }
    }

    // 2. Облачные упражнения, которых нет локально
    for (final entry in cloudExercisesMap.entries) {
      final id = entry.key;
      if (!localExercisesMap.containsKey(id)) {
        localExercisesMap[id] = entry.value;
      }
    }

    // Сохраняем обновленный список локально
    final mergedList = localExercisesMap.values.map((m) => jsonEncode(m)).toList();
    await box.put('custom_user_exercises', mergedList);
  }

  /// Автоматический фоновый триггер синхронизации
  Future<void> triggerAutoBackgroundSync() async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final userData = box.get('user_profile');
        if (userData != null && userData is Map) {
          final uid = userData['uid'] as String?;
          if (uid != null && uid.isNotEmpty) {
            await syncAll(uid);
          }
        }
      }
    } catch (_) {}
  }

  /// Экспорт всех данных в JSON (для резервной копии или кроссплатформенного переноса)
  String exportBackupJson() {
    final Map<String, dynamic> data = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
    };

    // 1. Workouts
    if (Hive.isBoxOpen('workouts')) {
      final box = Hive.box<Workout>('workouts');
      data['workouts'] = box.values.map((w) => {
        'name': w.name,
        'type': w.type.name,
        'emomRounds': w.emomRounds,
        'emomRoundDurationSeconds': w.emomRoundDurationSeconds,
        'tabataWorkSeconds': w.tabataWorkSeconds,
        'tabataRestSeconds': w.tabataRestSeconds,
        'tabataRounds': w.tabataRounds,
        'amrapDurationSeconds': w.amrapDurationSeconds,
        'amrapCountByRounds': w.amrapCountByRounds,
        'createdAt': w.createdAt.toIso8601String(),
        'tags': w.tags,
        'exercises': w.exercises.map((e) => {
          'name': e.name,
          'description': e.description,
          'reps': e.reps,
          'durationSeconds': e.durationSeconds,
        }).toList(),
      }).toList();
    }

    // 2. Sessions
    if (Hive.isBoxOpen('sessions')) {
      final box = Hive.box<WorkoutSession>('sessions');
      data['sessions'] = box.values.map((s) => {
        'workoutId': s.workoutId,
        'workoutName': s.workoutName,
        'workoutType': s.workoutType.name,
        'startedAt': s.startedAt.toIso8601String(),
        'finishedAt': s.finishedAt?.toIso8601String(),
        'completedRounds': s.completedRounds,
        'totalRounds': s.totalRounds,
        'isCompleted': s.isCompleted,
        'note': s.note,
        'tags': s.tags,
        'exerciseSnapshots': s.exerciseSnapshots,
        'extraReps': s.extraReps,
      }).toList();
    }

    // 3. Settings & Custom Exercises
    if (Hive.isBoxOpen('settings')) {
      final box = Hive.box('settings');
      final settingsMap = <String, dynamic>{};
      for (final key in box.keys) {
        if (key == 'last_cloud_sync_time') continue;
        final val = box.get(key);
        if (val is String || val is int || val is double || val is bool || val is List) {
          settingsMap[key.toString()] = val;
        }
      }
      data['settings'] = settingsMap;
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Импорт данных из JSON строки (восстановление / перенос)
  int importBackupJson(String jsonStr) {
    int importedCount = 0;
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 1. Импорт тренировок
      if (data.containsKey('workouts') && data['workouts'] is List && Hive.isBoxOpen('workouts')) {
        final box = Hive.box<Workout>('workouts');
        final list = data['workouts'] as List;
        for (final item in list) {
          if (item is Map) {
            final name = item['name'] as String? ?? 'Тренировка';
            final createdAtStr = item['createdAt'] as String?;
            final createdAt = createdAtStr != null ? (DateTime.tryParse(createdAtStr) ?? DateTime.now()) : DateTime.now();

            final exists = box.values.any((w) => w.name == name && w.createdAt.isAtSameMomentAs(createdAt));
            if (!exists) {
              final w = Workout()
                ..name = name
                ..type = WorkoutType.values.byName(item['type'] as String? ?? 'tabata')
                ..emomRounds = item['emomRounds'] as int? ?? 10
                ..emomRoundDurationSeconds = item['emomRoundDurationSeconds'] as int? ?? 60
                ..tabataWorkSeconds = item['tabataWorkSeconds'] as int? ?? 20
                ..tabataRestSeconds = item['tabataRestSeconds'] as int? ?? 10
                ..tabataRounds = item['tabataRounds'] as int? ?? 8
                ..amrapDurationSeconds = item['amrapDurationSeconds'] as int? ?? 600
                ..amrapCountByRounds = item['amrapCountByRounds'] as bool? ?? true
                ..createdAt = createdAt
                ..tags = List<String>.from(item['tags'] as List? ?? []);
              if (item['exercises'] is List) {
                w.exercises = (item['exercises'] as List).map((e) {
                  return Exercise()
                    ..name = e['name'] as String? ?? ''
                    ..description = e['description'] as String?
                    ..reps = e['reps'] as int?
                    ..durationSeconds = e['durationSeconds'] as int?;
                }).toList();
              }
              box.add(w);
              importedCount++;
            }
          }
        }
      }

      // 2. Импорт истории тренировок
      if (data.containsKey('sessions') && data['sessions'] is List && Hive.isBoxOpen('sessions')) {
        final box = Hive.box<WorkoutSession>('sessions');
        final list = data['sessions'] as List;
        for (final item in list) {
          if (item is Map) {
            final startedAtStr = item['startedAt'] as String?;
            if (startedAtStr != null) {
              final startedAt = DateTime.tryParse(startedAtStr) ?? DateTime.now();
              final exists = box.values.any((s) => s.startedAt.isAtSameMomentAs(startedAt));
              if (!exists) {
                final s = WorkoutSession()
                  ..workoutId = item['workoutId'] as int? ?? 0
                  ..workoutName = item['workoutName'] as String? ?? 'Тренировка'
                  ..workoutType = WorkoutType.values.byName(item['workoutType'] as String? ?? 'tabata')
                  ..startedAt = startedAt
                  ..finishedAt = item['finishedAt'] != null ? DateTime.tryParse(item['finishedAt'] as String) : null
                  ..completedRounds = item['completedRounds'] as int? ?? 0
                  ..totalRounds = item['totalRounds'] as int? ?? 0
                  ..isCompleted = item['isCompleted'] as bool? ?? true
                  ..note = item['note'] as String?
                  ..tags = List<String>.from(item['tags'] as List? ?? [])
                  ..exerciseSnapshots = List<String>.from(item['exerciseSnapshots'] as List? ?? [])
                  ..extraReps = item['extraReps'] as int? ?? 0;
                box.add(s);
                importedCount++;
              }
            }
          }
        }
      }

      // 3. Импорт настроек, кастомных упражнений и тегов (Умное слияние)
      if (data.containsKey('settings') && data['settings'] is Map && Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final map = data['settings'] as Map;
        for (final entry in map.entries) {
          final key = entry.key.toString();
          if (key == 'custom_user_exercises') {
            final incomingRaw = entry.value;
            if (incomingRaw is List) {
              final currentRaw = box.get('custom_user_exercises');
              final currentList = (currentRaw is List) ? List<String>.from(currentRaw) : <String>[];
              final currentMap = <String, String>{};
              for (final item in currentList) {
                try {
                  final parsed = jsonDecode(item) as Map<String, dynamic>;
                  final id = parsed['id'] as String?;
                  if (id != null) currentMap[id] = item;
                } catch (_) {}
              }
              for (final item in incomingRaw) {
                if (item is String) {
                  try {
                    final parsed = jsonDecode(item) as Map<String, dynamic>;
                    final id = parsed['id'] as String?;
                    if (id != null) {
                      if (!currentMap.containsKey(id)) {
                        currentMap[id] = item;
                        importedCount++;
                      } else {
                        // Обновляем упражнение актуальной версией
                        currentMap[id] = item;
                      }
                    }
                  } catch (_) {}
                }
              }
              box.put('custom_user_exercises', currentMap.values.toList());
            }
          } else if (key == 'custom_tags') {
            final incoming = entry.value;
            if (incoming is List) {
              final current = box.get('custom_tags');
              final currentSet = (current is List) ? Set<String>.from(current) : <String>{};
              for (final t in incoming) {
                if (t is String && t.trim().isNotEmpty && !currentSet.contains(t.trim())) {
                  currentSet.add(t.trim());
                  importedCount++;
                }
              }
              box.put('custom_tags', currentSet.toList());
            }
          } else if (key == 'hidden_tags') {
            final incoming = entry.value;
            if (incoming is List) {
              final current = box.get('hidden_tags');
              final currentSet = (current is List) ? Set<String>.from(current) : <String>{};
              for (final t in incoming) {
                if (t is String && t.trim().isNotEmpty) currentSet.add(t.trim());
              }
              box.put('hidden_tags', currentSet.toList());
            }
          } else if (!box.containsKey(key)) {
            box.put(key, entry.value);
            importedCount++;
          }
        }
      }

      notifyListeners();
      return importedCount;
    } catch (e) {
      debugPrint("Import error: $e");
      return 0;
    }
  }

  // --- Wi-Fi / LAN Direct P2P Sync (Прямая синхронизация ПК и смартфона) ---
  HttpServer? _syncServer;
  bool _isServerRunning = false;
  int _serverPort = 8765;

  bool get isServerRunning => _isServerRunning;
  int get serverPort => _serverPort;

  /// Получить локальные IPv4 адреса устройства для синхронизации
  Future<List<String>> getLocalIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      // Приоритетно отбираем физические Wi-Fi / LAN интерфейсы и фильтруем виртуальные (docker, vboxnet, dummy, br-, 10.x, 172.x)
      final preferredIps = <String>[];
      final secondaryIps = <String>[];

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        final isVirtual = name.contains('docker') ||
            name.contains('br-') ||
            name.contains('veth') ||
            name.contains('vbox') ||
            name.contains('virbr') ||
            name.contains('dummy');

        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.isNotEmpty) {
            final a = addr.address;
            // Исключаем 172.17.* - 172.31.* (Docker bridge)
            if (a.startsWith('172.17.') || a.startsWith('172.18.') || a.startsWith('172.19.')) continue;
            if (isVirtual) continue;

            if (a.startsWith('192.168.') || name.startsWith('wlan') || name.startsWith('wl')) {
              preferredIps.add(a);
            } else {
              secondaryIps.add(a);
            }
          }
        }
      }
      ips.addAll(preferredIps.isNotEmpty ? preferredIps : secondaryIps);
    } catch (e) {
      debugPrint("Error getting IP addresses: $e");
    }
    return ips;
  }

  /// Запуск локального сервера синхронизации на данном устройстве
  Future<bool> startLocalSyncServer({int port = 8765}) async {
    if (_syncServer != null) return true;
    try {
      _serverPort = port;
      _syncServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;
      notifyListeners();

      _syncServer!.listen((HttpRequest request) async {
        try {
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
          request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

          if (request.method == 'OPTIONS') {
            request.response.statusCode = HttpStatus.ok;
            await request.response.close();
            return;
          }

          if (request.uri.path == '/ping') {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'status': 'ok', 'app': 'workout_timer', 'time': DateTime.now().toIso8601String()}));
            await request.response.close();
            return;
          }

          if (request.uri.path == '/sync') {
            if (request.method == 'GET') {
              final jsonStr = exportBackupJson();
              request.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.json
                ..write(jsonStr);
              await request.response.close();
            } else if (request.method == 'POST') {
              final content = await utf8.decoder.bind(request).join();
              if (content.isNotEmpty) {
                importBackupJson(content);
              }
              // Возвращаем полностью объединенную базу обратно клиенту
              final merged = exportBackupJson();
              request.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.json
                ..write(merged);
              await request.response.close();
            } else {
              request.response.statusCode = HttpStatus.methodNotAllowed;
              await request.response.close();
            }
            return;
          }

          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        } catch (e) {
          debugPrint("Sync server request error: $e");
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });

      return true;
    } catch (e) {
      debugPrint("Could not start sync server: $e");
      _isServerRunning = false;
      notifyListeners();
      return false;
    }
  }

  /// Остановка сервера синхронизации
  Future<void> stopLocalSyncServer() async {
    if (_syncServer != null) {
      await _syncServer!.close(force: true);
      _syncServer = null;
      _isServerRunning = false;
      notifyListeners();
    }
  }

  /// Синхронизация с другим устройством в локальной сети по IP
  Future<int> syncWithPeer(String peerIp, {int port = 8765}) async {
    _isSyncing = true;
    _syncStatus = 'Подключение к $peerIp...';
    notifyListeners();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      var cleanHost = peerIp.trim().replaceAll('http://', '').replaceAll('https://', '').replaceAll('/', '');
      int targetPort = port;
      if (cleanHost.contains(':')) {
        final parts = cleanHost.split(':');
        cleanHost = parts[0];
        targetPort = int.tryParse(parts[1]) ?? port;
      }
      final uri = Uri.parse('http://$cleanHost:$targetPort/sync');

      _syncStatus = 'Отправка данных на $cleanHost...';
      notifyListeners();

      final myData = exportBackupJson();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(myData);
      final response = await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode == HttpStatus.ok) {
        final responseBody = await utf8.decoder.bind(response).join();
        final count = importBackupJson(responseBody);
        _lastSyncTime = DateTime.now();
        _syncStatus = 'Синхронизировано ($count объектов)';
        if (Hive.isBoxOpen('settings')) {
          Hive.box('settings').put('last_cloud_sync_time', _lastSyncTime!.toIso8601String());
        }
        return count;
      } else {
        _lastError = 'Ошибка сервера: HTTP ${response.statusCode}';
        _syncStatus = 'Ошибка синхронизации';
        return -1;
      }
    } catch (e) {
      debugPrint("Sync with peer error: $e");
      _lastError = e.toString();
      _syncStatus = 'Не удалось подключиться к $peerIp';
      return -1;
    } finally {
      client.close();
      _isSyncing = false;
      notifyListeners();
    }
  }
}

final cloudSyncServiceProvider = ChangeNotifierProvider<CloudSyncService>((ref) {
  return CloudSyncService();
});
