// lib/services/chat_service.dart
import 'dart:convert';
import '../models/chat_models.dart';
import 'api_services.dart';

class ChatService {
  static const _chatTimeout = Duration(seconds: 60);

  /// POST /api/chat con il JSON di ChatRequest.
  Future<ChatResponse> sendMessage(ChatRequest request) async {
    final response = await ApiService.post(
      '/api/chat',
      jsonEncode(request.toJson()),
      timeout: _chatTimeout,
    );
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ChatResponse.fromJson(json);
  }

  /// GET /api/chat/sessions?limit=$limit&offset=$offset
  /// Restituisce la lista da json['sessions'].
  Future<List<ChatSessionItem>> getSessions({int limit = 30, int offset = 0}) async {
    final response = await ApiService.get(
      '/api/chat/sessions?limit=$limit&offset=$offset',
    );
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final sessionsRaw = json['sessions'] as List<dynamic>? ?? [];
    return sessionsRaw
        .map((s) => ChatSessionItem.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/chat/sessions/$sessionId
  /// Restituisce { 'session': ..., 'messages': [...] }.
  Future<Map<String, dynamic>> getSessionDetail(int sessionId) async {
    final response = await ApiService.get(
      '/api/chat/sessions/$sessionId',
    );
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return json;
  }

  /// DELETE /api/chat/sessions/$sessionId (status 204).
  Future<void> deleteSession(int sessionId) async {
    await ApiService.delete('/api/chat/sessions/$sessionId');
  }
}
