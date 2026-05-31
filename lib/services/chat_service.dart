import 'package:signalr_netcore/signalr_client.dart';
import '../models/all_models.dart';
import 'api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  HubConnection? _hubConnection;
  final _storage = const FlutterSecureStorage();

Future<void> initSignalR(
  int groupId, 
  Function(MessageDto) onMessageReceived, 
  Function() onRoadmapUpdated
) async {
  // 1. Если соединение уже есть и оно РАБОТАЕТ — сначала закроем его, 
  // чтобы не было дублей и старых слушателей
  if (_hubConnection != null) {
    await _hubConnection!.stop();
    _hubConnection = null;
  }

  final token = await _storage.read(key: 'jwt_token');
  String base = ApiConfig.baseUrl.replaceFirst('/api', '');
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  final hubUrl = "$base/chatHub";

  _hubConnection = HubConnectionBuilder()
      .withUrl(hubUrl, options: HttpConnectionOptions(
        accessTokenFactory: () async => token ?? '',
        transport: HttpTransportType.WebSockets,
      ))
      .withAutomaticReconnect()
      .build();

  // 2. РЕГИСТРИРУЕМ СЛУШАТЕЛЕЙ ДО СТАРТА
  _hubConnection!.on("ReceiveMessage", (arguments) {
    if (arguments != null && arguments.isNotEmpty) {
      try {
        final msg = MessageDto.fromJson(arguments[0] as Map<String, dynamic>);
        onMessageReceived(msg);
      } catch (e) {
        debugPrint("SignalR Parse Error (Message): $e");
      }
    }
  });

  _hubConnection!.on("RoadmapUpdated", (arguments) {
    debugPrint("SignalR: План обучения обновлен!");
    onRoadmapUpdated(); // Вызываем обновление списка задач
  });

  try {
    // 3. СТАРТУЕМ
    await _hubConnection!.start();
    debugPrint("SignalR: Connected to $hubUrl");

    // 4. ВХОДИМ В ГРУППУ
  if (_hubConnection?.state == HubConnectionState.Connected) {
    await _hubConnection!.invoke("JoinGroup", args: [groupId.toString()]);
    return;
  }  } catch (e) {
    debugPrint("SignalR Start Error: $e");
  }
}

  Future<void> stopConnection(int groupId) async {
    if (_hubConnection != null) {
      try {
        debugPrint("SignalR: Leaving group $groupId and stopping...");
        await _hubConnection!.invoke("LeaveGroup", args: [groupId.toString()]);
        await _hubConnection!.stop();
      } catch (e) {
        debugPrint("SignalR: Error during stop: $e");
      }
    }
  }
}