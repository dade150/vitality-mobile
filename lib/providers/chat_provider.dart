import 'package:flutter/material.dart';
import '../models/chat_message.dart';

/// Stato della chat con il coach. La risposta del coach è simulata
/// localmente: in produzione andrebbe collegata a un backend/LLM reale.
class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> messages = [];

  bool get hasMessages => messages.isNotEmpty;

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    messages.add(ChatMessage(text: trimmed, isUser: true, time: DateTime.now()));
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 700), () {
      messages.add(ChatMessage(text: _reply(trimmed), isUser: false, time: DateTime.now()));
      notifyListeners();
    });
  }

  String _reply(String userText) {
    const replies = [
      'Grazie per l\'aggiornamento! Continua così.',
      'Ottimo, ricordati di bere a sufficienza durante la giornata.',
      'Hai preso la terapia di oggi? Se serve, posso ricordartelo.',
      'Perfetto, ho annotato tutto nel tuo diario.',
    ];
    return replies[userText.length % replies.length];
  }
}
