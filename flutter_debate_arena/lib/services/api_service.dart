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

  Map<String, dynamic> _decodeJson(http.Response response) {
    final raw = response.body.trim();
    final decoded = raw.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map<String, dynamic>);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['detail'] ?? decoded['message'] ?? 'Request failed')
          .toString();
      throw ApiException(statusCode: response.statusCode, message: message);
    }
    return decoded;
  }

  Future<List<String>> getTopicSuggestions() async {
    final r = await http.get(Uri.parse('$_base/topics/suggestions'));
    final data = _decodeJson(r);
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
    final data = _decodeJson(r);
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
    return _decodeJson(r);
  }
    Future<List<Map<String, dynamic>>> getHistory() async {
    final r = await http.get(Uri.parse('$_base/history'));
    return List<Map<String, dynamic>>.from(jsonDecode(r.body) as List);
  }

  Future<String> getTranscript(String sessionId) async {
    final r = await http.get(Uri.parse('$_base/history/$sessionId/transcript'));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['transcript'] as String;
  }
}
