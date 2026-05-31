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
        
        // УЛУЧШЕННАЯ ДЕДУПЛИКАЦИЯ: фильтруем по заголовку, сообщению и ID задачи
        final Map<String, AppNotification> uniqueMap = {};
        for (var n in all) {
          // Создаем уникальный ключ на основе контента
          final contentKey = "${n.title}_${n.message}_${n.taskId}_${n.roadmapStepId}";
          
          // Если уведомление с таким смыслом уже есть, оставляем более новое (по id или дате)
          if (!uniqueMap.containsKey(contentKey)) {
            uniqueMap[contentKey] = n;
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
void syncOverdueNotifications({
  required List<TaskResponse> tasks,
  required List<EventResponse> events,
  required List<RoadmapStepDto> roadmapSteps,
}) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  bool changed = false;

  _notifications.removeWhere((n) {
    final int? entityId = int.tryParse(n.data ?? '');
    if (entityId == null) return false;

    // Сравнение для Шагов к цели
    if (n.type == "TaskOverdue") {
      final task = tasks.where((t) => t.id == entityId).firstOrNull;
      if (task != null) {
        bool isDone = task.status == "Done" || task.completions.isNotEmpty;
        bool isNotOverdue = !task.dueDate.toLocal().isBefore(todayStart);
        if (isDone || isNotOverdue) return true;
      } else { return true; }
    }

    // Сравнение для Событий (минута в минуту)
    if (n.type == "EventOverdue") {
      final event = events.where((e) => e.id == entityId).firstOrNull;
      if (event != null) {
        bool isNotOverdue = !event.eventDate.toLocal().isBefore(now);
        if (event.isCompleted || isNotOverdue) return true;
      } else { return true; }
    }

    // Сравнение для Заданий чата
    if (n.type == "RoadmapOverdue") {
      final step = roadmapSteps.where((s) => s.id == entityId).firstOrNull;
      if (step != null) {
        bool isHandled = step.status == "Done" || step.status == "UnderReview";
        bool isNotOverdue = !step.dueDate.toLocal().isBefore(todayStart);
        if (isHandled || isNotOverdue) return true;
      } else { return true; }
    }

    return false;
  });

  notifyListeners();
}


void clearData() {
  _notifications = [];
  _isLoading = false;
  notifyListeners();
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