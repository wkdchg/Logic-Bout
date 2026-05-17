import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class DebateSession {
  final String sessionId;
  final String topic;
  final int totalRounds;

  const DebateSession({
    required this.sessionId,
    required this.topic,
    required this.totalRounds,
  });
}

class ApiService {
  static const int _port = 8000;
  static const Duration _timeout = Duration(seconds: 20);
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

  static String get _base => 'http://$_host:$_port';

  void _throwIfNotSuccess(http.Response response, Object? decoded) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Request failed';
    if (decoded is Map<String, dynamic>) {
      message = (decoded['detail'] ?? decoded['message'] ?? message).toString();
    }
    throw ApiException(statusCode: response.statusCode, message: message);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final raw = response.body.trim();
    final decoded = raw.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map<String, dynamic>);
    _throwIfNotSuccess(response, decoded);
    return decoded;
  }

  List<dynamic> _decodeList(http.Response response) {
    final raw = response.body.trim();
    final decoded = raw.isEmpty ? <dynamic>[] : jsonDecode(raw);
    _throwIfNotSuccess(response, decoded);
    if (decoded is List<dynamic>) return decoded;
    throw const ApiException(statusCode: 500, message: 'Invalid response format');
  }

  Future<List<String>> getTopicSuggestions() async {
    final r = await _get('$_base/topics/suggestions');
    final data = _decodeObject(r);
    return List<String>.from(data['topics'] as List);
  }

  Future<DebateSession> startDebate({
    required String topic,
    required String userPosition,
    int totalRounds = 5,
  }) async {
    final r = await _post(
      '$_base/debate/start',
      body: {
        'topic': topic,
        'user_position': userPosition,
        'total_rounds': totalRounds,
      },
    );
    final data = _decodeObject(r);
    return DebateSession(
      sessionId: data['session_id'] as String,
      topic: data['topic'] as String,
      totalRounds: data['total_rounds'] as int,
    );
  }

  Future<Map<String, dynamic>> getAnalysis(String sessionId) async {
    final r = await _get('$_base/debate/$sessionId/analysis');
    return _decodeObject(r);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final r = await _get('$_base/history');
    final data = _decodeList(r);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> getTranscript(String sessionId) async {
    final r = await _get('$_base/history/$sessionId/transcript');
    final data = _decodeObject(r);
    return data['transcript'] as String;
  }

  Future<http.Response> _get(String url) async {
    try {
      return await http.get(Uri.parse(url)).timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Не вдалося підключитися до сервера ($_host:$_port): $e',
      );
    }
  }

  Future<http.Response> _post(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    try {
      return await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Не вдалося підключитися до сервера ($_host:$_port): $e',
      );
    }
  }
}
