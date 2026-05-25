import 'package:flutter/material.dart';
import 'package:hive_app/models/all_models.dart';
import 'package:hive_app/services/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;


 Future<void> markAsRead(int id) async {
    try {
      await _api.dio.post("/Notifications/$id/read"); // Путь зависит от вашего API
      _notifications.removeWhere((n) => n.id == id); // Сразу удаляем из списка
      notifyListeners();
    } catch (e) {
      debugPrint("Ошибка прочтения уведомления: $e");
    }
  }

   Future<void> markAllAsRead() async {
    try {
      await _api.dio.post("/Notifications/mark-read");
      _notifications.clear(); // Удаляем все, так как они прочитаны
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> loadNotifications() async {
    try {
      final response = await _api.dio.get("/Notifications");
      _notifications = (response.data as List).map((e) => AppNotification.fromJson(e)).toList();
      notifyListeners();
    } catch (e) { print(e); }
  }

}