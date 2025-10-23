import 'dart:async';

import 'package:tick_coach/data/datasources/database_helper.dart';
import 'package:tick_coach/data/services/websocket_service.dart';
import 'package:tick_coach/domain/models/chat_message.dart';
import 'package:tick_coach/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final WebSocketService _webSocketService;
  final DatabaseHelper _databaseHelper;

  ChatRepositoryImpl(this._webSocketService, this._databaseHelper);

  @override
  Future<void> connect() {
    return _webSocketService.connect();
  }

  @override
  void dispose() {
    _webSocketService.dispose();
  }

  @override
  Future<List<ChatMessage>> getChatHistory() {
    return _databaseHelper.getChatMessages();
  }

  @override
  Stream<String> get messages => _webSocketService.messages;

  @override
  Future<void> saveChatMessage(ChatMessage message) {
    return _databaseHelper.saveChatMessage(message);
  }

  @override
  void sendMessage(String message) {
    _webSocketService.sendMessage(message);
  }

  @override
  Stream<ConnectionStatus> get status => _webSocketService.status;

  @override
  Future<void> deleteOldChatMessages() {
    return _databaseHelper.deleteOldChatMessages();
  }
}
