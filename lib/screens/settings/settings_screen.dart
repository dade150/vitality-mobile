import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_settings.dart';
import '../../providers/profile_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/gdpr_account_dialogs.dart';
import '../../widgets/legal_documents_sheet.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>();

    if (settings.isLoading && !settings.hasLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Impostazioni')),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Aspetto', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: RadioGroup<bool>(
                    groupValue: settings.darkMode,
                    onChanged: (val) {
                      if (val != null) {
                        context.read<SettingsProvider>().setDarkMode(val);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<bool>(
                          secondary: Icon(Icons.light_mode_outlined),
                          title: Text('Tema chiaro'),
                          value: false,
                        ),
                        Divider(height: 1),
                        RadioListTile<bool>(
                          secondary: Icon(Icons.dark_mode_outlined),
                          title: Text('Tema scuro'),
                          value: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Dimensione testo', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: RadioGroup<AppFontSize>(
                    groupValue: settings.fontSize,
                    onChanged: (val) {
                      if (val != null) {
                        context.read<SettingsProvider>().setFontSize(val);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<AppFontSize>(
                          secondary: Icon(Icons.format_size_rounded, size: 18),
                          title: Text('Piccolo'),
                          value: AppFontSize.piccolo,
                        ),
                        Divider(height: 1),
                        RadioListTile<AppFontSize>(
                          secondary: Icon(Icons.format_size_rounded, size: 22),
                          title: Text('Medio'),
                          value: AppFontSize.medio,
                        ),
                        Divider(height: 1),
                        RadioListTile<AppFontSize>(
                          secondary: Icon(Icons.format_size_rounded, size: 26),
                          title: Text('Grande'),
                          value: AppFontSize.grande,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Assistente vocale', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.record_voice_over_outlined),
                    title: const Text('Leggi ad alta voce le risposte in chat'),
                    value: settings.autoTts,
                    onChanged: (value) {
                      context.read<SettingsProvider>().setAutoTts(value);
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Text('Notifiche', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active_outlined),
                        title: const Text('Promemoria assunzione farmaci'),
                        value: settings.notifyTherapy,
                        onChanged: (value) async {
                          if (value) {
                            await NotificationService.instance.requestPermissions();
                          }
                          if (context.mounted) {
                            context.read<SettingsProvider>().setNotifyTherapy(value);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Promemoria visite mediche'),
                        value: settings.notifyAppointments,
                        onChanged: (value) async {
                          if (value) {
                            await NotificationService.instance.requestPermissions();
                          }
                          if (context.mounted) {
                            context.read<SettingsProvider>().setNotifyAppointments(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Privacy e gestione dati (GDPR)', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.smart_toy_outlined),
                        title: const Text('Assistente e analisi con IA'),
                        subtitle: const Text('Consenso al trattamento dati sanitari con Google Vertex AI (GDPR Art. 9)'),
                        value: profile.profile?.aiHealthConsent ?? false,
                        onChanged: (value) async {
                          if (!value) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Revocare il consenso IA?'),
                                content: const Text(
                                  'Disattivando il consenso, l\'assistente conversazionale e '
                                  'l\'estrazione automatica dei referti saranno disabilitati.\n\n'
                                  'Il tuo diario glicemico, i pasti, le attività e le terapie '
                                  'rimarranno conservati e continueranno a funzionare regolarmente.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Annulla'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Revoca consenso'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                          }
                          if (context.mounted) {
                            final ok = await context.read<ProfileProvider>().setAiHealthConsent(value);
                            if (context.mounted) {
                              if (ok) {
                                AppFeedback.showSuccess(
                                  context,
                                  value
                                      ? 'Consenso IA attivato.'
                                      : 'Consenso IA revocato. L\'assistente è ora disattivato.',
                                );
                              } else {
                                AppFeedback.showErrorDialog(
                                  context,
                                  message: 'Impossibile aggiornare il consenso. Riprova.',
                                );
                              }
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Termini e condizioni di servizio'),
                        subtitle: const Text('Versione ${LegalDocumentsSheet.currentTermsVersion}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => LegalDocumentsSheet.showTermsOfService(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Informativa sulla privacy'),
                        subtitle: const Text('Versione ${LegalDocumentsSheet.currentPrivacyVersion} (Art. 13 e 9 GDPR)'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => LegalDocumentsSheet.showPrivacyPolicy(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.file_download_outlined, color: cs.primary),
                        title: Text('Esporta dati (JSON)', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Scarica copia leggibile di tutti i tuoi dati'),
                        trailing: Icon(Icons.download_rounded, color: cs.primary),
                        onTap: () => triggerGdprJsonExport(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.delete_forever_outlined, color: cs.error),
                        title: Text('Elimina account e dati', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Cancellazione definitiva (Diritto all\'Oblio)'),
                        trailing: Icon(Icons.chevron_right_rounded, color: cs.error),
                        onTap: () => showDeleteAccountSecurityDialog(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}
