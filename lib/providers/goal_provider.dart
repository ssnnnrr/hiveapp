import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/goal_service.dart';

class GoalProvider extends ChangeNotifier {
  final GoalService _goalService = GoalService();
  List<GoalResponse> _goals = [];
  bool _isLoading = false;

  List<GoalResponse> get goals => _goals;
  bool get isLoading => _isLoading;

  void clearData() {
    _goals = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadGoals(int userId) async {
    _isLoading = true;
    try {
      _goals = await _goalService.getGoals(userId);
      notifyListeners();
    } catch (e) {
      debugPrint("GoalProvider Error (loadGoals): $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- СОЗДАНИЕ ЦЕЛИ (С ТИПОМ) ---
  Future<bool> addGoalWithSteps({
    required String title,
    required String why,
    required String result,
    required DateTime date,
    required String goalType, // Social, Exchange, Group
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
    if (success) await loadGoals(uid);
    _isLoading = false;
    notifyListeners();
    return success;
  }

  // --- УПРАВЛЕНИЕ МАТЕРИАЛАМИ (БАЗА ЗНАНИЙ) ---
  Future<bool> addMaterial(int goalId, String title, String content, String type) async {
    bool success = await _goalService.addMaterial(
      goalId: goalId,
      title: title,
      content: content,
      type: type,
    );
    if (success) {
      // Обновляем локальный список целей, чтобы сразу увидеть материал
      int idx = _goals.indexWhere((g) => g.id == goalId);
      if (idx != -1) {
        await loadGoals(_goals[idx].userId); 
      }
    }
    return success;
  }

Future<void> updateGoal({required int goalId, required String title, required bool isSolo}) async {
  try {
    await _goalService.updateGoal(goalId, title, isSolo);
    // Перезагружаем цели
    if (_goals.isNotEmpty) {
      await loadGoals(_goals.first.userId);
    }
    notifyListeners();
  } catch (e) {
    debugPrint("GoalProvider Error (updateGoal): $e");
  }
}

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

  // --- ВЗАИМОДЕЙСТВИЕ ---
  Future<bool> respondToGoalInvite(int goalId, bool accept, int userId) async {
    bool ok = await _goalService.respondToInvite(goalId, accept);
    if (ok) await loadGoals(userId);
    return ok;
  }

  Future<bool> invitePartner(int goalId, int partnerId, int userId) async {
    bool ok = await _goalService.invitePartner(goalId, partnerId);
    if (ok) await loadGoals(userId);
    return ok;
  }

  Future<void> removeGoal(int id, int uid) async {
    await _goalService.deleteGoal(id);
    await loadGoals(uid);
  }

  // В GoalProvider.dart
Future<bool> addMaterialWithTask(int goalId, String title, String content, String type, int? taskId) async {
  bool success = await _goalService.addMaterial(
    goalId: goalId,
    title: title,
    content: content,
    type: type,
    taskId: taskId, // Передаем
  );
  if (success) {
    // Принудительно перезагружаем список целей, чтобы увидеть материал в структуре
    await loadGoals(_goals.firstWhere((g) => g.id == goalId).userId);
    notifyListeners();
  }
  return success;
}

  // Получение черновика шагов от AI
  Future<List<TaskDraftResponse>> getDraftSteps(String title, String why, String result, DateTime date) async {
    return await _goalService.generateDraft(title, why, result, date);
  }

  // Синхронизация прогресса
  void syncProgress(int goalId, double newProgress) {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _goals[index] = _goals[index].copyWith(progress: newProgress);
      notifyListeners();
    }
  }
}