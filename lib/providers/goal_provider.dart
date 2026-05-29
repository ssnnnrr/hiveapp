import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_app/services/api_client.dart';
import '../models/all_models.dart';
import '../services/goal_service.dart';

class GoalProvider extends ChangeNotifier {
  final GoalService _goalService = GoalService();
  List<GoalResponse> _goals = [];
  bool _isLoading = false;
  final ApiClient _api = ApiClient(); 

  List<GoalResponse> get goals => _goals;
  bool get isLoading => _isLoading;

  /// Очистка всех данных
  void clearData() {
    _goals = [];
    _isLoading = false;
    notifyListeners();
  }


  Future<bool> addFileMaterial(int goalId, String title, int? taskId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        String filePath = result.files.single.path!;
        FormData data = FormData.fromMap({
          "goalId": goalId,
          "title": title,
          "type": "File",
          "taskId": taskId,
          "file": await MultipartFile.fromFile(filePath, filename: result.files.single.name)
        });
        await _api.dio.post("/Goals/materials/upload", data: data);
        await loadGoals(_goals.first.userId);
        return true;
      }
    } catch (e) { return false; }
    return false;
  }

  /// Загрузка списка целей (Синхронизировано с Service)
  Future<void> loadGoals(int userId) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());
    try {
      final fetchedGoals = await _goalService.getUserGoals(userId);
      _goals = fetchedGoals;
    } catch (e) {
      debugPrint("DEBUG [GoalProvider] ERROR: $e");
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  /// Создание маршрута
  Future<bool> addGoalWithSteps({
    required String title,
    required String why,
    required String result,
    required DateTime date,
    required String goalType,
    required int uid,
    required List<TaskDraftResponse> steps,
    bool isSolo = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    bool success = await _goalService.createSmartGoal(
      title: title,
      why: why,
      result: result,
      date: date,
      goalType: goalType,
      steps: steps,
      isSolo: isSolo,
    );

    if (success) {
      await loadGoals(uid);
    }
    
    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Добавление материала (исправлено)
  Future<bool> addMaterialWithTask(int goalId, String title, String content, String type, int? taskId) async {
    bool success = await _goalService.addMaterial(
      goalId: goalId,
      title: title,
      content: content,
      type: type,
      taskId: taskId,
    );

    if (success) {
      final goal = _goals.firstWhere((g) => g.id == goalId);
      await loadGoals(goal.userId);
    }
    return success;
  }

  /// Удаление материала
  Future<bool> deleteMaterial(int goalId, int materialId) async {
    bool success = await _goalService.deleteMaterial(materialId);
    if (success) {
      int idx = _goals.indexWhere((g) => g.id == goalId);
      if (idx != -1) {
        _goals[idx].materials.removeWhere((m) => m.id == materialId);
        notifyListeners();
      }
    }
    return success;
  }

  

  /// Обновление параметров цели
  Future<void> updateGoal({required int goalId, required String title, required bool isSolo}) async {
    try {
      bool success = await _goalService.updateGoal(goalId, title, isSolo);
      if (success && _goals.isNotEmpty) {
        await loadGoals(_goals.first.userId);
      }
    } catch (e) {
      debugPrint("GoalProvider Error (updateGoal): $e");
    }
  }

  /// Удаление маршрута
  Future<void> removeGoal(int goalId, int userId) async {
    bool success = await _goalService.deleteGoal(goalId);
    if (success) {
      _goals.removeWhere((g) => g.id == goalId);
      notifyListeners();
    }
  }


  /// Ответ на приглашение
  Future<bool> respondToGoalInvite(int goalId, bool accept, int userId) async {
    bool success = await _goalService.respondToInvite(goalId, accept);
    if (success) {
      await loadGoals(userId);
    }
    return success;
  }


  // В GoalProvider.dart

// lib/providers/goal_provider.dart

  Future<void> toggleGoalSoloStatus(int goalId, bool isSolo) async {
    try {
      final response = await _api.dio.patch(
        "/Goals/$goalId/toggle-solo", 
        data: isSolo, // Шлем просто true/false
        options: Options(contentType: 'application/json'), // Это критично для .NET
      );
      
      if (response.statusCode == 200) {
        int idx = _goals.indexWhere((g) => g.id == goalId);
        if (idx != -1) {
          _goals[idx] = _goals[idx].copyWith(isSolo: isSolo);
          notifyListeners();
        }
      }
    } catch (e) {
      print("Ошибка toggle: $e");
    }
  }

  // providers/goal_provider.dart

// lib/providers/goal_provider.dart

void syncTaskInGoal(int goalId, TaskResponse updatedTask) {
  // 1. Ищем индекс цели в списке _goals
  final gIdx = _goals.indexWhere((g) => g.id == goalId);
  
  if (gIdx != -1) {
    // 2. Получаем список задач этой цели
    final List<TaskResponse> currentGoalTasks = List.from(_goals[gIdx].tasks);
    
    // 3. Ищем индекс конкретной задачи в этом списке
    final tIdx = currentGoalTasks.indexWhere((t) => t.id == updatedTask.id);
    
    if (tIdx != -1) {
      debugPrint("DEBUG [GoalProvider]: Обновляю задачу ${updatedTask.id} в цели $goalId");
      
      // 4. Заменяем задачу на обновленную
      currentGoalTasks[tIdx] = updatedTask;
      
      // 5. Обновляем саму цель в списке через copyWith (чтобы сработал trigger в UI)
      _goals[gIdx] = _goals[gIdx].copyWith(tasks: currentGoalTasks);
      
      // Используем микрозадачу, чтобы избежать конфликтов при отрисовке
      Future.microtask(() => notifyListeners());
    }
  }
}

  Future<void> invitePartner(int goalId, int partnerId, int creatorId) async {
    try {
      final response = await _api.dio.post("/Goals/$goalId/invite/$partnerId");
      if (response.statusCode == 200) {
        // После приглашения обновляем данные цели, чтобы кнопка стала "В ожидании"
        loadGoals(creatorId); 
      }
    } catch (e) {
      debugPrint("Ошибка инвайта: $e");
    }
  }

// Вызов существующего метода удаления/форка для партнеров
Future<void> makeGoalPersonal(int goalId) async {
  try {
    final response = await _api.dio.post("/Goals/$goalId/make-solo");
    if (response.statusCode == 200) {
      // После этого бэкенд отцепил всех партнеров, удаляем их локально
      int idx = _goals.indexWhere((g) => g.id == goalId);
      if (idx != -1) {
        _goals[idx] = _goals[idx].copyWith(
          isSolo: true,
          collaborators: [] // Все партнеры исчезают
        );
        notifyListeners();
      }
    }
  } catch (e) {
    print(e);
  }
}

  /// Синхронизация прогресса (Для GoalsScreen)
  void syncProgress(int goalId, double newProgress) {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      debugPrint("DEBUG [GoalProvider]: Синхронизирую прогресс для $goalId -> $newProgress%");
      _goals[index] = _goals[index].copyWith(progress: newProgress);
      notifyListeners();
    }
  }

  /// Работа с AI черновиками
  Future<List<TaskDraftResponse>> getDraftSteps(String title, String why, String result, DateTime date) async {
    return await _goalService.generateDraft(title, why, result, date);
  }

  void clearGoals() {
    _goals = [];
    notifyListeners();
  }
}