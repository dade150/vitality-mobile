import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/api_services.dart';
import 'error_provider.dart';

/// Stato della chat con il coach. Le risposte arrivano dal backend (`/chat`);
/// la cronologia viene rimandata a ogni richiesta, il BE non salva nulla.
class ChatProvider extends ChangeNotifier with ErrorReporting {
  static const _maxHistory = 30; // = MAX_MESSAGES del BE
  static const _requestTimeout = Duration(seconds: 60);

  final List<ChatMessage> messages = [];
  bool isSending = false;

  /// Si incrementa a ogni [clear]: una risposta che arriva dopo un logout
  /// non deve finire nella conversazione del prossimo utente.
  int _epoch = 0;

  bool get hasMessages => messages.isNotEmpty;

  /// Massimo numero di messaggi di storico inviati al BE: quando la
  /// conversazione si avvicina a questo limite la UI suggerisce una nuova chat.
  int get maxHistory => _maxHistory;

  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending) return false;

    final epoch = _epoch;
    messages.add(ChatMessage(text: trimmed, isUser: true, time: DateTime.now()));
    isSending = true;
    notifyListeners();

    final ok = await guard(() async {
      final res = await ApiService.post(
        '/chat',
        jsonEncode({'messages': _history()}),
        timeout: _requestTimeout,
      );
      // utf8.decode sui bytes: `res.body` senza charset nell'header
      // userebbe latin1 e storpierebbe gli accenti.
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (epoch != _epoch) return; // logout avvenuto nel frattempo
      messages.add(
        ChatMessage(text: json['reply'] as String, isUser: false, time: DateTime.now()),
      );
    }, where: 'ChatProvider.sendMessage');

    if (epoch == _epoch) {
      isSending = false;
      notifyListeners();
    }
    return ok;
  }

  /// Da chiamare al logout: sono dati sanitari, non devono restare in memoria
  /// per l'utente successivo.
  void clear() {
    _epoch++;
    messages.clear();
    isSending = false;
    errorMessage = null;
    notifyListeners();
  }

  List<Map<String, String>> _history() {
    final recent = messages.length > _maxHistory
        ? messages.sublist(messages.length - _maxHistory)
        : messages;
    return [
      for (final m in recent) {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
    ];
  }
}