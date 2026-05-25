import 'package:signalr_netcore/signalr_client.dart';
import '../models/all_models.dart';
import 'api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatService {
  HubConnection? _hubConnection;
  final _storage = const FlutterSecureStorage();

  // Инициализация соединения
  Future<void> initSignalR(int groupId, Function(MessageDto) onMessageReceived) async {
    final token = await _storage.read(key: 'jwt_token');
    final hubUrl = "${ApiConfig.baseUrl.replaceFirst('/api', '')}/chatHub";

    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl, options: HttpConnectionOptions(
          accessTokenFactory: () async => token!,
        ))
        .build();

    _hubConnection!.on("ReceiveMessage", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final msg = MessageDto.fromJson(arguments[0] as Map<String, dynamic>);
        onMessageReceived(msg);
      }
    });

    await _hubConnection!.start();
    await _hubConnection!.invoke("JoinGroup", args: [groupId.toString()]);
  }

  Future<void> stopConnection(int groupId) async {
    if (_hubConnection != null) {
      await _hubConnection!.invoke("LeaveGroup", args: [groupId.toString()]);
      await _hubConnection!.stop();
    }
  }
}