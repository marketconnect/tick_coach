import 'dart:async';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { connecting, connected, disconnected, error }

class WebSocketService {
  final String url;
  WebSocketChannel? _channel;
  final StreamController<String> _messageController =
      StreamController.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController.broadcast();
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  final List<String> _pendingMessages = [];

  Stream<String> get messages => _messageController.stream;
  Stream<ConnectionStatus> get status => _statusController.stream;

  WebSocketService(this.url);

  Future<void> connect() async {
    if (_isConnecting || (_channel != null && _channel?.closeCode == null)) {
      return;
    }
    _isConnecting = true;
    _statusController.add(ConnectionStatus.connecting);
    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(url));
      _isConnecting = false;
      _statusController.add(ConnectionStatus.connected);
      _reconnectTimer?.cancel();
      _sendPendingMessages();
      _channel?.stream.listen(
        (message) {
          _messageController.add(message);
        },
        onDone: () {
          _statusController.add(ConnectionStatus.disconnected);
          _reconnect();
        },
        onError: (error) {
          _statusController.add(ConnectionStatus.error);
          _reconnect();
        },
      );
    } catch (e) {
      _isConnecting = false;
      _statusController.add(ConnectionStatus.error);
      _reconnect();
    }
  }

  void _reconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    // Simple exponential backoff could be added here
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  void _sendPendingMessages() {
    if (_channel != null && _channel?.closeCode == null) {
      for (final message in _pendingMessages) {
        _channel?.sink.add(message);
      }
      _pendingMessages.clear();
    }
  }

  void sendMessage(String message) {
    if (_channel != null && _channel?.closeCode == null) {
      _channel?.sink.add(message);
    } else {
      _pendingMessages.add(message);
      connect();
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
  }
}
