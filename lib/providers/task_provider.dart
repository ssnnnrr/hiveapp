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

  

  Future<void> loadTasks(int goalId) async {
    if (goalId == 0) return;
    _isLoading = true;
    _safeNotify();
    try {
      final fetchedTasks = await _taskService.getTasksForGoal(goalId);
      _tasks = fetchedTasks;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

// lib/providers/task_provider.dart

// lib/providers/task_provider.dart

Future<bool> updateTaskDate(int taskId, DateTime newDate, GoalProvider goalProv) async {
  // 1. Убираем влияние часового пояса, устанавливая время на ПОЛДЕНЬ (12:00)
  // Это гарантирует, что при любом сдвиге UTC (до +-12 часов) дата останется той же
  final safeDate = DateTime(newDate.year, newDate.month, newDate.day, 12, 0, 0);

  try {
    // Отправляем на сервер строго в формате UTC
    final response = await _api.dio.patch("/Tasks/$taskId/reschedule", data: {
      "newDate": safeDate.toUtc().toIso8601String()
    });

    if (response.statusCode == 200) {
      int idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        // Сохраняем дату в локальном состоянии (тоже как «чистую» дату без времени)
        final updatedTask = _tasks[idx].copyWith(
          dueDate: DateTime(newDate.year, newDate.month, newDate.day)
        );
        _tasks[idx] = updatedTask;
        
        goalProv.syncTaskInGoal(updatedTask.goalId, updatedTask);
        
        _safeNotify();
        return true;
      }
    }
  } catch (e) {
    debugPrint("DEBUG [TaskProvider] Reschedule ERROR: $e");
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

  // Остальные вспомогательные методы
  double getProgress(String myUsername) {
    if (_tasks.isEmpty) return 0.0;
    int doneCount = _tasks.where((t) => t.completions.any((c) => c.username == myUsername)).length;
    return (doneCount / _tasks.length) * 100;
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

  Future<void> deleteTask(int taskId, int goalId) async {
    bool success = await _taskService.deleteTask(taskId);
    if (success) {
      _tasks.removeWhere((t) => t.id == taskId);
      _safeNotify();
    }
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