import 'package:flutter/material.dart';
import '../models/all_models.dart';
import 'api_client.dart';

class GoalService {
  final ApiClient _api = ApiClient();

  // Получение целей пользователя (Метод переименован для соответствия Провайдеру)
  Future<List<GoalResponse>> getUserGoals(int userId) async {
    try {
      final response = await _api.dio.get("/Goals/user/$userId");
      return (response.data as List).map((e) => GoalResponse.fromJson(e)).toList();
    } catch (e) {
      debugPrint("GoalService Error (getUserGoals): $e");
      return [];
    }
  }

  // Добавление материала (база знаний)
  Future<bool> addMaterial({
    required int goalId,
    required String title,
    required String content,
    required String type,
    int? taskId,
  }) async {
    try {
      final response = await _api.dio.post("/Goals/materials", data: {
        "goalId": goalId,
        "title": title,
        "content": content,
        "type": type,
        "taskId": taskId,
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("GoalService Error (addMaterial): $e");
      return false;
    }
  }

  // Обновление параметров цели
  Future<bool> updateGoal(int id, String title, bool isSolo) async {
    try {
      final response = await _api.dio.put("/Goals/$id", data: {
        "title": title,
        "isSolo": isSolo
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("GoalService Error (updateGoal): $e");
      return false;
    }
  }

  // Перевод цели в личный режим (Метод переименован для соответствия Провайдеру)
  Future<bool> convertToSolo(int goalId) async {
    try {
      final response = await _api.dio.post("/Goals/$goalId/make-solo");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("GoalService Error (convertToSolo): $e");
      return false;
    }
  }

  // Генерация черновика через AI
  Future<List<TaskDraftResponse>> generateDraft(String title, String why, String result, DateTime date) async {
    try {
      final response = await _api.dio.post("/Goals/generate-draft", data: {
        "title": title,
        "why": why,
        "measurableResult": result,
        "targetDate": date.toIso8601String(),
      });
      return (response.data as List).map((e) => TaskDraftResponse.fromJson(e)).toList();
    } catch (e) {
      debugPrint("GoalService Error (generateDraft): $e");
      return [];
    }
  }

  // Ответ на приглашение
  Future<bool> respondToInvite(int goalId, bool accept) async {
    try {
      final response = await _api.dio.post("/Goals/invitation/$goalId/respond?accept=$accept");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Создание SMART-цели с шагами
  Future<bool> createSmartGoal({
    required String title,
    required String why,
    required String result,
    required DateTime date,
    required String goalType,
    required List<TaskDraftResponse> steps,
    bool isSolo = true,
  }) async {
    try {
      final response = await _api.dio.post("/Goals", data: {
        "title": title,
        "description": why,
        "measurableResult": result,
        "targetDate": date.toIso8601String(),
        "isSolo": isSolo,
        "goalType": goalType,
        "steps": steps.map((s) => s.toJson()).toList()
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("GoalService Error (createSmartGoal): $e");
      return false;
    }
  }

  // Удаление материала
  Future<bool> deleteMaterial(int materialId) async {
    try {
      final response = await _api.dio.delete("/Goals/materials/$materialId");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("GoalService Error (deleteMaterial): $e");
      return false;
    }
  }

  // Приглашение партнера
  Future<bool> invitePartner(int goalId, int partnerId) async {
    try {
      final response = await _api.dio.post("/Goals/$goalId/invite/$partnerId");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Удаление цели
  Future<bool> deleteGoal(int id) async {
    try {
      final response = await _api.dio.delete("/Goals/$id");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}