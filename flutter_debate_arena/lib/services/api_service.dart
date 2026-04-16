import 'dart:convert';
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
  static const String _base = 'http://localhost:8000';

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
    final r = await http.get(Uri.parse('$_base/topics/suggestions'));
    final data = _decodeObject(r);
    return List<String>.from(data['topics'] as List);
  }

  Future<DebateSession> startDebate({
    required String topic,
    required String userPosition,
    int totalRounds = 5,
  }) async {
    final r = await http.post(
      Uri.parse('$_base/debate/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'topic': topic,
        'user_position': userPosition,
        'total_rounds': totalRounds,
      }),
    );
    final data = _decodeObject(r);
    return DebateSession(
      sessionId: data['session_id'] as String,
      topic: data['topic'] as String,
      totalRounds: data['total_rounds'] as int,
    );
  }

  Future<Map<String, dynamic>> getAnalysis(String sessionId) async {
    final r = await http.get(
      Uri.parse('$_base/debate/$sessionId/analysis'),
    );
    return _decodeObject(r);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final r = await http.get(Uri.parse('$_base/history'));
    final data = _decodeList(r);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> getTranscript(String sessionId) async {
    final r = await http.get(Uri.parse('$_base/history/$sessionId/transcript'));
    final data = _decodeObject(r);
    return data['transcript'] as String;
  }
}
