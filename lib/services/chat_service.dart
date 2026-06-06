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
    if (_hubConnection != null) {
      await _hubConnection!.stop();
    }

    final token = await _storage.read(key: 'jwt_token');
    String base = ApiConfig.baseUrl.replaceFirst('/api', '');
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final hubUrl = "$base/chatHub";

    _hubConnection!.on("NotificationReceived", (args) {
       onRoadmapUpdated(); // Можно использовать этот же триггер для рефреша
    });

    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl, options: HttpConnectionOptions(
          accessTokenFactory: () async => token ?? '',
          transport: HttpTransportType.WebSockets,
          // ИСПРАВЛЕНО: Удален несуществующий ConsoleLogger. 
          // Библиотека сама пишет в консоль, если не указать иное.
        ))
        // ИСПРАВЛЕНО: Удален null из списка задержек
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000]) 
        .build();

    // Обработка автоматического переподключения
    _hubConnection!.onreconnecting(({error}) {
      onStatusChanged("Потеря связи. Переподключение...");
    });

    _hubConnection!.onreconnected(({connectionId}) async {
      // ПЕРЕЗАХОДИМ В ГРУППУ ПОСЛЕ ВОССТАНОВЛЕНИЯ СВЯЗИ
      try {
        await _hubConnection!.invoke("JoinGroup", args: [groupId.toString()]);
        onStatusChanged("Связь восстановлена");
      } catch (e) {
        debugPrint("Rejoin error: $e");
      }
    });

    _hubConnection!.onclose(({error}) {
      onStatusChanged("Чат оффлайн");
    });

    // Слушатели событий сервера
    _hubConnection!.on("ReceiveMessage", (args) {
      if (args != null && args.isNotEmpty) {
        onMessageReceived(MessageDto.fromJson(args[0] as Map<String, dynamic>));
      }
    });

    _hubConnection!.on("RoadmapUpdated", (args) => onRoadmapUpdated());
    
    _hubConnection!.on("MessageDeleted", (args) {
      if (args != null && args.isNotEmpty) {
        final data = args[0] as Map<String, dynamic>;
        onMessageDeleted(data['messageId']);
      }
    });

    try {
      await _hubConnection!.start();
      // ЗАХОДИМ В КОМНАТУ ГРУППЫ
      await _hubConnection!.invoke("JoinGroup", args: [groupId.toString()]);
      onStatusChanged("Онлайн");
    } catch (e) {
      debugPrint("SignalR Start Error: $e");
      onStatusChanged("Ошибка подключения");
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