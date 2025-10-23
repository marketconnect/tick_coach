import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tick_coach/data/services/websocket_service.dart';

import 'package:tick_coach/domain/models/chat_message.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/chat_repository.dart';
import 'package:xml/xml.dart';

class AgentEntryNotifier extends ChangeNotifier {
  final ChatRepository _chatRepository;

  AgentEntryNotifier(this._chatRepository) {
    _loadHistory();
  }

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _isWaitingForResponse = false;
  bool get isWaitingForResponse => _isWaitingForResponse;

  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;
  ConnectionStatus get connectionStatus => _connectionStatus;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;
  bool _connectionAttempted = false;

  Future<void> _loadHistory() async {
    final history = await _chatRepository.getChatHistory();
    _messages = history;
    notifyListeners();
  }

  void _connect() {
    if (_connectionAttempted) {
      return;
    }
    _connectionAttempted = true;
    _statusSubscription = _chatRepository.status.listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });

    _messageSubscription = _chatRepository.messages.listen((data) {
      _handleAssistantMessage(data);
    });

    _chatRepository.connect();
  }

  void initiateConnection() {
    _connect();
  }

  void _handleAssistantMessage(String data) {
    ChatMessage assistantMessage;
    try {
      final xmlDocument = XmlDocument.parse(data);
      final trainingSessionElement = xmlDocument.getElement('TrainingSession');
      if (trainingSessionElement != null) {
        assistantMessage = ChatMessage(
          id: _generateId(),
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
          type: MessageType.workout,
          trainingSession: _parseTrainingSession(trainingSessionElement),
        );
      } else {
        assistantMessage = _createTextMessage(data);
      }
    } catch (e) {
      assistantMessage = _createTextMessage(data);
    }

    if (assistantMessage.type == MessageType.text) {
      _chatRepository.saveChatMessage(assistantMessage);
    }

    _isWaitingForResponse = false;
    _messages.add(assistantMessage);
    notifyListeners();
  }

  TrainingSession _parseTrainingSession(XmlElement trainingSessionElement) {
    return TrainingSession(
      id: trainingSessionElement.getAttribute('id') ?? _generateId(),
      name: trainingSessionElement.getAttribute('name') ?? 'Новая тренировка',
      blocks: trainingSessionElement.findElements('Block').map((blockElement) {
        return Block(
          id: _generateId(),
          type: blockElement.getAttribute('type') ?? 'Unknown',
          label: blockElement.getAttribute('label'),
          sets: blockElement.findElements('Set').map((setElement) {
            final repeatCount =
                int.tryParse(
                  setElement.getElement('Repeat')?.getAttribute('rounds') ??
                      '1',
                ) ??
                1;
            return Set(
              id: _generateId(),
              label: setElement.getAttribute('label'),
              repeat: repeatCount,
              items: setElement.childElements
                  .where((el) => ['Exercise', 'Rest'].contains(el.name.local))
                  .map((itemElement) {
                    if (itemElement.name.local == 'Exercise') {
                      return Exercise(
                        id: _generateId(),
                        name: itemElement.getAttribute('name') ?? 'Упражнение',
                        modality: itemElement.getAttribute('modality'),
                        equipment: itemElement.getAttribute('equipment'),
                        loadKg: double.tryParse(
                          itemElement.getAttribute('load_kg') ?? '',
                        ),
                        tempo: itemElement.getAttribute('tempo'),
                      );
                    } else {
                      return Rest(
                        id: _generateId(),
                        durationSec:
                            int.tryParse(
                              itemElement.getAttribute('seconds') ?? '0',
                            ) ??
                            0,
                        reason: itemElement.getAttribute('reason'),
                      );
                    }
                  })
                  .toList(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  ChatMessage _createTextMessage(String text) {
    return ChatMessage(
      id: _generateId(),
      text: text,
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
    );
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty || _isWaitingForResponse) return;
    initiateConnection();
    final userMessage = ChatMessage(
      id: _generateId(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
    _chatRepository.saveChatMessage(userMessage);
    _chatRepository.sendMessage(text);
    _messages.add(userMessage);
    _isWaitingForResponse = true;
    notifyListeners();
  }

  Future<void> clearOldMessages() async {
    await _chatRepository.deleteOldChatMessages();
    await _loadHistory();
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}
