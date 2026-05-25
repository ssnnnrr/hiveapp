import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/all_models.dart';
import 'api_config.dart';
import 'api_client.dart';

class GroupService {
  final ApiClient _api = ApiClient();
  HubConnection? _hubConnection;
  List<RoadmapStepDto> _roadmapSteps = [];
  final _storage = const FlutterSecureStorage();
List<RoadmapStepDto> get roadmapSteps => _roadmapSteps;

  Future<List<GroupResponse>> getMyGroups(int userId) async {
    try {
      final response = await _api.dio.get("/Groups/user/$userId");
      return (response.data as List).map((json) => GroupResponse.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }



  Future<int?> getOrCreateDirectChat(int targetUserId) async {
    try {
      final response = await _api.dio.get("/Groups/direct/$targetUserId");
      return response.data['groupId'];
    } catch (e) {
      print("Error getting chat: $e");
      return null;
    }
  }


  Future<List<RoadmapStepDto>> getRoadmap(int groupId) async {
    try {
      final response = await _api.dio.get("/Chat/$groupId/roadmap");
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => RoadmapStepDto.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Отправить новый шаг на сервер
  Future<bool> addRoadmapStep(int groupId, String content) async {
    try {
      final response = await _api.dio.post("/Chat/roadmap", data: {
        "groupId": groupId,
        "content": content,
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> initSignalR(int groupId, Function(MessageDto) onMsg) async {
    final token = await _storage.read(key: 'jwt_token');
    final hubUrl = ApiConfig.baseUrl.replaceFirst("/api", "/chatHub");

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl, 
          options: HttpConnectionOptions( // ДОБАВЛЕНО 'options:'
            accessTokenFactory: () async => token!,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection!.on("ReceiveMessage", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final msg = MessageDto.fromJson(arguments[0] as Map<String, dynamic>);
        onMsg(msg);
      }
    });

    try {
      await _hubConnection!.start();
      await _hubConnection!.invoke("JoinGroup", args: [groupId.toString()]);
    } catch (e) {
      // Ошибки логируем в консоль для отладки
    }
  }

Future<void> stopSignalR(int groupId) async {
  if (_hubConnection != null) {
    // ПРОВЕРЯЕМ, ЧТО МЫ ВСЕ ЕЩЕ ПОДКЛЮЧЕНЫ ПЕРЕД ВЫЗОВОМ
    if (_hubConnection!.state == HubConnectionState.Connected) {
      await _hubConnection!.invoke("LeaveGroup", args: [groupId.toString()]);
    }
    await _hubConnection!.stop();
    _hubConnection = null;
  }
}

  Future<void> sendMessage(int groupId, String content) async {
    await _api.dio.post("/Chat", data: {"groupId": groupId, "content": content});
  }

  Future<List<MessageDto>> getChatMessages(int groupId) async {
    final response = await _api.dio.get("/Chat/$groupId/messages");
    return (response.data as List).map((json) => MessageDto.fromJson(json)).toList();
  }
}