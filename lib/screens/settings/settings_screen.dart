import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_settings.dart';
import '../../providers/settings_provider.dart';
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
                const SizedBox(height: 20),
                Text('Dimensione testo', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AppFontSize>(
                      segments: const [
                        ButtonSegment(value: AppFontSize.piccolo, label: Text('Piccolo')),
                        ButtonSegment(value: AppFontSize.medio, label: Text('Medio')),
                        ButtonSegment(value: AppFontSize.grande, label: Text('Grande')),
                      ],
                      selected: {settings.fontSize},
                      onSelectionChanged: (selected) {
                        context.read<SettingsProvider>().setFontSize(selected.first);
                      },
                    ),
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
                        title: const Text('Promemoria terapia'),
                        subtitle: const Text('Ricevi un avviso agli orari di assunzione dei farmaci'),
                        value: settings.notifyTherapy,
                        onChanged: (value) {
                          context.read<SettingsProvider>().setNotifyTherapy(value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Promemoria appuntamenti'),
                        subtitle: const Text('Ricevi un promemoria prima delle visite mediche'),
                        value: settings.notifyAppointments,
                        onChanged: (value) {
                          context.read<SettingsProvider>().setNotifyAppointments(value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Terapia', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                SectionCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('Configura terapia e notifiche'),
                    subtitle: const Text('Gestisci farmaci, orari e promemoria'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pushNamed('/settings/therapy'),
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
