import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_app/providers/task_provider.dart';
import 'package:hive_app/services/api_client.dart';
import 'package:provider/provider.dart';
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


Future<bool> addFileMaterial(int goalId, String title, int? taskId, PlatformFile file) async {
  try {
    // Создаем MultipartFile в зависимости от платформы
    late MultipartFile multipartFile;
    
    if (file.bytes != null) {
      // Веб-платформа - используем bytes
      multipartFile = MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
      );
    } else if (file.path != null) {
      // Мобильная платформа - используем path
      multipartFile = await MultipartFile.fromFile(
        file.path!,
        filename: file.name,
      );
    } else {
      throw Exception('No file data available');
    }
    
    FormData data = FormData.fromMap({
      "GoalId": goalId,
      "Title": title,
      "Type": "File",
      "TaskId": taskId,
      "File": multipartFile,
    });
    
    final response = await _api.dio.post("/Goals/materials/upload", data: data);
    
    if (response.statusCode == 200) {
      await loadGoals(_goals.first.userId);
      return true;
    }
  } catch (e) {
    debugPrint("Error uploading file material: $e");
  }
  return false;
}

// Обновленный метод для поддержки и файлов и ссылок
Future<bool> addMaterialWithTask(int goalId, String title, String content, String type, int? taskId, {PlatformFile? file}) async {
  if (type == "File" && file != null) {
    return await addFileMaterial(goalId, title, taskId, file);
  }
  
  // Для ссылок используем существующий метод
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

Future<void> removeGoal(int goalId, int userId) async {
  // 1. Находим и удаляем локально сразу
  _goals.removeWhere((g) => g.id == goalId);
  notifyListeners(); // UI скроет карточку мгновенно

  try {
    final success = await _goalService.deleteGoal(goalId);
    if (!success) {
      // Если сервер не удалил — вернем данные (опционально)
      await loadGoals(userId); 
    }
  } catch (e) {
    print("Ошибка при удалении: $e");
  }
}


void removeTaskFromGoal(int goalId, int taskId) {
  // 1. Ищем индекс цели
  final gIdx = _goals.indexWhere((g) => g.id == goalId);
  if (gIdx != -1) {
    // 2. Создаем НОВЫЙ список задач без удаленной задачи
    final updatedTasks = _goals[gIdx].tasks.where((t) => t.id != taskId).toList();
    
    // 3. Обновляем цель целиком через copyWith
    _goals[gIdx] = _goals[gIdx].copyWith(tasks: updatedTasks);
    
    // 4. Пересчитываем прогресс цели локально (чтобы цифра сразу стала верной)
    // Допустим, мы считаем прогресс по создателю:
    int done = updatedTasks.where((t) => t.completions.any((c) => c.username == _goals[gIdx].userId.toString())).length;
    _goals[gIdx] = _goals[gIdx].copyWith(
      progress: updatedTasks.isEmpty ? 0 : (done / updatedTasks.length * 100)
    );

    notifyListeners();
  }
}


Future<void> respondToGoalInvite(int goalId, bool accept, int myId, BuildContext context) async {
  try {
    final response = await _api.dio.post("/Goals/invitation/$goalId/respond?accept=$accept");
    if (response.statusCode == 200) {
      // 1. Сразу обновляем цели
      await loadGoals(myId);
      // 2. СРАЗУ ОБНОВЛЯЕМ ЗАДАЧИ ДЛЯ ГЛАВНОЙ (чтобы они появились мгновенно)
      await context.read<TaskProvider>().loadAllTasks();
      notifyListeners();
    }
  } catch (e) {
    debugPrint("Ошибка принятия приглашения: $e");
  }
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

Future<bool> removeMember(int goalId, int memberId) async {
  try {
    final response = await _api.dio.delete("/Goals/$goalId/members/$memberId");
    if (response.statusCode == 200) {
      // 1. Находим цель и удаляем участника локально
      final goalIndex = _goals.indexWhere((g) => g.id == goalId);
      if (goalIndex != -1) {
        _goals[goalIndex].collaborators.removeWhere((c) => c.id == memberId);
        
        // *** ВАЖНОЕ ИСПРАВЛЕНИЕ: Очищаем completions удаленного участника из ВСЕХ задач ***
        final updatedTasks = _goals[goalIndex].tasks.map((task) {
          // Удаляем completions удаленного пользователя
          final filteredCompletions = task.completions
              .where((c) => c.username != _goals[goalIndex].collaborators
                  .firstWhere((col) => col.id == memberId, 
                    orElse: () => GoalPartnerDto(
                      id: memberId, 
                      name: "", 
                      progress: 0, 
                      avatarUrl: null, 
                      isConfirmed: false, 
                      isAdmin: false
                    ))
                  .name)
              .toList();
          
          // Возвращаем обновленную задачу
          return task.copyWith(completions: filteredCompletions);
        }).toList();
        
        // Обновляем цель с очищенными задачами
        _goals[goalIndex] = _goals[goalIndex].copyWith(tasks: updatedTasks);
      }
      
      // 2. Уведомляем интерфейс
      notifyListeners();
      return true;
    }
  } catch (e) {
    debugPrint("Error removeMember: $e");
  }
  return false;
}

// В классе GoalProvider добавьте метод:
Future<void> updateGoalMode(int goalId, bool newIsSolo) async {
  try {
    final response = await _api.dio.patch(
      "/Goals/$goalId/toggle-solo", // Ваш эндпоинт для смены режима
      data: newIsSolo, // Отправляем новое значение isSolo
      options: Options(headers: {'Content-Type': 'application/json'})
    );

    if (response.statusCode == 200) {
      // Находим цель в списке и обновляем её
      final index = _goals.indexWhere((g) => g.id == goalId);
      if (index != -1) {
        // Создаем новую копию цели с измененным флагом
        final updatedGoal = _goals[index].copyWith(isSolo: newIsSolo);
        _goals[index] = updatedGoal;
        
        // Уведомляем всех, кто слушает изменения
        notifyListeners(); 
      }
    }
  } catch (e) {
    debugPrint("Ошибка смены режима цели: $e");
  }
}

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

Future<bool> leaveGoal(int goalId) async {
  try {
    final response = await _api.dio.post("/Goals/$goalId/leave");
    if (response.statusCode == 200) {
      _goals.removeWhere((g) => g.id == goalId);
      notifyListeners();
      return true;
    }
  } catch (e) {
    debugPrint("Error leaveGoal: $e");
  }
  return false;
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
      // Находим userId и перезагружаем все данные
      final goalIndex = _goals.indexWhere((g) => g.id == goalId);
      if (goalIndex != -1) {
        final userId = _goals[goalIndex].userId;
        await loadGoals(userId);
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
// В GoalProvider.dart исправьте этот метод:
Future<List<TaskDraftResponse>> getDraftSteps(String title, String why, String result, DateTime date) async {
  _isLoading = true;
  notifyListeners();
  
  try {
    // Получаем свежий список от сервиса
    final freshSteps = await _goalService.generateDraft(title, why, result, date);
    
    _isLoading = false;
    notifyListeners();
    
    return freshSteps; // Возвращаем ТОЛЬКО новые шаги
  } catch (e) {
    _isLoading = false;
    notifyListeners();
    return [];
  }
}

  void clearGoals() {
    _goals = [];
    notifyListeners();
  }
}