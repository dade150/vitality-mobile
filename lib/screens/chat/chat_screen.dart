import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/proposed_entry.dart';
import '../../providers/appointments_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/clinical_proposal_card.dart';
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

  /// Predisposizione per l'input vocale Speech-to-Text (STT) futuro.
  void onVoiceTranscriptReceived(String transcript, {bool autoSend = false}) {
    final text = transcript.trim();
    if (text.isEmpty) return;
    if (autoSend) {
      _controller.text = text;
      _send();
    } else {
      setState(() {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      });
    }
  }

  void _refreshDomainProvider(TargetTable table) {
    switch (table) {
      case TargetTable.diabetesData:
        unawaited(context.read<HealthProvider>().refresh());
        unawaited(context.read<ClinicalProvider>().refresh());
        break;
      case TargetTable.meals:
      case TargetTable.physicalActivities:
      case TargetTable.therapyLogs:
      case TargetTable.therapies:
        unawaited(context.read<HealthProvider>().refresh());
        break;
      case TargetTable.appointments:
        unawaited(context.read<AppointmentsProvider>().refresh());
        break;
      case TargetTable.profile:
        unawaited(context.read<ProfileProvider>().refresh());
        break;
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
      body: _AnimatedChatBackground(
        child: SafeArea(
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
                              if (message.isUser) {
                                return _bubble(
                                  theme: theme,
                                  isUser: true,
                                  child: Text(
                                    message.text,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _bubble(
                                    theme: theme,
                                    isUser: false,
                                    child: Text(
                                      message.text,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (message.visibleProposals.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 480),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (final proposal in message.visibleProposals)
                                              ClinicalProposalCard(
                                                key: ValueKey('${message.id}_${proposal.proposalId}'),
                                                messageId: message.id,
                                                proposal: proposal,
                                                onDismiss: () => chat.dismissProposal(message.id, proposal.proposalId),
                                                onConfirm: (finalData) async {
                                                  final ok = await chat.confirmProposal(
                                                    message.id,
                                                    proposal.proposalId,
                                                    finalData,
                                                  );
                                                  if (ok && mounted) {
                                                    _refreshDomainProvider(proposal.targetTable);
                                                  }
                                                  return ok;
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          )
                        : _ChatGreeting(greeting: _greeting),
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
              // Barra di inserimento messaggio, microfono e invio.
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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Supporto vocale predisposto: tocca e parla (STT).'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
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
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}

/// Sfondo animato a tutto schermo che copre l'intera schermata della chat:
/// lavaggio di gradiente orbitante, orbs sfumati e onde morbide sul fondo.
/// Avvolge la SafeArea e tutti i controlli (bottoni in alto e barra di input in basso).
class _AnimatedChatBackground extends StatefulWidget {
  final Widget child;
  const _AnimatedChatBackground({required this.child});

  @override
  State<_AnimatedChatBackground> createState() => _AnimatedChatBackgroundState();
}

class _AnimatedChatBackgroundState extends State<_AnimatedChatBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = disableAnimations ? 0.0 : _controller.value * 2 * math.pi;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _OrbBackgroundPainter(t: t, isDark: isDark, cs: cs),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

/// Contenuto centrale dello stato vuoto della chat: icona pulsante che "respira"
/// e messaggio di saluto casuale.
class _ChatGreeting extends StatefulWidget {
  final String greeting;
  const _ChatGreeting({required this.greeting});

  @override
  State<_ChatGreeting> createState() => _ChatGreetingState();
}

class _ChatGreetingState extends State<_ChatGreeting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final pulse = _controller.value;
                return SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.92 + pulse * 0.22,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.withValues(
                              alpha: (isDark ? 0.18 : 0.14) * (1.15 - pulse * 0.35),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? cs.primaryContainer.withValues(alpha: 0.35)
                              : AppColors.lightPeach,
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 36,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              widget.greeting,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sfondo animato della chat: lavaggio di gradiente che orbita, quattro
/// orbs sfumati con effetto respiro e due onde sinusoidali morbide sul fondo.
/// Tutte le armoniche usano multipli interi di `t` (0..2π) per un loop continuo
/// senza alcuno scatto.
class _OrbBackgroundPainter extends CustomPainter {
  final double t;
  final bool isDark;
  final ColorScheme cs;

  _OrbBackgroundPainter({required this.t, required this.isDark, required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shortest = math.min(w, h);

    // 0. Base uniforme del canvas con il colore della superficie.
    canvas.drawRect(Offset.zero & size, Paint()..color = cs.surface);

    // 1. Lavaggio di colore di fondo che si muove dolcemente.
    final washCenter = Offset(
      w * 0.5 + math.sin(t) * w * 0.22,
      h * 0.32 + math.cos(t) * h * 0.14,
    );
    final washPaint = Paint()
      ..shader = RadialGradient(
        radius: 1.15,
        colors: [
          (isDark ? cs.primary : AppColors.lightPeach)
              .withValues(alpha: isDark ? 0.28 : 0.85),
          cs.surface.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: washCenter, radius: math.max(w, h) * 0.9));
    canvas.drawRect(Offset.zero & size, washPaint);

    // 2. Orbs sfumati con traiettoria fluida (Lissajous) ed effetto respiro.
    void orb({
      required Offset base,
      required double baseRadius,
      required Color color,
      required double phaseX,
      required double phaseY,
      int freqX = 1,
      int freqY = 1,
    }) {
      final center = base +
          Offset(
            math.sin(t * freqX + phaseX) * w * 0.15,
            math.cos(t * freqY + phaseY) * h * 0.11,
          );
      final breathingRadius =
          baseRadius * (0.9 + 0.16 * math.sin(t * 2 + phaseX));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: breathingRadius));
      canvas.drawCircle(center, breathingRadius, paint);
    }

    // Orb caldo arancio in alto a sinistra
    orb(
      base: Offset(w * 0.22, h * 0.24),
      baseRadius: shortest * 0.45,
      color: AppColors.vibrantOrange.withValues(alpha: isDark ? 0.26 : 0.24),
      phaseX: 0.0,
      phaseY: 0.6,
      freqX: 1,
      freqY: 2,
    );
    // Orb verde salvia a destra
    orb(
      base: Offset(w * 0.80, h * 0.44),
      baseRadius: shortest * 0.42,
      color: cs.secondary.withValues(alpha: isDark ? 0.24 : 0.20),
      phaseX: 1.4,
      phaseY: 0.9,
      freqX: 2,
      freqY: 1,
    );
    // Orb azzurro in basso al centro-sinistra
    orb(
      base: Offset(w * 0.38, h * 0.76),
      baseRadius: shortest * 0.48,
      color: cs.tertiary.withValues(alpha: isDark ? 0.22 : 0.18),
      phaseX: 2.6,
      phaseY: 1.8,
      freqX: 1,
      freqY: 1,
    );
    // Quarto orb pesca/primario che attraversa il centro
    orb(
      base: Offset(w * 0.62, h * 0.22),
      baseRadius: shortest * 0.36,
      color: cs.primary.withValues(alpha: isDark ? 0.20 : 0.18),
      phaseX: 4.0,
      phaseY: 2.2,
      freqX: 2,
      freqY: 2,
    );

    // 3. Due onde sinusoidali morbide sul fondo per dare continuità visiva.
    void drawWave({
      required double baseYFactor,
      required double amplitude,
      required double phase,
      required int speed,
      required Color topColor,
    }) {
      final path = Path()..moveTo(0, h);
      final baseY = h * baseYFactor;
      const steps = 48;
      for (int i = 0; i <= steps; i++) {
        final x = (w / steps) * i;
        final nx = (i / steps) * 2 * math.pi;
        final y = baseY +
            math.sin(nx + t * speed + phase) * amplitude +
            math.cos(nx * 2 - t + phase) * (amplitude * 0.4);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();

      final wavePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            topColor,
            topColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, baseY - amplitude * 2, w, h - baseY + amplitude * 2));
      canvas.drawPath(path, wavePaint);
    }

    drawWave(
      baseYFactor: 0.78,
      amplitude: h * 0.032,
      phase: 0.0,
      speed: 1,
      topColor: cs.primary.withValues(alpha: isDark ? 0.14 : 0.12),
    );
    drawWave(
      baseYFactor: 0.85,
      amplitude: h * 0.026,
      phase: 2.1,
      speed: 2,
      topColor: cs.tertiary.withValues(alpha: isDark ? 0.12 : 0.10),
    );
  }

  @override
  bool shouldRepaint(_OrbBackgroundPainter old) =>
      old.t != t || old.isDark != isDark || old.cs != cs;
}
