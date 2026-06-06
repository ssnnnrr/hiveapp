import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

Future<void> loadNotifications() async {
  _notifications = [];
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.dio.get("/Notifications");
      if (response.statusCode == 200) {
        final List fetched = response.data;
        final all = fetched.map((e) => AppNotification.fromJson(e)).toList();
        
        // ДЕДУПЛИКАЦИЯ: Если ID и Тип совпадают — это одно и то же уведомление
        final Map<String, AppNotification> uniqueMap = {};
        for (var n in all) {
          final key = "${n.type}_${n.data}"; 
          if (!uniqueMap.containsKey(key)) {
            uniqueMap[key] = n;
          }
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


  void handleSignalRNotificationDeleted(int noteId) {
    _notifications.removeWhere((n) => n.id == noteId);
    notifyListeners();
  }

  // ЭТАП 6: Мгновенное удаление просрочки из списка (локально)
  void removeOverdueNotification(int itemId, String type) {
    _notifications.removeWhere((n) {
      final int? entityId = int.tryParse(n.data ?? '');
      if (type == "task") return n.type == "TaskOverdue" && entityId == itemId;
      if (type == "event") return n.type == "EventOverdue" && entityId == itemId;
      if (type == "roadmap") return n.type == "RoadmapOverdue" && entityId == itemId;
      return false;
    });
    notifyListeners();
  }

  // Синхронизация всех уведомлений (удаляем те, что уже не просрочены)
  void syncOverdueNotifications({
    required List<TaskResponse> tasks,
    required List<EventResponse> events,
    required List<RoadmapStepDto> roadmapSteps,
  }) {
    final now = DateTime.now();
    _notifications.removeWhere((n) {
      final int? entityId = int.tryParse(n.data ?? '');
      if (entityId == null) return false;

      if (n.type == "TaskOverdue") {
        final t = tasks.where((t) => t.id == entityId).firstOrNull;
        return t == null || t.status == "Done" || !t.dueDate.isBefore(now);
      }
      if (n.type == "EventOverdue") {
        final e = events.where((e) => e.id == entityId).firstOrNull;
        return e == null || e.isCompleted || !e.eventDate.isBefore(now);
      }
      if (n.type == "RoadmapOverdue") {
        final s = roadmapSteps.where((s) => s.id == entityId).firstOrNull;
        return s == null || s.status == "Done" || !s.dueDate.isBefore(now);
      }
      return false;
    });
    notifyListeners();
  }

  Future<void> markAsRead(int id) async {
    await _api.dio.post("/Notifications/$id/read");
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearData() {
    _notifications = [];
    notifyListeners();
  }
}