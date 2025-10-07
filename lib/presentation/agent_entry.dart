import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tick_coach/domain/models/chat_message.dart';
import 'package:tick_coach/utils/database_helper.dart';
import 'package:tick_coach/utils/websocket_service.dart';

class AgentEntry extends StatefulWidget {
  const AgentEntry({super.key});
  @override
  State<AgentEntry> createState() => _AgentEntryState();
}

class _AgentEntryState extends State<AgentEntry> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  late final WebSocketService _webSocketService;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;

  bool _isWaitingForResponse = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;

  @override
  void initState() {
    super.initState();
    _webSocketService = WebSocketService(
      'wss://d5dugiqufgjq0ntb4i16.laqt4bj7.apigw.yandexcloud.net/ws',
    );
    _loadHistoryAndConnect();
  }

  Future<void> _loadHistoryAndConnect() async {
    final history = await DatabaseHelper.instance.getChatMessages();
    setState(() {
      _messages.addAll(history);
    });
    _connect();
  }

  void _connect() {
    _statusSubscription = _webSocketService.status.listen((status) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = status;
      });
      if (status == ConnectionStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка соединения. Попытка переподключения...'),
          ),
        );
      }
    });

    _messageSubscription = _webSocketService.messages.listen((text) {
      if (!mounted) return;
      final assistantMessage = ChatMessage(
        id: _generateId(),
        text: text,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
      );
      DatabaseHelper.instance.saveChatMessage(assistantMessage);
      setState(() {
        _isWaitingForResponse = false;
        _messages.add(assistantMessage);
      });
      _scrollToBottom();
    });

    _webSocketService.connect();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isWaitingForResponse) return;

    HapticFeedback.selectionClick();

    final userMessage = ChatMessage(
      id: _generateId(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    DatabaseHelper.instance.saveChatMessage(userMessage);
    _webSocketService.sendMessage(text);

    setState(() {
      _messages.add(userMessage);
      _isWaitingForResponse = true;
    });

    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildStatusIndicator(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + (_isWaitingForResponse ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isWaitingForResponse && index == _messages.length) {
                  return const _TypingIndicator();
                }
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          const SizedBox(height: 8),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_connectionStatus == ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }
    String text;
    Color color;
    switch (_connectionStatus) {
      case ConnectionStatus.connecting:
        text = 'Подключение...';
        color = Colors.orange;
        break;
      case ConnectionStatus.disconnected:
        text = 'Отключено';
        color = Colors.grey;
        break;
      case ConnectionStatus.error:
        text = 'Ошибка соединения';
        color = Colors.red;
        break;
      case ConnectionStatus.connected:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'I want…',
              prefixIcon: Icon(Icons.auto_awesome),
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _isWaitingForResponse ? null : _sendMessage,
          icon: const Icon(Icons.send),
          tooltip: 'Отправить',
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUserMessage = message.sender == MessageSender.user;
    final alignment = isUserMessage
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = isUserMessage
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: alignment,
      child: Card(
        color: color,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SelectableText(message.text),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text('ассистент печатает...'), // Simple text for now
        ),
      ),
    );
  }
}
