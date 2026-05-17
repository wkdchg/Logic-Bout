import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static const int _port = 8000;
  static const bool _useAndroidEmulatorHost = bool.fromEnvironment(
    'ANDROID_EMULATOR',
    defaultValue: false,
  );
  static const String _apiHostFromEnv = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get _host {
    if (_apiHostFromEnv.isNotEmpty) return _apiHostFromEnv;
    if (kIsWeb) return 'localhost';
    if (defaultTargetPlatform == TargetPlatform.android && _useAndroidEmulatorHost) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  static String get _baseWs => 'ws://$_host:$_port';

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
