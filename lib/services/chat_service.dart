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

  /// POST /api/chat/stream con Server-Sent Events (SSE).
  /// Emette eventi parsed: delta (`{"type": "delta", "text": "..."}`) e done (`{"type": "done", ...}`).
  Stream<Map<String, dynamic>> streamMessage(ChatRequest request) async* {
    final streamed = await ApiService.postStream(
      '/api/chat/stream',
      jsonEncode(request.toJson()),
      timeout: _chatTimeout,
    );

    final lines = streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('data:')) {
        final jsonStr = trimmed.substring(5).trim();
        if (jsonStr.isNotEmpty) {
          try {
            final parsed = jsonDecode(jsonStr);
            if (parsed is Map<String, dynamic>) {
              yield parsed;
            }
          } catch (_) {
            // Ignora eventuali righe malformate o commenti SSE
          }
        }
      }
    }
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
