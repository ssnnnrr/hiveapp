import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/all_models.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';

class GroupProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final ChatService _chatService = ChatService();

  // --- СОСТОЯНИЕ (STATE) ---
  List<GroupResponse> _groups = [];
  List<MessageDto> _messages = [];
  List<RoadmapStepDto> _roadmapSteps = []; // Шаги конкретной группы
  List<RoadmapStepDto> _allRoadmapSteps = []; // Все шаги всех партнеров (для главной)
  
  bool _isLoading = false;
  int? _activeGroupId; // Храним ID текущего чата для SignalR

  // --- ГЕТТЕРЫ ---
  List<GroupResponse> get groups => _groups;
  List<MessageDto> get messages => _messages;
  List<RoadmapStepDto> get roadmapSteps => _roadmapSteps;
  List<RoadmapStepDto> get allRoadmapSteps => _allRoadmapSteps;
  bool get isLoading => _isLoading;

  // --- ГРУППЫ И ЧАТЫ ---

  /// Загрузка списка всех чатов
  Future<void> loadGroups() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.dio.get("/Groups");
      if (response.statusCode == 200) {
        _groups = (response.data as List).map((g) => GroupResponse.fromJson(g)).toList();
      }
    } catch (e) {
      debugPrint("GroupProvider Error [loadGroups]: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Создание чата один-на-один
  Future<int?> startDirectChat(int targetUserId) async {
    try {
      final response = await _api.dio.post("/Groups/direct/$targetUserId");
      if (response.statusCode == 200) {
        await loadGroups();
        return response.data['id'];
      }
    } catch (e) {
      debugPrint("GroupProvider Error [startDirectChat]: $e");
    }
    return null;
  }

  // --- ЧАТ (SIGNALR И СООБЩЕНИЯ) ---

Future<void> openChat(int groupId) async {
  _activeGroupId = groupId;
  _messages = [];
  _roadmapSteps = [];
  
  // Не вызываем notifyListeners() здесь
  // notifyListeners(); // УБИРАЕМ ЭТУ СТРОКУ
  
  try {
    await loadMessages(groupId);
  } catch (e) {
    debugPrint("Error loading messages: $e");
  }
  
  try {
    await loadRoadmap(groupId);
  } catch (e) {
    debugPrint("Error loading roadmap: $e");
  }
  
  try {
    await _chatService.initSignalR(groupId, (newMessage) {
      if (!_messages.any((m) => m.id == newMessage.id)) {
        _messages.add(newMessage);
        notifyListeners();
      }
    });
  } catch (e) {
    debugPrint("Error connecting to SignalR: $e");
  }
}

  /// Выход из чата
  void closeChat(int groupId) {
    _chatService.stopConnection(groupId);
    _activeGroupId = null;
  }

  /// Загрузка истории сообщений
  Future<void> loadMessages(int groupId) async {
    try {
      final response = await _api.dio.get("/Chat/$groupId/messages");
      if (response.statusCode == 200) {
        _messages = (response.data as List).map((m) => MessageDto.fromJson(m)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("GroupProvider Error [loadMessages]: $e");
    }
  }

  /// Отправка сообщения
  Future<void> sendMessage(int groupId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      // Сервер возвращает DTO созданного сообщения
      final response = await _api.dio.post("/Chat/send", data: {
        "groupId": groupId, 
        "content": content
      });
      
      if (response.statusCode == 200) {
        final newMsg = MessageDto.fromJson(response.data);
        if (!_messages.any((m) => m.id == newMsg.id)) {
          _messages.add(newMsg);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("GroupProvider Error [sendMessage]: $e");
    }
  }

  // --- ПЛАН ОБУЧЕНИЯ (ROADMAP) ---

  /// Загрузка шагов текущей группы
Future<void> loadRoadmap(int groupId) async {
  try {
    print("DEBUG: Запрашиваю Roadmap для группы $groupId...");
    final response = await _api.dio.get("/Chat/$groupId/roadmap");
    
    if (response.statusCode == 200) {
      // ЛОГ №1: Видим ли мы попытки в сыром JSON?
      print("DEBUG: Получен ответ от сервера: ${response.data}");
      
      _roadmapSteps = (response.data as List).map((s) {
         var step = RoadmapStepDto.fromJson(s);
         // ЛОГ №2: Проверяем, что получилось после парсинга
         if (step.isTest) {
           print("DEBUG: Тест '${step.content}': Попытки из JSON = ${s['UsedAttempts'] ?? s['usedAttempts']}, В объекте = ${step.usedAttempts}");
         }
         return step;
      }).toList();
      
      notifyListeners();
    }
  } catch (e) {
    print("DEBUG: Ошибка в loadRoadmap: $e");
  }
}
  /// Загрузка всех шагов всех активных обучений для Главной страницы
  Future<void> loadAllRoadmaps() async {
    try {
      final response = await _api.dio.get("/Chat/roadmap/all-my");
      if (response.statusCode == 200) {
        _allRoadmapSteps = (response.data as List).map((s) => RoadmapStepDto.fromJson(s)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("GroupProvider Error [loadAllRoadmaps]: $e");
    }
  }

  

  /// Удаление шага
  Future<void> deleteRoadmapStep(int stepId, int groupId) async {
    try {
      final response = await _api.dio.delete("/Chat/roadmap/$stepId");
      if (response.statusCode == 200) {
        _roadmapSteps.removeWhere((s) => s.id == stepId);
        _allRoadmapSteps.removeWhere((s) => s.id == stepId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("GroupProvider Error [deleteRoadmapStep]: $e");
    }
  }

// Исправленный метод uploadMaterialFile в GroupProvider:
Future<String?> uploadMaterialFile(int groupId) async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx', 'zip', 'rar', 'txt'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    print('Processing material file: ${file.name}');
    
    Uint8List fileBytes;
    if (kIsWeb) {
      fileBytes = file.bytes!;
    } else {
      fileBytes = await File(file.path!).readAsBytes();
    }
    
    // Сохраняем файл как data URL (base64)
    String base64File = base64Encode(fileBytes);
    String mimeType = file.name.endsWith('.pdf') ? 'application/pdf' 
        : file.name.endsWith('.docx') ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        : file.name.endsWith('.doc') ? 'application/msword'
        : 'application/octet-stream';
    
    // Возвращаем data URL, который можно открыть в браузере
    return 'data:$mimeType;base64,$base64File';
    
  } catch (e) {
    debugPrint("Error processing material file: $e");
    return null;
  }
}


// В GroupProvider
Future<String?> uploadFileToServer(PlatformFile file) async {
  try {
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(
        file.bytes!, 
        filename: file.name
      ),
    });

    final response = await _api.dio.post("/Chat/upload-file", data: formData);

    if (response.statusCode == 200) {
      // Сервер вернул нам уникальное имя файла
      return response.data['fileName']; 
    }
  } catch (e) {
    debugPrint("Ошибка загрузки файла на сервер: $e");
  }
  return null;
}



    Future<void> submitStepResult(int stepId, String artifactUrl, String studentComment, int groupId) async {
    try {
      await _api.dio.post("/Chat/roadmap/submit", data: {
        "stepId": stepId,
        "artifactUrl": artifactUrl,
        "studentComment": studentComment
      });
      await loadRoadmap(groupId);
      await loadAllRoadmaps();
    } catch (e) {
      debugPrint("Ошибка сдачи работы: $e");
    }
  }

    Future<void> verifyStep(int stepId, bool approve, String? comment, int groupId) async {
    try {
      await _api.dio.post("/Chat/roadmap/verify", data: {"stepId": stepId, "approve": approve, "comment": comment});
      await loadRoadmap(groupId);
      await loadAllRoadmaps();
    } catch (e) {}
  }


  // --- ТЕСТЫ (AI И ЛОГИКА) ---

  /// Запрос к бэкенду на генерацию теста через AI
  Future<String?> generateTest(String topic, String format, int questionsCount) async {
    try {
      final response = await _api.dio.post("/Chat/roadmap/generate-test", data: {
        "topic": topic,
        "format": format,
        "questionsCount": questionsCount,
      });
      if (response.statusCode == 200) {
        return response.data['testData']; // Строка JSON теста
      }
    } catch (e) {
      debugPrint("AI Generation Error: $e");
    }
    return null;
  }

  /// Прикрепить готовый JSON теста к существующему шагу
  Future<void> saveTestToStep(int stepId, String testJson, int groupId) async {
    try {
      await _api.dio.post("/Chat/roadmap/$stepId/save-test", data: jsonDecode(testJson));
      await loadRoadmap(groupId);
    } catch (e) {
      debugPrint("Error [saveTestToStep]: $e");
    }
  }


Future<void> finalizeTestResult(int stepId, int groupId) async {
  try {
    await _api.dio.post(
      "/Chat/roadmap/finalize-test", 
      data: {
        "stepId": stepId  // Отправляем как JSON объект, а не просто число
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
    await loadRoadmap(groupId);
    await loadAllRoadmaps();
  } catch (e) {
    debugPrint("Error finalizeTest: $e");
    rethrow;
  }
}

  // --- СДАЧА РАБОТ И ФАЙЛЫ ---

Future<void> toggleStepComplete(int stepId, int groupId) async {
  try {
    await _api.dio.post(
      "/Chat/roadmap/toggle-complete", 
      data: {
        "stepId": stepId  // Отправляем как JSON объект
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
    await loadRoadmap(groupId);
    await loadAllRoadmaps();
  } catch (e) {
    debugPrint("Error toggleStep: $e");
  }
}

    Future<void> addStepComment(int stepId, String text, int groupId) async {
    await _api.dio.post("/Chat/roadmap/comment", data: {"stepId": stepId, "text": text});
    await loadRoadmap(groupId);
  }

  Future<void> deleteStepComment(int commentId, int groupId) async {
    await _api.dio.delete("/Chat/roadmap/comment/$commentId");
    await loadRoadmap(groupId);
  }


// Замените метод uploadArtifact в GroupProvider на этот:

Future<void> uploadArtifact(int stepId, int groupId) async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx', 'zip', 'rar', 'txt'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      print('Файл не выбран');
      return;
    }

    final file = result.files.first;
    print('Выбран файл: ${file.name}, размер: ${file.size}');
    
    Uint8List fileBytes;
    if (kIsWeb) {
      fileBytes = file.bytes!;
    } else {
      fileBytes = await File(file.path!).readAsBytes();
    }
    
    String base64File = base64Encode(fileBytes);

    // ЛОГИРОВАНИЕ: Проверяем полный URL
    final fullUrl = '${_api.dio.options.baseUrl}Chat/roadmap/submit';
    print('=== ОТЛАДКА ЗАПРОСА ===');
    print('Base URL: ${_api.dio.options.baseUrl}');
    print('Полный URL: $fullUrl');
    print('StepId: $stepId');
    print('GroupId: $groupId');
    print('Размер файла: ${fileBytes.length} байт');
    print('========================');

    // Пробуем разные варианты отправки
    final response = await _api.dio.post(
      "/Chat/roadmap/submit",
      data: {
        "stepId": stepId,
        "studentComment": "Файл: ${file.name}",
        "file": base64File,
        "fileName": file.name,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    print('Успех! Статус: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      await loadRoadmap(groupId);
      await loadAllRoadmaps();
    }
  } catch (e) {
    print("=== ОШИБКА ===");
    if (e is DioException) {
      print('Статус код: ${e.response?.statusCode}');
      print('URL запроса: ${e.requestOptions.uri}');
      print('Метод: ${e.requestOptions.method}');
      print('Заголовки: ${e.requestOptions.headers}');
      print('Данные: ${e.requestOptions.data}');
      
      // Проверяем разные URL для диагностики
      await _diagnoseEndpoints();
    }
    print("==============");
    rethrow;
  }
}

// Диагностический метод для проверки доступных эндпоинтов
Future<void> _diagnoseEndpoints() async {
  print('\n=== ДИАГНОСТИКА ЭНДПОИНТОВ ===');
  
  final endpoints = [
    'Chat/roadmap/submit',
    '/Chat/roadmap/submit',
    'api/Chat/roadmap/submit',
    '/api/Chat/roadmap/submit',
  ];
  
  for (final endpoint in endpoints) {
    try {
      final response = await _api.dio.post(
        endpoint,
        data: {"stepId": 1, "studentComment": "test"},
        options: Options(validateStatus: (status) => true), // Принимаем любой статус
      );
      print('$endpoint -> ${response.statusCode}');
    } catch (e) {
      print('$endpoint -> ОШИБКА: $e');
    }
  }
  print('===============================\n');
}

// Вспомогательный метод для определения MIME типа
String _getMimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'zip':
      return 'application/zip';
    case 'rar':
      return 'application/x-rar-compressed';
    case 'txt':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}

// Добавьте новый метод для загрузки файлов в чат (если нужно):
Future<void> uploadChatFile(int groupId) async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx', 'zip', 'rar', 'txt'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    
    MultipartFile multipartFile;
    if (kIsWeb) {
      if (file.bytes == null) return;
      multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
    } else {
      if (file.path == null) return;
      multipartFile = await MultipartFile.fromFile(file.path!, filename: file.name);
    }

    // Если есть эндпоинт для загрузки в чат, используйте его
    // Если нет - отправляем файл как сообщение с ссылкой
    final formData = FormData.fromMap({
      "groupId": groupId,
      "file": multipartFile,
    });

    // Временно: отправляем информацию о файле как сообщение
    // Замените на реальный эндпоинт, когда он будет готов
    await sendMessage(groupId, "📎 Отправлен файл: ${file.name}");
    
    // Если будет эндпоинт для чата:
    // final response = await _api.dio.post("/Chat/upload-file", data: formData);
    
  } catch (e) {
    debugPrint("Error [uploadChatFile]: $e");
  }
}
  
  // --- ДОБАВЛЕННЫЙ МЕТОД ДЛЯ ТЕСТОВ (был undefined) ---
// В файле lib/providers/group_provider.dart

  Future<void> createRoadmapStepWithTest({
    required int groupId,
    required String content,
    required DateTime dueDate,
    required String testData,
    String? instructionUrl,
    bool isRequired = true,
    int maxAttempts = 3,
  }) async {
    try {
      // 1. Создаем сам шаг
      final response = await _api.dio.post(
        "/Chat/roadmap", 
        data: {
          "groupId": groupId,
          "content": content,
          "dueDate": dueDate.toUtc().toIso8601String(),
          "instructionUrl": instructionUrl,
          "isTest": true,
          "isRequired": isRequired,
          "maxAttempts": maxAttempts
        },
        options: Options(contentType: "application/json"), // ФИКС ОШИБКИ 415
      );

      if (response.statusCode == 200) {
        int stepId = response.data['id'];
        // 2. Сохраняем вопросы теста
        await _api.dio.post(
          "/Chat/roadmap/$stepId/save-test", 
          data: jsonDecode(testData),
          options: Options(contentType: "application/json"), // ФИКС ОШИБКИ 415
        );
        
        await loadRoadmap(groupId);
        await loadAllRoadmaps();
      }
    } catch (e) {
      debugPrint("Ошибка создания теста (Провайдер): $e");
      rethrow; 
    }
  }

  // Обновленный метод добавления обычного шага (чтобы точно сохранялось)
  Future<void> addRoadmapStep({
    required int groupId,
    required String content,
    required DateTime date,
    String? instructionUrl,
    bool isTest = false,
    bool isRequired = true,
    int maxAttempts = 3,
  }) async {
    try {
      await _api.dio.post(
        "/Chat/roadmap", 
        data: {
          "groupId": groupId,
          "content": content,
          "dueDate": date.toUtc().toIso8601String(),
          "instructionUrl": instructionUrl,
          "isTest": isTest,
          "isRequired": isRequired,
          "maxAttempts": maxAttempts
        },
        options: Options(contentType: "application/json"),
      );
      await loadRoadmap(groupId);
      await loadAllRoadmaps();
    } catch (e) {
      debugPrint("Ошибка addRoadmapStep: $e");
    }
  }
  // --- КОММЕНТАРИИ К ШАГАМ (ОБЩЕНИЕ) ---


// Обновленный метод в GroupProvider
Future<void> submitTestResult(int stepId, double score, int groupId, String answersJson) async {
  try {
    final response = await _api.dio.post("/Chat/roadmap/submit-test-attempt", data: {
      "stepId": stepId,
      "score": score,
      "answersJson": answersJson,
    });
    
    if (response.statusCode == 200) {
      // Это ОБЯЗАТЕЛЬНО, чтобы обновить список в памяти приложения
      await loadRoadmap(groupId); 
      notifyListeners(); 
    }
  } catch (e) {
    print("Ошибка: $e");
  }
}
// В GroupProvider (или RoadmapProvider)

// Создание сложного теста
Future<void> createManualTest({
  required int groupId,
  required String title,
  required DateTime dueDate,
  required List<Map<String, dynamic>> questions,
  required int maxAttempts,
}) async {
  try {
    final testData = jsonEncode(questions);
    await _api.dio.post("/Chat/roadmap", data: {
      "groupId": groupId,
      "content": title,
      "dueDate": dueDate.toUtc().toIso8601String(),
      "isTest": true,
      "testData": testData, // JSON со всеми вопросами
      "maxAttempts": maxAttempts,
      "isRequired": true,
    });
    await loadRoadmap(groupId);
  } catch (e) {
    debugPrint("Ошибка создания теста: $e");
  }
}

// Отправка результата попытки
Future<void> submitTestAttempt(int stepId, double score, String answersJson, int groupId) async {
  await _api.dio.post("/Chat/roadmap/submit-test-attempt", data: {
    "stepId": stepId,
    "score": score,
    "answersJson": answersJson, // Здесь храним, что именно выбрал ученик
  });
  await loadRoadmap(groupId);
}



  // --- СООБЩЕНИЯ И ПИНЫ ---

  Future<void> togglePinMessage(int messageId, bool pin, int groupId) async {
    try {
      await _api.dio.post("/Chat/messages/$messageId/pin?pin=$pin");
      await loadMessages(groupId);
    } catch (e) {
      debugPrint("Error [togglePin]: $e");
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await _api.dio.delete("/Chat/messages/$messageId");
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error [deleteMessage]: $e");
    }
  }

  /// Полная очистка при выходе
  void clearData() {
    // ИСПРАВЛЕННАЯ ОШИБКА: вызываем существующий метод стопа для текущей группы
    if (_activeGroupId != null) {
      _chatService.stopConnection(_activeGroupId!);
    }
    _groups = [];
    _messages = [];
    _roadmapSteps = [];
    _allRoadmapSteps = [];
    _isLoading = false;
    _activeGroupId = null;
    notifyListeners();
  }
}