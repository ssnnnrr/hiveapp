import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/api_client.dart';

class GroupProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<GroupResponse> _groups = [];
  List<MessageDto> _messages = [];
  List<RoadmapStepDto> _roadmapSteps = []; // Для текущего чата
  List<RoadmapStepDto> _allRoadmapSteps = []; // Для главного экрана задач
  bool _isLoading = false;
  int? _currentGroupId;

  // Геттеры
  List<GroupResponse> get groups => _groups;
  List<MessageDto> get messages => _messages;
  List<RoadmapStepDto> get roadmapSteps => _roadmapSteps;
  List<RoadmapStepDto> get allRoadmapSteps => _allRoadmapSteps;
  bool get isLoading => _isLoading;

  // --- ЛОГИКА ГРУПП (ЧАТОВ) ---

  // Загрузка всех моих чатов (для списка чатов)
  Future<void> loadGroups() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.dio.get("/Chat/my-chats");
      _groups = (response.data as List)
          .map((g) => GroupResponse.fromJson(g))
          .toList();
    } catch (e) {
      debugPrint("Ошибка загрузки групп: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Открытие конкретного чата
  Future<void> openChat(int groupId) async {
    _currentGroupId = groupId;
    _messages = [];
    _roadmapSteps = [];
    notifyListeners();

    await loadMessages(groupId);
    await loadRoadmap(groupId); // Теперь этот метод определен ниже
  }

  void closeChat(int groupId) {
    if (_currentGroupId == groupId) _currentGroupId = null;
  }

  // --- ЛОГИКА СООБЩЕНИЙ ---

  Future<void> loadMessages(int groupId) async {
    try {
      final response = await _api.dio.get("/Chat/$groupId/messages");
      _messages = (response.data as List)
          .map((m) => MessageDto.fromJson(m))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Ошибка сообщений: $e");
    }
  }

  Future<void> sendMessage(int groupId, String content) async {
    try {
      final response = await _api.dio.post("/Chat", data: {
        "groupId": groupId, 
        "content": content
      });
      if (response.statusCode == 200) {
        _messages.add(MessageDto.fromJson(response.data));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Ошибка отправки: $e");
    }
  }

  // --- ЛОГИКА ПЛАНА (ROADMAP) ---

  // ТОТ САМЫЙ МЕТОД, КОТОРОГО НЕ ХВАТАЛО
  Future<void> loadRoadmap(int groupId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.dio.get("/Chat/$groupId/roadmap");
      _roadmapSteps = (response.data as List)
          .map((s) => RoadmapStepDto.fromJson(s))
          .toList();
    } catch (e) {
      debugPrint("Ошибка загрузки плана: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Загрузка планов изо всех чатов сразу (для главного экрана Tasks)
  Future<void> loadAllRoadmaps() async {
    try {
      final response = await _api.dio.get("/Chat/roadmap/all-my");
      _allRoadmapSteps = (response.data as List)
          .map((s) => RoadmapStepDto.fromJson(s))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Ошибка общих планов: $e");
    }
  }


Future<bool> editRoadmapStep(int stepId, int groupId, String content, DateTime date) async {
  try {
    final response = await _api.dio.put("/Chat/roadmap/$stepId", data: {
      "content": content,
      "dueDate": date.toIso8601String(),
    });

    if (response.statusCode == 200) {
      await loadRoadmap(groupId);
      await loadAllRoadmaps(); // Синхронизируем главный экран
      return true;
    }
    return false;
  } catch (e) {
    debugPrint("Ошибка редактирования шага: $e");
    return false;
  }
}

Future<void> updateStepStatus(int stepId, bool isDone) async {
  try {
    // ВАЖНО: Добавляем Options, чтобы избежать ошибки Content-Type
    await _api.dio.patch(
      "/Groups/steps/$stepId/status", // Убедись, что в GroupsController путь именно такой
      data: isDone,
      options: Options(contentType: "application/json"), 
    );
    
    // Обновляем локально
    await loadAllRoadmaps();
    notifyListeners();
  } catch (e) {
    debugPrint("Ошибка обновления статуса: $e");
  }
}
// 2. Метод отправки напоминания
Future<void> remindPartnerAboutStep(int stepId) async {
  try {
    // Путь /Groups/steps/.../remind совпадает с бэкендом
    await _api.dio.post("/Groups/steps/$stepId/remind");
  } catch (e) {
    debugPrint("Ошибка Roadmap reminder: $e");
  }
}

// Внутри GroupProvider найдите и замените методы:

Future<bool> addRoadmapStep(int groupId, String content, DateTime date, {String? instructionUrl}) async {
  try {
    final response = await _api.dio.post("/Chat/roadmap", data: {
      "groupId": groupId,
      "content": content,
      "dueDate": date.toIso8601String(),
      "instructionUrl": instructionUrl, // Добавили это
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      await loadRoadmap(groupId);
      await loadAllRoadmaps();
      return true;
    }
    return false;
  } catch (e) {
    debugPrint("Ошибка сохранения шага: $e");
    return false;
  }
}

// Поправьте этот метод (замените bool на String и поле на status)
void _updateLocalStatus(List<RoadmapStepDto> list, int id, String status) {
  final i = list.indexWhere((s) => s.id == id);
  if (i != -1) list[i] = list[i].copyWith(status: status);
}

// 1. Сдать работу (для ученика)
Future<void> submitStepResult(int stepId, String url) async {
  try {
    await _api.dio.post("/Chat/roadmap/submit", data: {
      "stepId": stepId,
      "artifactUrl": url
    });
    await loadAllRoadmaps(); // Обновляем данные
    notifyListeners();
  } catch (e) {
    debugPrint("Ошибка сдачи работы: $e");
  }
}

// 2. Проверить работу (для учителя)
Future<void> verifyStep(int stepId, bool approve, String comment) async {
  try {
    await _api.dio.post("/Chat/roadmap/verify", data: {
      "stepId": stepId,
      "approve": approve,
      "comment": comment
    });
    await loadAllRoadmaps();
    notifyListeners();
  } catch (e) {
    debugPrint("Ошибка проверки работы: $e");
  }
}

  // --- ВЗАИМОДЕЙСТВИЕ (ДИРЕКТ) ---

  Future<int?> startDirectChat(int targetUserId) async {
    try {
      final response = await _api.dio.post("/Chat/direct/$targetUserId");
      int chatId = response.data['id'];
      await loadGroups();
      return chatId;
    } catch (e) {
      debugPrint("Ошибка API чата: $e");
      return null;
    }
  }


  Future<void> deleteRoadmapStep(int stepId) async {
    await _api.dio.delete("/Chat/roadmap/$stepId");
    _roadmapSteps.removeWhere((s) => s.id == stepId);
    _allRoadmapSteps.removeWhere((s) => s.id == stepId);
    notifyListeners();
  }

  Future<void> deleteMessage(int messageId) async {
    await _api.dio.delete("/Chat/messages/$messageId");
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }
}