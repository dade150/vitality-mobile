// lib/screens/chat/chat_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';

/// Schermata per visualizzare lo storico delle sessioni di chat precedenti.
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatProvider>().loadSessions();
      }
    });
  }

  Future<bool> _confirmDelete(BuildContext context, ChatSessionItem session) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Elimina conversazione'),
        content: Text(
          'Vuoi davvero eliminare "${session.title ?? 'questa sessione'}"? L\'operazione non è reversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteSession(ChatProvider chat, ChatSessionItem session) async {
    final confirmed = await _confirmDelete(context, session);
    if (!confirmed || !mounted) return;

    final ok = await chat.deleteSession(session.id);
    if (!mounted) return;
    if (!ok && chat.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.errorMessage!)),
      );
    }
  }

  Future<void> _selectSession(ChatProvider chat, ChatSessionItem session) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final ok = await chat.loadSession(session.id);
    if (!mounted) return;

    if (ok) {
      nav.pop();
    } else if (chat.errorMessage != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(chat.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat passate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Nuova chat',
            onPressed: () {
              chat.newChat();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: chat.isLoadingSessions && chat.sessions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : chat.sessions.isEmpty
                ? _buildEmptyState(context, theme, cs, chat)
                : RefreshIndicator(
                    onRefresh: () => chat.loadSessions(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: chat.sessions.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                          itemBuilder: (context, index) {
                            final session = chat.sessions[index];
                            final isCurrent = chat.currentSessionId == session.id;
                            final formattedDate = DateFormat('dd/MM/yyyy HH:mm')
                                .format(session.createdAt.toLocal());

                            return Dismissible(
                              key: ValueKey('session_${session.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.redAccent,
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              confirmDismiss: (_) => _confirmDelete(context, session),
                              onDismissed: (_) => chat.deleteSession(session.id),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isCurrent
                                      ? AppColors.accent
                                      : AppColors.lightPeach,
                                  child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: isCurrent
                                        ? Colors.white
                                        : AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  session.title?.isNotEmpty == true
                                      ? session.title!
                                      : 'Sessione del $formattedDate',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isCurrent
                                        ? AppColors.accent
                                        : cs.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  formattedDate,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCurrent)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.lightPeach,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Attiva',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 22,
                                      ),
                                      color: cs.onSurfaceVariant,
                                      tooltip: 'Elimina chat',
                                      onPressed: () =>
                                          _deleteSession(chat, session),
                                    ),
                                  ],
                                ),
                                onTap: () => _selectSession(chat, session),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    ChatProvider chat,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.lightPeach,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 42,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Nessuna sessione passata',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Le conversazioni precedenti con il tuo assistente virtuale compariranno qui.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () {
                  chat.newChat();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_comment_outlined, size: 20),
                label: const Text(
                  'Avvia nuova chat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
