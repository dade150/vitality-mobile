// lib/models/chat_models.dart

/// Input allegato opzionale per la richiesta di chat
class ChatAttachmentIn {
  final String kind; // 'meal_photo', 'glucometer_photo', 'medical_report', 'generic_image', 'pdf_document'
  final String mimeType; // 'image/jpeg', 'image/png', 'image/webp', 'application/pdf'
  final String dataBase64;

  ChatAttachmentIn({
    required this.kind,
    required this.mimeType,
    required this.dataBase64,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'mime_type': mimeType,
    'data_base64': dataBase64,
  };

  factory ChatAttachmentIn.fromJson(Map<String, dynamic> json) => ChatAttachmentIn(
    kind: json['kind'] ?? 'generic_image',
    mimeType: json['mime_type'] ?? 'image/jpeg',
    dataBase64: json['data_base64'] ?? '',
  );
}

/// Nuova richiesta POST /api/chat
class ChatRequest {
  final int? sessionId; // null per nuova chat, altrimenti l'ID della sessione attiva
  final String? message;
  final ChatAttachmentIn? attachment;

  ChatRequest({
    this.sessionId,
    this.message,
    this.attachment,
  });

  Map<String, dynamic> toJson() => {
    if (sessionId != null) 'session_id': sessionId,
    if (message != null) 'message': message,
    if (attachment != null) 'attachment': attachment!.toJson(),
  };
}

/// Nuova risposta ChatResponse
class ChatResponse {
  final String reply;
  final int? sessionId;
  final int? userMessageId;
  final int? assistantMessageId;
  final List<dynamic> proposedEntries;
  final Map<String, dynamic>? attachmentInfo;

  ChatResponse({
    required this.reply,
    this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
    this.proposedEntries = const [],
    this.attachmentInfo,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    reply: json['reply'] ?? '',
    sessionId: json['session_id'],
    userMessageId: json['user_message_id'],
    assistantMessageId: json['assistant_message_id'],
    proposedEntries: json['proposed_entries'] ?? [],
    attachmentInfo: json['attachment_info'] != null
        ? Map<String, dynamic>.from(json['attachment_info'] as Map)
        : null,
  );
}

/// Modello Sessione per la cronologia
class ChatSessionItem {
  final int id;
  final String? title;
  final DateTime createdAt;

  ChatSessionItem({required this.id, this.title, required this.createdAt});

  factory ChatSessionItem.fromJson(Map<String, dynamic> json) => ChatSessionItem(
    id: json['id'],
    title: json['title'],
    createdAt: DateTime.parse(json['created_at']),
  );
}
