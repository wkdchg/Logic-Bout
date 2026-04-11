import 'dart:convert';
import 'package:http/http.dart' as http;

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

  Future<List<String>> getTopicSuggestions() async {
    final r = await http.get(Uri.parse('$_base/topics/suggestions'));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
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
    final data = jsonDecode(r.body) as Map<String, dynamic>;
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
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
