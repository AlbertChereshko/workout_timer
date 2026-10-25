import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/database.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Адаптация под современные AMOLED-экраны и управление жестами (OnePlus 15)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Инициализируем локальную базу данных (Hive)
  await initDatabase();

  // Инициализируем аудио сервис с поддержкой микширования (не останавливает Spotify)
  await AudioService().init();
  await NotificationService().init();

  // Инициализируем Firebase на поддерживаемых мобильных платформах (Android/iOS)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint("Firebase init error: $e");
    }
  }

  // Восстанавливаем авторизацию пользователя и облачную/локальную синхронизацию
  await AuthService().init();
  await CloudSyncService().init();
  try {
    await CloudSyncService().startLocalSyncServer();
  } catch (_) {}
  
  runApp(const ProviderScope(child: WorkoutTimerApp()));
}
