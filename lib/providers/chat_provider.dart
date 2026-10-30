// lib/providers/chat_provider.dart
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_models.dart';
import '../models/proposed_entry.dart';
import '../services/chat_service.dart';
import '../services/proposal_service.dart';
import 'error_provider.dart';

/// Stato della chat con il coach. Le risposte e la persistenza arrivano dal backend (`/api/chat`).
/// Gestisce inoltre le proposte di salvataggio clinico Human-in-the-Loop (`proposed_entries`).
class ChatProvider extends ChangeNotifier with ErrorReporting {
  ChatProvider({
    ProposalService? proposalService,
    ChatService? chatService,
  })  : _proposalService = proposalService ?? ProposalService(),
        _chatService = chatService ?? ChatService();

  static const _maxHistory = 30;

  final ProposalService _proposalService;
  final ChatService _chatService;
  final List<ChatMessage> messages = [];
  bool isSending = false;

  /// Identificatore della sessione corrente di chat. Null se nuova sessione.
  int? currentSessionId;
  int? get sessionId => currentSessionId;

  List<ChatSessionItem> sessions = [];
  bool isLoadingSessions = false;
  bool isLoadingSessionDetail = false;

  /// Si incrementa a ogni [clear]: una risposta che arriva dopo un logout
  /// non deve finire nella conversazione del prossimo utente.
  int _epoch = 0;

  bool get hasMessages => messages.isNotEmpty;

  /// Massimo numero di messaggi di storico: quando la conversazione si avvicina a questo
  /// limite la UI suggerisce una nuova chat.
  int get maxHistory => _maxHistory;

  Future<bool> sendMessage(
    String text, {
    ChatAttachmentIn? attachment,
    String? attachmentFileName,
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachment == null) || isSending) return false;

    final epoch = _epoch;
    messages.add(
      ChatMessage(
        text: trimmed,
        isUser: true,
        time: DateTime.now(),
        attachmentKind: attachment?.kind,
        attachmentFileName: attachmentFileName,
      ),
    );
    isSending = true;
    notifyListeners();

    final ok = await guard(() async {
      final request = ChatRequest(
        sessionId: currentSessionId,
        message: trimmed.isNotEmpty ? trimmed : null,
        attachment: attachment,
      );

      // Crea subito un segnaposto per la bolla dell'assistente con stato isStreaming
      final assistantIndex = messages.length;
      messages.add(
        ChatMessage(
          text: '',
          isUser: false,
          time: DateTime.now(),
          isStreaming: true,
        ),
      );
      notifyListeners();

      var accumulatedText = '';
      String? assistantMsgId;
      var proposals = <ProposedEntry>[];
      String? attKind;

      try {
        final stream = _chatService.streamMessage(request);
        await for (final event in stream) {
          if (epoch != _epoch) return;

          final type = event['type']?.toString();
          if (type == 'delta') {
            final deltaText = event['text']?.toString() ?? '';
            accumulatedText += deltaText;
            if (assistantIndex < messages.length) {
              messages[assistantIndex] = messages[assistantIndex].copyWith(
                text: accumulatedText,
                isStreaming: true,
              );
              notifyListeners();
            }
          } else if (type == 'done') {
            final sessId = event['session_id'];
            if (sessId is int) {
              currentSessionId = sessId;
            }
            if (event['assistant_message_id'] != null) {
              assistantMsgId = event['assistant_message_id'].toString();
            }

            final rawProposals = event['proposed_entries'];
            if (rawProposals is List) {
              for (final p in rawProposals) {
                if (p is Map<String, dynamic>) {
                  final entry = ProposedEntry.fromJson(p);
                  if (entry != null) proposals.add(entry);
                }
              }
            }

            if (event['attachment_info'] is Map) {
              attKind = (event['attachment_info'] as Map)['kind']?.toString();
            }

            if (assistantIndex < messages.length) {
              messages[assistantIndex] = messages[assistantIndex].copyWith(
                id: assistantMsgId,
                text: accumulatedText,
                isStreaming: false,
                proposedEntries: proposals,
                attachmentKind: attKind,
              );
              notifyListeners();
            }
          } else if (type == 'error') {
            throw Exception(event['message']?.toString() ?? 'Errore durante la generazione della risposta.');
          }
        }
      } catch (e) {
        // Se si verifica un errore e non avevamo ricevuto testo, rimuoviamo la bolla vuota
        if (assistantIndex < messages.length && accumulatedText.isEmpty) {
          messages.removeAt(assistantIndex);
          notifyListeners();
        } else if (assistantIndex < messages.length) {
          messages[assistantIndex] = messages[assistantIndex].copyWith(isStreaming: false);
          notifyListeners();
        }
        rethrow;
      }
    }, where: 'ChatProvider.sendMessage');

    if (epoch == _epoch) {
      isSending = false;
      notifyListeners();
    }
    return ok;
  }

  /// Carica le sessioni di chat passate dall'API
  Future<void> loadSessions({int limit = 30, int offset = 0}) async {
    isLoadingSessions = true;
    notifyListeners();

    await guard(() async {
      sessions = await _chatService.getSessions(limit: limit, offset: offset);
    }, where: 'ChatProvider.loadSessions');

    isLoadingSessions = false;
    notifyListeners();
  }

  /// Carica i dettagli di una sessione specifica e ripristina la cronologia a schermo
  Future<bool> loadSession(int targetSessionId) async {
    isLoadingSessionDetail = true;
    notifyListeners();
    final epoch = _epoch;

    final ok = await guard(() async {
      final detail = await _chatService.getSessionDetail(targetSessionId);
      if (epoch != _epoch) return;

      messages.clear();
      final rawMsgs = detail['messages'] as List<dynamic>? ?? [];
      for (final m in rawMsgs) {
        if (m is Map<String, dynamic>) {
          messages.add(ChatMessage.fromBackend(m));
        }
      }
      currentSessionId = targetSessionId;
    }, where: 'ChatProvider.loadSession');

    if (epoch == _epoch) {
      isLoadingSessionDetail = false;
      notifyListeners();
    }
    return ok;
  }

  /// Elimina una sessione specifica sia da backend che dallo stato locale
  Future<bool> deleteSession(int targetSessionId) async {
    final ok = await guard(() async {
      await _chatService.deleteSession(targetSessionId);
      sessions.removeWhere((s) => s.id == targetSessionId);
      if (currentSessionId == targetSessionId) {
        newChat();
      }
    }, where: 'ChatProvider.deleteSession');

    notifyListeners();
    return ok;
  }

  /// Aggiorna i dati in bozza modificati dall'utente (previene la perdita di dati durante lo scroll)
  void updateProposalDraft(String messageId, String proposalId, Map<String, dynamic> updatedData) {
    final msg = _findMessage(messageId);
    if (msg == null) return;

    for (final p in msg.proposedEntries) {
      if (p.proposalId == proposalId) {
        p.data.addAll(updatedData);
        notifyListeners();
        return;
      }
    }
  }

  /// Annulla / ignora la proposta rimuovendola dalla visualizzazione
  void dismissProposal(String messageId, String proposalId) {
    final msg = _findMessage(messageId);
    if (msg == null) return;

    for (final p in msg.proposedEntries) {
      if (p.proposalId == proposalId) {
        p.status = ProposalStatus.dismissed;
        notifyListeners();
        return;
      }
    }
  }

  /// Conferma e salva la proposta direttamente su Supabase
  Future<bool> confirmProposal(
    String messageId,
    String proposalId,
    Map<String, dynamic> finalData,
  ) async {
    final msg = _findMessage(messageId);
    if (msg == null) return false;

    ProposedEntry? targetProposal;
    for (final p in msg.proposedEntries) {
      if (p.proposalId == proposalId) {
        targetProposal = p;
        break;
      }
    }

    if (targetProposal == null ||
        targetProposal.status == ProposalStatus.saving ||
        targetProposal.status == ProposalStatus.saved) {
      return false;
    }

    final epoch = _epoch;
    targetProposal.status = ProposalStatus.saving;
    targetProposal.saveError = null;
    notifyListeners();

    try {
      await _proposalService.saveProposal(targetProposal.targetTable, finalData);
      if (epoch != _epoch) return false;

      targetProposal.data.clear();
      targetProposal.data.addAll(finalData);
      targetProposal.status = ProposalStatus.saved;
      targetProposal.saveError = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (epoch != _epoch) return false;
      targetProposal.status = ProposalStatus.pending;
      targetProposal.saveError =
          e is ArgumentError ? e.message?.toString() : e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  ChatMessage? _findMessage(String messageId) {
    for (final m in messages) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  /// Avvia una nuova sessione di chat: imposta [currentSessionId] a null e cancella la cronologia a schermo.
  void newChat() {
    currentSessionId = null;
    clear();
  }

  /// Da chiamare al logout: sono dati sanitari, non devono restare in memoria per l'utente successivo.
  void clear() {
    _epoch++;
    currentSessionId = null;
    messages.clear();
    isSending = false;
    errorMessage = null;
    notifyListeners();
  }
}
