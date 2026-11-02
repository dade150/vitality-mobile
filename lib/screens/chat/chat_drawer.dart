import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gdpr_account_dialogs.dart';
import '../../widgets/pdf_export_sheet.dart';

/// Navigation Drawer laterale per la schermata Chat di Vitality Assist.
/// Layout pulito, sobrio e accessibile con bordi piatti, feedback visivo
/// e pulsanti dedicati in basso per Esportazione Dati (Art. 20 GDPR) ed Eliminazione Account (Art. 17 GDPR).
class ChatDrawer extends StatelessWidget {
  /// Callback opzionale per l'avvio di una nuova chat (se null, usa chatProvider.newChat()).
  final VoidCallback? onNewChat;

  /// Callback opzionale per aprire le chat passate (se null, naviga a /chat/history).
  final VoidCallback? onPastChats;

  const ChatDrawer({
    super.key,
    this.onNewChat,
    this.onPastChats,
  });

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.accent,
        size: 21,
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
          fontSize: 16,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      minLeadingWidth: 28,
      splashColor: AppColors.accent.withValues(alpha: 0.18),
      hoverColor: AppColors.accent.withValues(alpha: 0.08),
      focusColor: AppColors.accent.withValues(alpha: 0.12),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hostContext = Navigator.of(context).context;

    return Drawer(
      // Bordi piatti (nessun angolo arrotondato a destra né in alto né in basso)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      backgroundColor: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header pulito ed essenziale: solo scritta "Menu" senza banner o icone ingombranti
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 20,
              24,
              12,
            ),
            child: Text(
              'Menu',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                fontSize: 22,
              ),
            ),
          ),

          // Voci del menu con spaziatura uniforme e feedback visivo
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.add_comment_outlined,
                  title: 'Nuova chat',
                  onTap: () {
                    if (onNewChat != null) {
                      onNewChat!();
                    } else {
                      hostContext.read<ChatProvider>().newChat();
                    }
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.history_rounded,
                  title: 'Chat passate',
                  onTap: () {
                    if (onPastChats != null) {
                      onPastChats!();
                    } else {
                      Navigator.of(hostContext).pushNamed('/chat/history');
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    indent: 24,
                    endIndent: 24,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.person_outline_rounded,
                  title: 'Profilo',
                  onTap: () => Navigator.of(hostContext).pushNamed('/profile'),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.medication_outlined,
                  title: 'Terapia e Farmaci',
                  onTap: () => Navigator.of(hostContext).pushNamed('/settings/therapy'),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF Riepilogativo',
                  onTap: () => showPdfExportSheet(hostContext),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: 'Impostazioni',
                  onTap: () => Navigator.of(hostContext).pushNamed('/settings'),
                ),
              ],
            ),
          ),

          // Sezione inferiore dedicata ai diritti GDPR: Esportazione JSON (Art. 20) ed Eliminazione Dati/Account (Art. 17)
          Divider(
            height: 1,
            thickness: 1,
            indent: 24,
            endIndent: 24,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              4,
              0,
              MediaQuery.paddingOf(context).bottom + 8,
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.file_download_outlined,
                  title: 'Esporta dati (JSON)',
                  onTap: () => triggerGdprJsonExport(hostContext),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: cs.error,
                    size: 21,
                  ),
                  title: Text(
                    'Elimina account e dati',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.error,
                      fontSize: 16,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                  minLeadingWidth: 28,
                  onTap: () {
                    Navigator.pop(context);
                    showDeleteAccountSecurityDialog(hostContext);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
