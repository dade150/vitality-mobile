import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_settings.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

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
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        secondary: const Icon(Icons.light_mode_outlined),
                        title: const Text('Tema chiaro'),
                        value: false,
                        groupValue: settings.darkMode,
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsProvider>().setDarkMode(val);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<bool>(
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Tema scuro'),
                        value: true,
                        groupValue: settings.darkMode,
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsProvider>().setDarkMode(val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Dimensione testo', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      RadioListTile<AppFontSize>(
                        secondary: const Icon(Icons.format_size_rounded, size: 18),
                        title: const Text('Piccolo'),
                        value: AppFontSize.piccolo,
                        groupValue: settings.fontSize,
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsProvider>().setFontSize(val);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<AppFontSize>(
                        secondary: const Icon(Icons.format_size_rounded, size: 22),
                        title: const Text('Medio'),
                        value: AppFontSize.medio,
                        groupValue: settings.fontSize,
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsProvider>().setFontSize(val);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<AppFontSize>(
                        secondary: const Icon(Icons.format_size_rounded, size: 26),
                        title: const Text('Grande'),
                        value: AppFontSize.grande,
                        groupValue: settings.fontSize,
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsProvider>().setFontSize(val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Assistente Vocale', style: theme.textTheme.titleLarge),
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}
