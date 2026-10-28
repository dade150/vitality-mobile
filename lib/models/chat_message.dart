import 'proposed_entry.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime time;
  final List<ProposedEntry> proposedEntries;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    required this.time,
    this.proposedEntries = const [],
  }) : id = id ?? 'msg_${DateTime.now().microsecondsSinceEpoch}';

  List<ProposedEntry> get visibleProposals =>
      proposedEntries.where((p) => p.status != ProposalStatus.dismissed).toList();
}
