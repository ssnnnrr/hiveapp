import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_app/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import '../models/all_models.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';

class GroupProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final ChatService _chatService = ChatService();

  // --- СОСТОЯНИЕ (STATE) ---
  List<GroupResponse> _groups = [];
  List<MessageDto> _messages = [];
  List<RoadmapStepDto> _roadmapSteps = [];
  List<RoadmapStepDto> _allRoadmapSteps = [];
  final Set<int> _myPinnedMessages = {}; 
  bool _isLoading = false;
  int? _activeGroupId;
  bool _isProcessingSignalR = false;

  // --- ГЕТТЕРЫ ---
  List<GroupResponse> get groups => _groups;
  List<MessageDto> get messages => _messages;
  List<RoadmapStepDto> get roadmapSteps => _roadmapSteps;
  List<RoadmapStepDto> get allRoadmapSteps => _allRoadmapSteps;
  Set<int> get myPinnedMessages => _myPinnedMessages;
  bool get isLoading => _isLoading;
  
  MessageDto? get pinnedMessage {
    try {
      return _messages.lastWhere((m) => m.isPinned);
    } catch (e) {
      return null;
    }
  }

  // --- УПРАВЛЕНИЕ ГРУППАМИ ---

  Future<void> loadGroups() async {
    try {
      final response = await _api.dio.get("/Groups");
      if (response.statusCode == 200) {
        _groups = (response.data as List).map((g) => GroupResponse.fromJson(g)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loadGroups: $e");
    }
  }

  Future<int?> startDirectChat(int targetUserId) async {
    try {
      final response = await _api.dio.post("/Groups/direct/$targetUserId");
      if (response.statusCode == 200) {
        await loadGroups();
        return response.data['id'];
      }
    } catch (e) {
      debugPrint("Error startDirectChat: $e");
    }
    return null;
  }

  // --- ЧАТ И SIGNALR ---

// Внутри GroupProvider.dart

Future<void> openChat(int groupId, int myId, BuildContext context, {VoidCallback? onBothFinished}) async {
    _activeGroupId = groupId;
    _isLoading = true;
    // Не очищаем сообщения сразу, чтобы UI не дергался, 
    // но помечаем, что мы в новой группе
    notifyListeners();

    try {
      // Первичная загрузка
      await _initialLoad(groupId);

      await _chatService.initSignalR(
        groupId,
        (newMessage) { // OnMessageReceived
          // Используем microtask для безопасности на Web
          Future.microtask(() {
            if (!_messages.any((m) => m.id == newMessage.id)) {
              _messages.insert(0, newMessage); 
              notifyListeners();
            }
          });
        },
        () async {
  debugPrint("--- SIGNALR: Сигнал обновления ---");
  
  // 1. Защита от "дребезга" (если пришло несколько сигналов сразу)
  if (_isProcessingSignalR) return;
  _isProcessingSignalR = true;

  try {
    // 2. Загружаем данные без уведомления слушателей
    await Future.wait([
      loadGroups(),
      loadRoadmap(groupId),
      loadMessages(groupId),
    ]);

    // 3. БЕЗОПАСНОЕ ОБНОВЛЕНИЕ: Ждем, пока Flutter Web будет готов к новому кадру
    if (hasListeners) {
      // Это предотвращает Assertion failed в window.dart
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    }
  } catch (e) {
    debugPrint("Ошибка обновления данных: $e");
  } finally {
    await Future.delayed(const Duration(milliseconds: 500));
    _isProcessingSignalR = false; // Открываем замок
  }
},
        (deletedId) { // OnMessageDeleted
          _messages.removeWhere((m) => m.id == deletedId);
          notifyListeners();
        },
        (noteId) {
          context.read<NotificationProvider>().handleSignalRNotificationDeleted(noteId);
        },
        (status) => debugPrint("SignalR Status: $status"),
      );
    } catch (e) {
      debugPrint("Error openChat: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
}

// Вынесем первичную загрузку в отдельный метод для чистоты
Future<void> _initialLoad(int groupId) async {
  try {
    await _api.dio.post("/Chat/$groupId/read-all");
    await loadGroups();
    await loadMessages(groupId);
    await loadRoadmap(groupId);
  } catch (e) {
    debugPrint("Initial load error: $e");
  }
}

  // Обновим метод загрузки сообщений, чтобы они шли в правильном порядке
  Future<void> loadMessages(int groupId) async {
    try {
      final response = await _api.dio.get("/Chat/$groupId/messages");
      if (response.statusCode == 200) {
        final List data = response.data;
        // Переворачиваем список из БД, чтобы новые были в начале (индекс 0)
        _messages = data.map((m) => MessageDto.fromJson(m)).toList().reversed.toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loadMessages: $e");
    }
  }

  // --- ЛОГИКА ЗАВЕРШЕНИЯ И ПЕРЕЗАПУСКА ---

Future<void> requestMyCompletion(int groupId) async {
  try {
    final response = await _api.dio.post("/Groups/$groupId/request-my-completion");
    if (response.statusCode == 200) {
      // Даже если SignalR задержится, мы сами обновляем данные для себя
      await loadGroups();
      await loadRoadmap(groupId);
      notifyListeners();
    }
  } catch (e) {
    debugPrint("Error requestMyCompletion: $e");
  }
}

Future<bool> confirmPartnerCompletion(int groupId) async {
  try {
    final response = await _api.dio.post("/Groups/$groupId/confirm-partner-completion");
    
    // Если сервер вернул, что оба завершили (isFullyFinished: true)
    if (response.statusCode == 200) {
      // Обновляем локальные данные, чтобы кнопки исчезли из Roadmap и чата
      await loadGroups(); 
      await loadMessages(groupId);
      
      final data = response.data;
      return data['isFullyFinished'] ?? false;
    }
    return false;
  } catch (e) {
    debugPrint("Error confirming completion: $e");
    return false;
  }
}

Future<void> rejectCompletion(int groupId) async {
  try {
    await _api.dio.post("/Groups/$groupId/reject-completion");
    // Здесь тоже ничего лишнего не вызываем
  } catch (e) {
    debugPrint("Error rejecting completion: $e");
    rethrow;
  }
}


  Future<void> requestFinish(int groupId) async {
    await requestMyCompletion(groupId);
  }

Future<bool> confirmFinish(int groupId) async {
    try {
      final response = await _api.dio.post("/Groups/$groupId/confirm-partner-completion");
      
      if (response.statusCode == 200) {
        // 1. Обновляем локальный список групп, чтобы получить свежие флаги
        await loadGroups(); 
        
        // 2. Находим нашу группу в обновленном списке
        final updatedGroup = _groups.firstWhere((g) => g.id == groupId);
        
        // 3. Возвращаем результат: завершено ли обучение для обоих?
        return updatedGroup.ownerFinished && updatedGroup.partnerFinished;
      }
    } catch (e) {
      debugPrint("Provider ConfirmFinish Error: $e");
    }
    return false; // Если ошибка или не оба закончили
  }


  Future<void> proposeRestart(int groupId) async {
    try {
      await _api.dio.post("/Groups/$groupId/propose-restart");
    } catch (e) {
      debugPrint("Error proposeRestart: $e");
    }
  }

  Future<void> confirmRestart(int groupId) async {
    try {
      await _api.dio.post("/Groups/$groupId/confirm-restart");
    } catch (e) {
      debugPrint("Error confirmRestart: $e");
    }
  }

  void closeChat(int groupId) {
    _chatService.stopConnection(groupId);
    _activeGroupId = null;
  }

  // --- СООБЩЕНИЯ ---


  Future<void> sendMessage(int groupId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      await _api.dio.post("/Chat/send", data: {"groupId": groupId, "content": content});
    } catch (e) {
      debugPrint("Error sendMessage: $e");
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await _api.dio.delete("/Chat/messages/$messageId");
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleteMessage: $e");
    }
  }

  Future<void> togglePinMessage(int messageId, bool pin, int groupId) async {
    try {
      final response = await _api.dio.post("/Chat/messages/$messageId/pin?pin=$pin");
      if (response.statusCode == 200) {
        for (var i = 0; i < _messages.length; i++) {
          if (pin) _messages[i] = _messages[i].copyWith(isPinned: false);
        }
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) _messages[idx] = _messages[idx].copyWith(isPinned: pin);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error togglePin: $e");
    }
  }

  void toggleLocalPin(int messageId) {
    if (_myPinnedMessages.contains(messageId)) {
      _myPinnedMessages.remove(messageId);
    } else {
      _myPinnedMessages.add(messageId);
    }
    notifyListeners();
  }

  // --- ПЛАН ОБУЧЕНИЯ (ROADMAP) ---

  Future<void> loadRoadmap(int groupId) async {
    try {
      final response = await _api.dio.get("/Chat/$groupId/roadmap");
      if (response.statusCode == 200) {
        _roadmapSteps = (response.data as List).map((s) => RoadmapStepDto.fromJson(s)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loadRoadmap: $e");
    }
  }

  Future<void> loadAllRoadmaps() async {
    try {
      final response = await _api.dio.get("/Chat/roadmap/all-my");
      if (response.statusCode == 200) {
        _allRoadmapSteps = (response.data as List).map((s) => RoadmapStepDto.fromJson(s)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loadAllRoadmaps: $e");
    }
  }

Future<void> addRoadmapStep({
  required int groupId,
  required String content,
  required DateTime date,
  String? instructionUrl,
  bool isTest = false,
  bool isRequired = true,
}) async {
  try {
    final response = await _api.dio.post("/Chat/roadmap", data: {
      "groupId": groupId,
      "content": content,
      "dueDate": date.toUtc().toIso8601String(),
      "instructionUrl": instructionUrl,
      "isTest": isTest,
      "isRequired": isRequired,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      // КРИТИЧЕСКИ ВАЖНО: Обновляем список сразу после добавления
      await loadRoadmap(groupId); 
      await loadAllRoadmaps(); // Для обновления на главной
      notifyListeners();
    }
  } catch (e) {
    debugPrint("Error addRoadmapStep: $e");
  }
}

  Future<void> submitStepResult({
    required int stepId,
    required String artifactUrl,
    String? studentComment,
    required int groupId,
  }) async {
    try {
      await _api.dio.post("/Chat/roadmap/submit", data: {
        "stepId": stepId,
        "artifactUrl": artifactUrl,
        "studentComment": studentComment
      });
    } catch (e) {
      debugPrint("Error submitStepResult: $e");
    }
  }

  Future<void> verifyStep({
    required int stepId,
    required bool approve,
    String? comment,
    required int groupId,
  }) async {
    try {
      await _api.dio.post("/Chat/roadmap/verify", data: {
        "stepId": stepId,
        "approve": approve,
        "comment": comment
      });
    } catch (e) {
      debugPrint("Error verifyStep: $e");
    }
  }

  Future<void> toggleStepComplete({required int stepId, required int groupId}) async {
    try {
      await _api.dio.post("/Chat/roadmap/toggle-complete", data: {"stepId": stepId});
    } catch (e) {
      debugPrint("Error toggleStepComplete: $e");
    }
  }

  Future<void> deleteRoadmapStep(int stepId, int groupId) async {
    try {
      await _api.dio.delete("/Chat/roadmap/$stepId");
      _roadmapSteps.removeWhere((s) => s.id == stepId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleteRoadmapStep: $e");
    }
  }

  // --- AI ТЕСТЫ ---

Future<String?> generateTest(String topic, String format, int questionsCount) async {
  try {
    final response = await _api.dio.post("/Chat/roadmap/generate-test", data: {
      "topic": topic,
      "format": format,
      "questionsCount": questionsCount,
    });
    return response.data['testData'];
  } on DioException catch (e) {
    // Вместо падения просто логируем и возвращаем null
    debugPrint("AI Generation Dio Error: ${e.response?.data}");
    return null;
  } catch (e) {
    debugPrint("AI Generation Unknown Error: $e");
    return null;
  }
}

Future<void> createRoadmapStepWithTest({
  required int groupId,
  required String content,
  required DateTime dueDate,
  required String testData, // Это наш JSON с вопросами
  int maxAttempts = 3,
  bool isRequired = true,
}) async {
  try {
    // ОТПРАВЛЯЕМ ВСЁ ОДНИМ ПАКЕТОМ
    final response = await _api.dio.post("/Chat/roadmap", data: {
      "groupId": groupId,
      "content": content,
      "dueDate": dueDate.toUtc().toIso8601String(),
      "isTest": true,
      "maxAttempts": maxAttempts,
      "isRequired": isRequired,
      "testData": testData, // Добавляем данные теста прямо сюда!
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      await loadRoadmap(groupId);
      notifyListeners();
    }
  } catch (e) {
    debugPrint("Ошибка создания теста: $e");
  }
}

  Future<void> submitTestResult(int stepId, double score, int groupId, String answersJson) async {
    try {
      await _api.dio.post("/Chat/roadmap/submit-test-attempt", data: {
        "stepId": stepId,
        "score": score,
        "answersJson": answersJson,
      });
    } catch (e) {
      debugPrint("Error submitTestResult: $e");
    }
  }

  Future<void> finalizeTestResult(int stepId, int groupId) async {
    try {
      await _api.dio.post("/Chat/roadmap/finalize-test", data: {"stepId": stepId});
    } catch (e) {
      debugPrint("Error finalizeTestResult: $e");
    }
  }

  // --- ЗАГРУЗКА ФАЙЛОВ ---

  Future<String?> uploadFileToServer(PlatformFile file) async {
    try {
      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });
      final response = await _api.dio.post("/Chat/upload-file", data: formData);
      return response.data['fileName'];
    } catch (e) {
      debugPrint("File upload error: $e");
      return null;
    }
  }

  Future<void> uploadArtifact(int stepId, int groupId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null) return;

      final file = result.files.first;
      String base64File = base64Encode(file.bytes!);

      await _api.dio.post("/Chat/roadmap/submit", data: {
        "stepId": stepId,
        "file": base64File,
        "fileName": file.name,
        "studentComment": "Файл прикреплен"
      });
    } catch (e) {
      debugPrint("Artifact upload error: $e");
    }
  }

  void clearData() {
    if (_activeGroupId != null) {
      _chatService.stopConnection(_activeGroupId!);
    }
    _groups = [];
    _messages = [];
    _roadmapSteps = [];
    _allRoadmapSteps = [];
    _activeGroupId = null;
    notifyListeners();
  }
}