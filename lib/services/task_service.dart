import 'package:flutter/material.dart';
import '../models/all_models.dart';
import 'api_client.dart';

class TaskService {
  final ApiClient _api = ApiClient();

  // Получение задач для конкретной цели
  Future<List<TaskResponse>> getTasksForGoal(int goalId) async {
    try {
      final response = await _api.dio.get("/Tasks/goal/$goalId");
      return (response.data as List)
          .map((e) => TaskResponse.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint("TaskService Error (getTasksForGoal): $e");
      return [];
    }
  }

  // Создание задачи
  Future<bool> createTask({
    required int goalId,
    required String title,
    required DateTime dueDate,
  }) async {
    try {
      final response = await _api.dio.post("/Tasks", data: {
        "goalId": goalId,
        "title": title,
        "dueDate": dueDate.toIso8601String(),
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("TaskService Error (createTask): $e");
      return false;
    }
  }

  // Обновление задачи
  Future<bool> updateTask({
    required int taskId,
    required int goalId,
    required String title,
    required DateTime dueDate,
  }) async {
    try {
      final response = await _api.dio.put("/Tasks/$taskId", data: {
        "goalId": goalId,
        "title": title,
        "dueDate": dueDate.toIso8601String(),
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("TaskService Error (updateTask): $e");
      return false;
    }
  }

  // Обновление статуса задачи - ИСПОЛЬЗУЕМ PATCH вместо PUT
  Future<bool> updateTaskStatus(
    int taskId, 
    String status, 
    String? comment
  ) async {
    try {
      // Пробуем PATCH запрос
      final response = await _api.dio.patch("/Tasks/$taskId/status", data: {
        "status": status,
        "studentComment": comment,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("TaskService Error (updateTaskStatus): $e");
      // Пробуем альтернативный эндпоинт
      try {
        final response = await _api.dio.post("/Tasks/$taskId/status", data: {
          "status": status,
          "studentComment": comment,
        });
        return response.statusCode == 200;
      } catch (e2) {
        debugPrint("TaskService Error (updateTaskStatus alt): $e2");
        return false;
      }
    }
  }

  // Удаление задачи
  Future<bool> deleteTask(int taskId) async {
    try {
      final response = await _api.dio.delete("/Tasks/$taskId");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("TaskService Error (deleteTask): $e");
      return false;
    }
  }

  // Обновление комментария учителя
  Future<bool> updateTeacherComment(int taskId, String comment) async {
    try {
      final response = await _api.dio.patch("/Tasks/$taskId/teacher-comment", data: {
        "teacherComment": comment,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("TaskService Error (updateTeacherComment): $e");
      return false;
    }
  }
}