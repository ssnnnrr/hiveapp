import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  List<TaskResponse> _tasks = [];
  bool _isLoading = false;

  List<TaskResponse> get tasks => _tasks;
  bool get isLoading => _isLoading;

  void clearData() {
    _tasks = [];
    _isLoading = false;
    notifyListeners();
  }

  // Загрузка задач для конкретной цели
  Future<void> loadTasks(int goalId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Используем правильный метод из TaskService
      _tasks = await _taskService.getTasksForGoal(goalId);
      notifyListeners();
    } catch (e) {
      debugPrint("TaskProvider Error (loadTasks): $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Оптимистичное обновление статуса задачи
  Future<void> updateTaskStatus(int taskId, String newStatus, String? comment) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    String? oldStatus;
    
    // Оптимистично обновляем UI
    if (index != -1) {
      oldStatus = _tasks[index].status;
      _tasks[index] = _tasks[index].copyWith(
        status: newStatus,
        studentComment: comment,
      );
      notifyListeners();
    }
    
    // Отправляем изменения на сервер
    bool success = await _taskService.updateTaskStatus(taskId, newStatus, comment);
    
    // Откатываем изменения в случае ошибки
    if (!success && index != -1 && oldStatus != null) {
      _tasks[index] = _tasks[index].copyWith(status: oldStatus);
      notifyListeners();
    }
  }

  // Создание новой задачи
  Future<void> createTask(
    int goalId, 
    String title, 
    DateTime dueDate, 
    Function(double) onProgressUpdate
  ) async {
    bool success = await _taskService.createTask(
      goalId: goalId,
      title: title,
      dueDate: dueDate,
    );
    
    if (success) {
      await loadTasks(goalId);
    }
  }

  // Обновление задачи (название и дата)
  Future<void> updateTask({
    required int taskId,
    required int goalId,
    required String newTitle,
    required DateTime newDate,
  }) async {
    bool success = await _taskService.updateTask(
      taskId: taskId,
      goalId: goalId,
      title: newTitle,
      dueDate: newDate,
    );
    
    if (success) {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          title: newTitle,
          dueDate: newDate,
        );
        notifyListeners();
      }
    }
  }

  // Отправка комментария к задаче
  Future<void> submitTask({
    required int taskId,
    required int goalId,
    required String resultComment,
  }) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      // Обновляем статус и комментарий
      await updateTaskStatus(taskId, task.status, resultComment);
    }
  }

  // Удаление задачи
  Future<void> deleteTask(int taskId, int goalId) async {
    bool success = await _taskService.deleteTask(taskId);
    if (success) {
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    }
  }

  // Получение прогресса по задачам
  double getProgress() {
    if (_tasks.isEmpty) return 0.0;
    final doneTasks = _tasks.where((t) => t.status == "Done").length;
    return (doneTasks / _tasks.length) * 100;
  }

  // Получение задачи по ID
  TaskResponse? getTaskById(int taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (e) {
      return null;
    }
  }

  // Фильтрация задач по статусу
  List<TaskResponse> getTasksByStatus(String status) {
    return _tasks.where((t) => t.status == status).toList();
  }

  // Получение выполненных задач
  List<TaskResponse> get completedTasks => getTasksByStatus("Done");
  
  // Получение активных задач
  List<TaskResponse> get activeTasks => getTasksByStatus("ToDo");

  // Проверка, все ли задачи выполнены
  bool get allTasksCompleted => _tasks.isNotEmpty && _tasks.every((t) => t.status == "Done");

  // Сортировка задач по дате
  void sortTasksByDate() {
    _tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    notifyListeners();
  }

  // Сортировка задач по статусу (невыполненные первыми)
  void sortTasksByStatus() {
    _tasks.sort((a, b) {
      if (a.status == "ToDo" && b.status == "Done") return -1;
      if (a.status == "Done" && b.status == "ToDo") return 1;
      return 0;
    });
    notifyListeners();
  }

  // Обновление комментария студента
  Future<void> updateStudentComment(int taskId, String comment) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(studentComment: comment);
      notifyListeners();
      
      // Отправляем на сервер
      await _taskService.updateTaskStatus(
        taskId, 
        _tasks[index].status, 
        comment
      );
    }
  }

  // Обновление комментария учителя
  Future<void> updateTeacherComment(int taskId, String comment) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(teacherComment: comment);
      notifyListeners();
      
      // Отправляем на сервер (если есть соответствующий метод)
      await _taskService.updateTeacherComment(taskId, comment);
    }
  }

  // Массовое обновление статусов задач
  Future<void> updateMultipleTaskStatuses(
    List<int> taskIds, 
    String newStatus
  ) async {
    // Оптимистичное обновление
    for (var id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(status: newStatus);
      }
    }
    notifyListeners();
    
    // Отправляем на сервер
    for (var id in taskIds) {
      await _taskService.updateTaskStatus(id, newStatus, null);
    }
  }

  // Получение статистики по задачам
  Map<String, dynamic> getTaskStatistics() {
    return {
      'total': _tasks.length,
      'completed': completedTasks.length,
      'active': activeTasks.length,
      'progress': getProgress(),
      'allCompleted': allTasksCompleted,
    };
  }

  // Сброс всех задач (для выхода из аккаунта)
  void resetTasks() {
    _tasks.clear();
    _isLoading = false;
    notifyListeners();
  }
}