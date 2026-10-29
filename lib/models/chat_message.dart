// lib/models/chat_message.dart
import 'proposed_entry.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime time;
  final List<ProposedEntry> proposedEntries;
  final String? attachmentKind;
  final String? attachmentFileName;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    required this.time,
    this.proposedEntries = const [],
    this.attachmentKind,
    this.attachmentFileName,
  }) : id = id ?? 'msg_${DateTime.now().microsecondsSinceEpoch}';

  List<ProposedEntry> get visibleProposals =>
      proposedEntries.where((p) => p.status != ProposalStatus.dismissed).toList();

  factory ChatMessage.fromBackend(Map<String, dynamic> json) {
    final role = (json['role'] ?? json['sender'] ?? 'user').toString().toLowerCase();
    final isUser = role == 'user';
    final text = (json['content'] ?? json['text'] ?? json['message'] ?? '').toString();
    final createdAt = json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    final rawProposals = json['proposed_entries'];
    final proposals = <ProposedEntry>[];
    if (rawProposals is List) {
      for (final p in rawProposals) {
        if (p is Map<String, dynamic>) {
          final entry = ProposedEntry.fromJson(p);
          if (entry != null) proposals.add(entry);
        }
      }
    }

    String? attachmentKind;
    String? attachmentFileName;
    if (json['attachment_kind'] != null) {
      attachmentKind = json['attachment_kind']?.toString();
    } else if (json['attachment_info'] is Map) {
      final info = json['attachment_info'] as Map;
      attachmentKind = info['kind']?.toString();
      attachmentFileName = info['file_name']?.toString() ?? info['filename']?.toString();
    } else if (json['attachment'] is Map) {
      final att = json['attachment'] as Map;
      attachmentKind = att['kind']?.toString();
      attachmentFileName = att['file_name']?.toString() ?? att['filename']?.toString();
    }

    return ChatMessage(
      id: json['id']?.toString(),
      text: text,
      isUser: isUser,
      time: createdAt,
      proposedEntries: proposals,
      attachmentKind: attachmentKind,
      attachmentFileName: attachmentFileName,
    );
  }
}
