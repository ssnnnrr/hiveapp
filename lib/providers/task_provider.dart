import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';
import 'goal_provider.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final ApiClient _api = ApiClient();
  
  List<TaskResponse> _tasks = [];
  bool _isLoading = false;

  List<TaskResponse> get tasks => _tasks;
  bool get isLoading => _isLoading;

  // Безопасное уведомление слушателей
  void _safeNotify() {
    Future.microtask(() => notifyListeners());
  }

  Future<void> loadAllTasks() async {
    _isLoading = true;
    _safeNotify();
    try {
      final response = await _api.dio.get("/Tasks/my-all");
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        _tasks = data.map((json) => TaskResponse.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("TaskProvider Error: $e");
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  // *** ИСПРАВЛЕННЫЙ МЕТОД: Принимает GoalProvider как параметр ***
  void cleanupOrphanedTasks(GoalProvider goalProv) {
    try {
      if (goalProv.goals.isNotEmpty) {
        final activeGoalIds = goalProv.goals.map((g) => g.id).toSet();
        
        final beforeCount = _tasks.length;
        _tasks.removeWhere((t) => !activeGoalIds.contains(t.goalId));
        final afterCount = _tasks.length;
        
        if (beforeCount != afterCount) {
          debugPrint("TaskProvider: Removed ${beforeCount - afterCount} orphaned tasks");
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("TaskProvider cleanup error: $e");
    }
  }

  void removeTasksForGoal(int goalId) {
    final beforeCount = _tasks.length;
    _tasks.removeWhere((t) => t.goalId == goalId);
    final afterCount = _tasks.length;
    
    if (beforeCount != afterCount) {
      debugPrint("TaskProvider: Removed ${beforeCount - afterCount} tasks for goal $goalId");
      notifyListeners();
    }
  }

  Future<void> loadTasks(int goalId) async {
    _isLoading = true;
    _safeNotify();
    try {
      final response = await _api.dio.get("/Tasks/goal/$goalId");
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List;
        final newTasks = data.map((json) => TaskResponse.fromJson(json)).toList();
        
        // 1. Удаляем из общего кэша старые задачи ТОЛЬКО этой цели
        _tasks.removeWhere((t) => t.goalId == goalId);
        // 2. Добавляем свежие
        _tasks.addAll(newTasks);
      }
    } catch (e) {
      debugPrint("TaskProvider Error: $e");
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> updateTaskDate(int taskId, DateTime newDate, GoalProvider goalProv) async {
    final safeDate = _toSafeUtc(newDate);
    try {
      final response = await _api.dio.patch("/Tasks/$taskId/reschedule", data: {
        "newDate": safeDate.toIso8601String()
      });

      if (response.statusCode == 200) {
        int idx = _tasks.indexWhere((t) => t.id == taskId);
        if (idx != -1) {
          _tasks[idx] = _tasks[idx].copyWith(
            dueDate: DateTime(newDate.year, newDate.month, newDate.day)
          );
          goalProv.syncTaskInGoal(_tasks[idx].goalId, _tasks[idx]);
          _safeNotify();
          return true;
        }
      }
    } catch (e) { 
      debugPrint(e.toString()); 
    }
    return false;
  }

  Future<void> updateTask({
    required int taskId, 
    required int goalId, 
    required String newTitle, 
    required DateTime newDate,
    required GoalProvider goalProv,
  }) async {
    try {
      await _api.dio.put("/Tasks/$taskId", data: {"title": newTitle});
      bool ok = await updateTaskDate(taskId, newDate, goalProv);
      
      if (ok) {
        int idx = _tasks.indexWhere((t) => t.id == taskId);
        if (idx != -1) {
          _tasks[idx] = _tasks[idx].copyWith(title: newTitle, dueDate: newDate);
          _safeNotify();
        }
      }
    } catch (e) {
      debugPrint("UpdateTask Error: $e");
    }
  }

  Future<void> updateTaskStatus({
    required int taskId,
    required String newStatus,
    required String? comment,
    required String userName,
    required String? userAvatar,
    required GoalProvider goalProvider, 
  }) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final oldTask = _tasks[index];
    
    List<UserMinimalDto> updatedCompletions = List<UserMinimalDto>.from(oldTask.completions);
    if (newStatus == "Done") {
      if (!updatedCompletions.any((c) => c.username == userName)) {
        updatedCompletions.add(UserMinimalDto(username: userName, avatarUrl: userAvatar));
      }
    } else {
      updatedCompletions.removeWhere((c) => c.username == userName);
    }

    _tasks[index] = oldTask.copyWith(status: newStatus, completions: updatedCompletions);
    
    Future.microtask(() {
      goalProvider.syncProgress(oldTask.goalId, getProgress(userName));
      goalProvider.syncTaskInGoal(oldTask.goalId, _tasks[index]);
    });
    
    _safeNotify();
    await _taskService.updateTaskStatus(taskId, newStatus, comment);
  }

double getProgress(String myUsername, {int? goalId}) {
  // Фильтруем задачи: если goalId передан, берем только задачи этой цели
  List<TaskResponse> targetTasks = goalId != null 
      ? _tasks.where((t) => t.goalId == goalId).toList() 
      : _tasks;

  if (targetTasks.isEmpty) return 0.0;
  
  int doneCount = targetTasks
      .where((t) => t.completions.any((c) => c.username == myUsername))
      .length;
  return (doneCount / targetTasks.length) * 100;
}

  void clearData() {
    _tasks = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createTask(int goalId, String title, DateTime dueDate) async {
    bool success = await _taskService.createTask(goalId: goalId, title: title, dueDate: dueDate);
    if (success) await loadAllTasks(); 
  }

Future<void> deleteTask(int taskId, int goalId, GoalProvider goalProv) async {
  // 1. Сначала удаляем из глобального кэша задач
  _tasks.removeWhere((t) => t.id == taskId);
  
  // 2. СРАЗУ удаляем из внутреннего списка задач цели в GoalProvider
  goalProv.removeTaskFromGoal(goalId, taskId);
  
  // 3. Уведомляем UI (теперь графики и списки увидят изменения одновременно)
  notifyListeners();

  try {
    // 4. Отправляем на сервер
    await _api.dio.delete("/Tasks/$taskId");
  } catch (e) {
    debugPrint("Ошибка удаления на сервере: $e");
    // В случае ошибки возвращаем данные (делаем reload)
    await loadTasks(goalId);
    await goalProv.loadGoals(goalProv.goals.first.userId);
  }
}

    List<TaskResponse> getTasksByGoal(int goalId) {
    return _tasks.where((t) => t.goalId == goalId).toList();
  }

  Future<void> addComment(int taskId, String text) async {
    final newComment = await _taskService.postComment(taskId, text); 
    if (newComment != null) {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final List<TaskCommentDto> updatedComments = List.from(_tasks[index].comments)..add(newComment);
        _tasks[index] = _tasks[index].copyWith(comments: updatedComments);
        _safeNotify();
      }
    }
  }

  DateTime _toSafeUtc(DateTime localDate) {
    return DateTime.utc(localDate.year, localDate.month, localDate.day, 12, 0, 0);
  }

  Future<void> deleteComment(int taskId, int commentId) async {
    bool success = await _taskService.deleteComment(commentId);
    if (success) {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final updatedComments = _tasks[index].comments.where((c) => c.id != commentId).toList();
        _tasks[index] = _tasks[index].copyWith(comments: updatedComments);
        _safeNotify();
      }
    }
  }
}