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
    Function() onRoadmapUpdated,
    Function(int) onMessageDeleted,
    Function(int) onNotificationDeleted,
    Function(String) onStatusChanged
  ) async {
    // 1. Останавливаем старое соединение, если оно есть
    if (_hubConnection != null) {
      await _hubConnection!.stop();
    }

    final token = await _storage.read(key: 'jwt_token');
    String base = ApiConfig.baseUrl.replaceFirst('/api', '');
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final hubUrl = "$base/chatHub";

    // 2. СНАЧАЛА СОЗДАЕМ СОЕДИНЕНИЕ
    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl, options: HttpConnectionOptions(
          accessTokenFactory: () async => token ?? '',
          transport: HttpTransportType.WebSockets,
        ))
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000]) 
        .build();

    // 3. ЗАТЕМ РЕГИСТРИРУЕМ СЛУШАТЕЛЕЙ (теперь _hubConnection не null)
    
    _hubConnection!.on("ReceiveMessage", (args) {
      if (args != null && args.isNotEmpty) {
        debugPrint("SignalR: Message Received: ${args[0]}");
        onMessageReceived(MessageDto.fromJson(args[0] as Map<String, dynamic>));
      }
    });

    _hubConnection!.on("RoadmapUpdated", (args) => onRoadmapUpdated());
    
    _hubConnection!.on("NotificationReceived", (args) => onRoadmapUpdated());

    _hubConnection!.on("MessageDeleted", (args) {
      if (args != null && args.isNotEmpty) {
        final data = args[0] as Map<String, dynamic>;
        onMessageDeleted(data['messageId']);
      }
    });

    _hubConnection!.on("NotificationDeleted", (args) {
       if (args != null && args.isNotEmpty) {
         onNotificationDeleted(args[0] as int);
       }
    });

    // Статусы переподключения
    _hubConnection!.onreconnecting(({error}) => onStatusChanged("Переподключение..."));
    _hubConnection!.onreconnected(({connectionId}) async {
      await _hubConnection!.invoke("JoinGroup", args: [groupId.toString()]);
      onStatusChanged("Онлайн");
    });
    _hubConnection!.onclose(({error}) => onStatusChanged("Оффлайн"));

    // 4. ЗАПУСКАЕМ И ВХОДИМ В ГРУППУ
    try {
      await _hubConnection!.start();
      debugPrint("SignalR: Connection started");
      
      // КРИТИЧНО: Входим в комнату, чтобы получать сообщения именно этой группы
      await _hubConnection!.invoke("JoinGroup", args: [groupId.toString()]);
      debugPrint("SignalR: Joined group $groupId");
      
      onStatusChanged("Онлайн");
    } catch (e) {
      debugPrint("SignalR Start Error: $e");
      onStatusChanged("Ошибка сети");
    }
  }

  Future<void> stopConnection(int groupId) async {
    if (_hubConnection != null) {
      try {
        if (_hubConnection!.state == HubConnectionState.Connected) {
          await _hubConnection!.invoke("LeaveGroup", args: [groupId.toString()]);
        }
        await _hubConnection!.stop();
      } catch (e) {
        debugPrint("Stop connection error: $e");
      } finally {
        _hubConnection = null;
      }
    }
  }
}