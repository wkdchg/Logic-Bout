import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum DebateMessageType { turnStart, token, turnEnd, error }

class DebateMessage {
  final DebateMessageType type;
  final String? text;
  final int? round;
  final bool? isFinished;
  final String? errorMessage;

  const DebateMessage({
    required this.type,
    this.text,
    this.round,
    this.isFinished,
    this.errorMessage,
  });

  factory DebateMessage.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'turn_start' => DebateMessage(
          type: DebateMessageType.turnStart,
          round: json['round'] as int,
        ),
      'token' => DebateMessage(
          type: DebateMessageType.token,
          text: json['text'] as String,
        ),
      'turn_end' => DebateMessage(
          type: DebateMessageType.turnEnd,
          round: json['round'] as int,
          isFinished: json['is_finished'] as bool,
        ),
      'error' => DebateMessage(
          type: DebateMessageType.error,
          errorMessage: json['message'] as String,
        ),
      _ => const DebateMessage(type: DebateMessageType.error, errorMessage: 'Unknown message'),
    };
  }
}

class WebSocketService {
  static const String _baseWs = 'ws://localhost:8000';
  /// For HTTP requests (if needed in the future)
  static const String _baseHttp = 'http://localhost:8000';

  WebSocketChannel? _channel;
  final _messageController = StreamController<DebateMessage>.broadcast();

  Stream<DebateMessage> get messages => _messageController.stream;

  void connect(String sessionId) {
    _channel?.sink.close();
    _channel = WebSocketChannel.connect(
      Uri.parse('$_baseWs/ws/debate/$sessionId'),
    );
    _channel!.stream.listen(
      (raw) {
        final json = jsonDecode(raw as String) as Map<String, dynamic>;
        _messageController.add(DebateMessage.fromJson(json));
      },
      onError: (e) => _messageController.add(
        DebateMessage(type: DebateMessageType.error, errorMessage: e.toString()),
      ),
    );
  }

  void sendArgument(String text) {
    _channel?.sink.add(jsonEncode({'type': 'argument', 'text': text}));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
