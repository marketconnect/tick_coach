import 'package:tick_coach/domain/models/training_session.dart';

enum MessageSender { user, assistant }

enum MessageType { text, workout }

class ChatMessage {
  final String id;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageType type;

  final String? text;
  final TrainingSession? trainingSession;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.timestamp,
    this.type = MessageType.text,
    this.text,
    this.trainingSession,
  }) : assert(
         (type == MessageType.text && text != null) ||
             (type == MessageType.workout && trainingSession != null),
         'Для текстовых сообщений должен быть текст, а для тренировок - trainingSession.',
       );

  // Для простоты в БД будем сохранять только текстовые сообщения
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      text: map['text'],
      sender: MessageSender.values.byName(map['sender']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      type: MessageType.text, // Все сообщения из БД считаем текстовыми
    );
  }
}
