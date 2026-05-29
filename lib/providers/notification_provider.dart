import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<AppNotification> get notifications => _notifications;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.dio.get("/Notifications");
      if (response.statusCode == 200) {
        final List fetched = response.data;
        final all = fetched.map((e) => AppNotification.fromJson(e)).toList();
        
        // КЛИЕНТСКАЯ ДЕДУПЛИКАЦИЯ: Убираем повторы
        final Map<String, AppNotification> uniqueMap = {};
        for (var n in all) {
          uniqueMap["${n.type}_${n.title}_${n.message}"] = n;
        }
        
        _notifications = uniqueMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint("Ошибка загрузки уведомлений: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _api.dio.post("/Notifications/$id/read");
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Ошибка markAsRead: $e");
    }
  }

  // Локальное удаление уведомления (без API запроса)
  void removeNotification(int id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  // Локальное удаление нескольких уведомлений
  void removeNotifications(List<int> ids) {
    _notifications.removeWhere((n) => ids.contains(n.id));
    notifyListeners();
  }


  // В NotificationProvider (lib/providers/notification_provider.dart)

// В класс NotificationProvider добавим:
void removeOverdueNotification(int itemId, String type) {
  // Ищем уведомление по taskId или roadmapStepId
  _notifications.removeWhere((n) => 
    (type == "task" && n.taskId == itemId) || 
    (type == "roadmap" && n.roadmapStepId == itemId)
  );
  notifyListeners();
}

  Future<void> markAllAsRead() async {
    try {
      await _api.dio.post("/Notifications/mark-read");
      _notifications.clear();
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}