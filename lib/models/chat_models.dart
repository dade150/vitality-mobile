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

/// Azione suggerita dall'assistente (es. apertura esportazione Report Medico PDF).
class ChatSuggestedAction {
  final String type;
  final int months;

  const ChatSuggestedAction({
    required this.type,
    this.months = 3,
  });

  static ChatSuggestedAction? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final type = raw['type']?.toString().trim();
    if (type != 'export_pdf_summary') return null;

    final rawMonths = raw['months'];
    int parsedMonths = 3;
    if (rawMonths is num) {
      parsedMonths = rawMonths.toInt();
    } else if (rawMonths != null) {
      parsedMonths = int.tryParse(rawMonths.toString()) ?? 3;
    }
    if (parsedMonths != 2 && parsedMonths != 3 && parsedMonths != 4) {
      parsedMonths = 3;
    }

    return ChatSuggestedAction(type: type!, months: parsedMonths);
  }
}

/// Nuova risposta ChatResponse
class ChatResponse {
  final String reply;
  final int? sessionId;
  final int? userMessageId;
  final int? assistantMessageId;
  final List<dynamic> proposedEntries;
  final Map<String, dynamic>? attachmentInfo;
  final bool isEmergency;
  final String? guardrailCategory;
  final ChatSuggestedAction? suggestedAction;

  ChatResponse({
    required this.reply,
    this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
    this.proposedEntries = const [],
    this.attachmentInfo,
    this.isEmergency = false,
    this.guardrailCategory,
    this.suggestedAction,
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
    isEmergency: json['is_emergency'] == true,
    guardrailCategory: json['guardrail_category']?.toString(),
    suggestedAction: ChatSuggestedAction.tryFromJson(json['suggested_action']),
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
