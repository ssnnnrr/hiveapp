import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'dart:io' show Platform; // Используем аккуратно
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
     if (kIsWeb) return;
    tz_data.initializeTimeZones();
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // ИСПРАВЛЕНО: Добавлен обязательный именованный параметр 'settings'
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
  }

  static Future<void> showMissedAlert(String title) async {
    // ИСПРАВЛЕНО: В v21 параметры id, title, body и notificationDetails ДОЛЖНЫ быть именованными
    await _notifications.show(
      id: 999,
      title: "Пропущенные задачи!",
      body: "Вы не выполнили: $title. Нажмите, чтобы перенести.",
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hive_missed', 'Пропуски',
          importance: Importance.high,
          priority: Priority.high,
          color: Colors.red,
        ),
      ),
    );
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return; 
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    }
  }

  static Future<void> scheduleNotification({required int id, required String title, required DateTime scheduledDate}) async {
    final reminderTime = scheduledDate.subtract(const Duration(minutes: 30));
    if (reminderTime.isBefore(DateTime.now())) return;

    // ИСПРАВЛЕНО: Все параметры стали именованными (id, title, body, scheduledDate, notificationDetails)
    await _notifications.zonedSchedule(
      id: id,
      title: "Напоминание",
      body: "Событие '$title' через 30 минут!",
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hive_ch', 
          'Hive Channel',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Параметр uiLocalNotificationDateInterpretation удален в v21, он больше не нужен
    );
  }

  static Future<void> cancelNotification(int id) async {
    // ИСПРАВЛЕНО: Параметр id стал именованным
    await _notifications.cancel(id: id);
  }
}