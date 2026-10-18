import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/pill_button.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _greetings = [
    'Come posso aiutarti oggi?',
    'Come va oggi?',
    'Hai fatto un po\' di movimento oggi?',
    'Cosa hai mangiato oggi?',
    'Come ti senti oggi?',
    'Hai bevuto abbastanza acqua oggi?',
    'Un piccolo passo alla volta: come posso aiutarti?',
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Lazy: con l'hot reload initState non viene ri-eseguito sugli stati già
  // vivi, un late assegnato lì andrebbe in LateInitializationError.
  late final String _greeting = _greetings[math.Random().nextInt(_greetings.length)];

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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          label: 'Impostazioni',
                          icon: Icons.settings_outlined,
                          onTap: () => Navigator.of(context).pushNamed('/settings'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PillButton(
                          label: 'Profilo',
                          icon: Icons.person_outline_rounded,
                          onTap: () => Navigator.of(context).pushNamed('/profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                      : _ChatEmptyState(greeting: _greeting),
                ),
              ),
            ),
            // "Nuova chat": compare solo quando il contesto sta per esaurirsi
            // (>= 80% dello storico massimo), come promemoria discreto sopra
            // l'input. Logica del reset da aggiungere dopo.
            if (chat.hasMessages && chat.messages.length >= (chat.maxHistory * 0.8).round())
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {}, // TODO: logica nuova sessione
                          icon: const Icon(Icons.add_comment_outlined, size: 18),
                          label: const Text('Nuova chat'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            visualDensity: VisualDensity.compact,
                            textStyle: theme.textTheme.labelMedium,
                          ),
                        ),
                      ],
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

/// Stato vuoto della chat: gradiente che orbita dolcemente, orbs sfocati e
/// saluto casuale scelto all'apertura. Solo visuale, nessuna logica chat.
class _ChatEmptyState extends StatefulWidget {
  final String greeting;
  const _ChatEmptyState({required this.greeting});

  @override
  State<_ChatEmptyState> createState() => _ChatEmptyStateState();
}

class _ChatEmptyStateState extends State<_ChatEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Solo lo sfondo viene ridisegnato a ogni frame (RepaintBoundary +
    // CustomPainter): icona e testo restano statici, la UI resta reattiva.
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
              painter: _OrbBackgroundPainter(
                t: _ctrl.value * 2 * math.pi,
                isDark: isDark,
                cs: cs,
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 48, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  widget.greeting,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sfondo animato della chat vuota: lavaggio di gradiente che orbita e tre
/// orbs sfumati (posizioni frazionarie, visibili su qualsiasi schermo).
class _OrbBackgroundPainter extends CustomPainter {
  final double t;
  final bool isDark;
  final ColorScheme cs;

  _OrbBackgroundPainter({required this.t, required this.isDark, required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Lavaggio di colore che si muove dolcemente.
    final washCenter = Offset(
      w * 0.5 + math.sin(t) * w * 0.12,
      h * 0.3 + math.cos(t * 0.8) * h * 0.1,
    );
    final washPaint = Paint()
      ..shader = RadialGradient(
        radius: 1.3,
        colors: [
          (isDark ? cs.primary : AppColors.lightPeach)
              .withValues(alpha: isDark ? 0.22 : 0.75),
          cs.surface.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: washCenter, radius: math.max(w, h)));
    canvas.drawRect(Offset.zero & size, washPaint);

    // Orb sfumato: gradiente radiale che va dal colore a trasparente.
    void orb(Offset base, double radius, Color color, double phaseX, double phaseY) {
      final c = base +
          Offset(math.sin(t + phaseX) * w * 0.04, math.cos(t * 0.8 + phaseY) * h * 0.03);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: radius));
      canvas.drawCircle(c, radius, paint);
    }

    orb(
      Offset(w * 0.18, h * 0.2),
      w * 0.28,
      cs.primary.withValues(alpha: 0.16),
      0,
      0.7,
    );
    orb(
      Offset(w * 0.82, h * 0.5),
      w * 0.24,
      cs.secondary.withValues(alpha: 0.13),
      0.9,
      0.6,
    );
    orb(
      Offset(w * 0.45, h * 0.85),
      w * 0.32,
      cs.tertiary.withValues(alpha: 0.11),
      0.5,
      1.2,
    );
  }

  @override
  bool shouldRepaint(_OrbBackgroundPainter old) =>
      old.t != t || old.isDark != isDark || old.cs != cs;
}