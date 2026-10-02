import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/section_card.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Map<String, (String, IconData)> _sectionLabels = {
    'terapia': ('Terapia', Icons.medication_outlined),
    'glicemia': ('Glicemia', Icons.opacity_rounded),
    'pressione': ('Pressione Arteriosa', Icons.favorite_outline_rounded),
    'pasti': ('Pasti', Icons.restaurant_outlined),
    'attivita': ('Attività', Icons.directions_walk_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();

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
                      RadioListTile<ThemeMode>(
                        title: const Text('Chiaro'),
                        value: ThemeMode.light,
                        groupValue: themeProvider.themeMode,
                        onChanged: (mode) => context.read<ThemeProvider>().setThemeMode(mode ?? ThemeMode.system),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Scuro'),
                        value: ThemeMode.dark,
                        groupValue: themeProvider.themeMode,
                        onChanged: (mode) => context.read<ThemeProvider>().setThemeMode(mode ?? ThemeMode.system),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Sistema'),
                        value: ThemeMode.system,
                        groupValue: themeProvider.themeMode,
                        onChanged: (mode) => context.read<ThemeProvider>().setThemeMode(mode ?? ThemeMode.system),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Sezioni del Diario', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Disattiva le sezioni che non ti interessano per semplificare la schermata del Diario.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: _sectionLabels.entries.map((entry) {
                      final (label, icon) = entry.value;
                      return SwitchListTile(
                        secondary: Icon(icon),
                        title: Text(label),
                        value: settings.isSectionVisible(entry.key),
                        onChanged: (value) => context.read<SettingsProvider>().setSectionVisible(entry.key, value),
                      );
                    }).toList(),
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
