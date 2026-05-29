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

  // Обновление статуса задачи (выполнено/нет)
  Future<bool> updateTaskStatus(int taskId, String status, String? comment) async {
    try {
      final response = await _api.dio.patch("/Tasks/$taskId/status", data: {
        "Status": status,
        "Comment": comment ?? "",
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("TaskService Error (updateTaskStatus): $e");
      return false;
    }
  }

  // Отправка комментария к задаче
  Future<TaskCommentDto?> postComment(int taskId, String text) async {
    try {
      final response = await _api.dio.post("/Tasks/comments", data: {
        "taskId": taskId,
        "text": text,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return TaskCommentDto.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("TaskService Error (postComment): $e");
    }
    return null;
  }

  // Удаление комментария
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await _api.dio.delete('/Tasks/comments/$commentId'); 
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("TaskService Error (deleteComment): $e");
      return false;
    }
  }

  // Создание новой задачи (этапа)
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
}