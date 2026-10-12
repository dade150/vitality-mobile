import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final chat = context.read<ChatProvider>();
    final text = _controller.text;
    if (text.trim().isEmpty || chat.isSending) return;
    _controller.clear();

    // La parte sincrona di sendMessage aggiunge già il messaggio utente.
    final pending = chat.sendMessage(text);
    _scrollToEnd();
    final ok = await pending;
    if (!mounted) return;
    _scrollToEnd();
    if (!ok && chat.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chat.errorMessage!)));
    }
  }

  Widget _bubble({
    required ThemeData theme,
    required bool isUser,
    required Widget child,
  }) {
    final cs = theme.colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Impostazioni',
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
        title: const Text('Chat Coach'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: chat.hasMessages
                      ? ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          // +1: bolla di caricamento mentre si aspetta la risposta
                          itemCount: chat.messages.length + (chat.isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chat.messages.length) {
                              return _bubble(
                                theme: theme,
                                isUser: false,
                                child: const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            final message = chat.messages[index];
                            return _bubble(
                              theme: theme,
                              isUser: message.isUser,
                              child: Text(
                                message.text,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: message.isUser ? cs.onPrimary : cs.onSurface,
                                ),
                              ),
                            );
                          },
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.psychology_outlined, size: 56, color: cs.secondary),
                              const SizedBox(height: 16),
                              Text(
                                'Ciao! Scrivi un messaggio o usa il microfono per iniziare a chattare con il tuo coach.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            // Nota: il pulsante "+" di allegato è stato rimosso su richiesta,
            // resta solo il campo di testo, il microfono e l'invio.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(hintText: 'Scrivi un messaggio...'),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: FloatingActionButton(
                          heroTag: 'mic',
                          onPressed: () {},
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.mic_rounded, color: cs.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: FloatingActionButton(
                          heroTag: 'send',
                          onPressed: chat.isSending ? null : _send,
                          backgroundColor: cs.primary,
                          child: Icon(Icons.send_rounded, color: cs.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}