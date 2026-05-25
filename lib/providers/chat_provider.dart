import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/chat_service.dart';
import '../services/api_client.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final ApiClient _api = ApiClient();
  List<MessageDto> _messages = [];

  List<MessageDto> get messages => _messages;

  Future<void> openChat(int groupId) async {
    _messages = [];
    // 1. Загружаем историю через обычный API
    final response = await _api.dio.get("/Chat/$groupId/messages");
    _messages = (response.data as List).map((json) => MessageDto.fromJson(json)).toList();
    notifyListeners();

    // 2. Подключаем SignalR для новых сообщений
    await _chatService.initSignalR(groupId, (newMessage) {
      _messages.add(newMessage);
      notifyListeners();
    });
  }

  Future<void> sendMessage(int groupId, String content) async {
    if (content.trim().isEmpty) return;
    // Отправляем через API, а SignalR сам «раскидает» это сообщение всем
    await _api.dio.post("/Chat", data: {"groupId": groupId, "content": content});
  }

  void closeChat(int groupId) {
    _chatService.stopConnection(groupId);
  }
}