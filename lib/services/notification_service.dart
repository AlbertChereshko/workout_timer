import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool isNotificationsEnabled = false;

  static const String _timerChannelId = 'workout_timer_phases';
  static const String _timerChannelName = 'Фазы тренировки';
  static const String _timerChannelDescription = 'Оповещения о смене интервалов: работа, отдых, раунд, финиш';

  static const String _remindersChannelId = 'workout_reminders';
  static const String _remindersChannelName = 'Напоминания о тренировках';
  static const String _remindersChannelDescription = 'Регулярные напоминания и мотивация к тренировкам';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        isNotificationsEnabled = box.get('notifications_enabled', defaultValue: false) as bool;
      }

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const LinuxInitializationSettings linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint("Notification tapped: ${response.payload}");
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        await _notificationsPlugin.cancelAll();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint("NotificationService init error: $e");
    }
  }

  void setNotificationsEnabled(bool enabled) {
    isNotificationsEnabled = enabled;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('notifications_enabled', enabled);
      }
    } catch (_) {}
  }

  /// Уведомление о смене фазы интервала (Работа, Отдых, Раунд, Финиш)
  Future<void> showPhaseTransitionNotification({
    required String title,
    required String body,
    int notificationId = 101,
  }) async {
    if (!isNotificationsEnabled) return;
    if (!_isInitialized) await init();

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _timerChannelId,
        _timerChannelName,
        channelDescription: _timerChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        category: AndroidNotificationCategory.workout,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        linux: LinuxNotificationDetails(),
      );

      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: platformDetails,
      );
    } catch (e) {
      debugPrint("NotificationService show error: $e");
    }
  }

  /// Мотивационное напоминание о тренировке
  Future<void> showWorkoutPrompt({
    required String title,
    required String body,
    int notificationId = 201,
  }) async {
    if (!isNotificationsEnabled) return;
    if (!_isInitialized) await init();

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _remindersChannelId,
        _remindersChannelName,
        channelDescription: _remindersChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      );

      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: platformDetails,
      );
    } catch (e) {
      debugPrint("NotificationService prompt error: $e");
    }
  }

  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
