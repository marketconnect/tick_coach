import 'dart:async';
import 'dart:math';
import 'dart:convert';
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
    initiateConnection();
  }

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _isWaitingForResponse = false;
  bool get isWaitingForResponse => _isWaitingForResponse;

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  ConnectionStatus get connectionStatus => _connectionStatus;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;

  Future<void> _loadHistory() async {
    final history = await _chatRepository.getChatHistory();
    _messages = history;
    notifyListeners();
  }

  void _subscribeToStreams() {
    // Подписываемся на стримы только один раз
    if (_statusSubscription != null) return;

    _statusSubscription = _chatRepository.status.listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });

    _messageSubscription = _chatRepository.messages.listen((data) {
      _handleAssistantMessage(data);
    });
  }

  void initiateConnection() {
    _subscribeToStreams();
    _chatRepository.connect();
  }

  void _handleAssistantMessage(String data) {
    ChatMessage assistantMessage;
    try {
      // Always try to parse as JSON first
      final decodedJson = jsonDecode(data);
      final type = decodedJson['type'];
      final payload = decodedJson['payload'];

      if (type is String && payload != null) {
        switch (type) {
          case 'error':
            assistantMessage = ChatMessage(
              id: _generateId(),
              sender: MessageSender.assistant,
              timestamp: DateTime.now(),
              type: MessageType.error,
              text: payload.toString(),
            );
            break;
          case 'final_answer':
            assistantMessage = _createTextMessage(payload.toString());
            break;
          case 'training_session':
            try {
              final xmlDocument = XmlDocument.parse(payload.toString());
              final trainingSessionElement = xmlDocument.getElement(
                'TrainingSession',
              );
              if (trainingSessionElement != null) {
                assistantMessage = ChatMessage(
                  id: _generateId(),
                  sender: MessageSender.assistant,
                  timestamp: DateTime.now(),
                  type: MessageType.workout,
                  trainingSession: _parseTrainingSession(
                    trainingSessionElement,
                  ),
                );
              } else {
                // Invalid XML in payload, treat as text
                assistantMessage = _createTextMessage(data);
              }
            } catch (e) {
              // XML parsing failed, treat as text
              assistantMessage = _createTextMessage(data);
            }
            break;
          default:
            // Unknown type, treat original data as text
            assistantMessage = _createTextMessage(data);
        }
      } else {
        // JSON doesn't have the required structure, treat as text
        assistantMessage = _createTextMessage(data);
      }
    } catch (e) {
      // Not a valid JSON, treat as plain text.
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

    final userMessage = ChatMessage(
      id: _generateId(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isWaitingForResponse = true;
    notifyListeners();

    _chatRepository.saveChatMessage(userMessage);
    _chatRepository.sendMessage(text);
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
