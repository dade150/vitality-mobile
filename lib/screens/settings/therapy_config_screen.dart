import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/therapy_item.dart';
import '../../widgets/section_card.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class TherapyConfigScreen extends StatelessWidget {
  const TherapyConfigScreen({super.key});

  Future<void> _addOrEditTherapy(BuildContext context, {TherapyItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final timeController = TextEditingController(text: existing?.time ?? '');
    final health = context.read<HealthProvider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Aggiungi Farmaco' : 'Modifica Farmaco'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome farmaco')),
              const SizedBox(height: 12),
              TextField(controller: timeController, decoration: const InputDecoration(labelText: 'Orario (es. 08:00)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final time = timeController.text.trim();
                if (name.isEmpty || time.isEmpty) return;
                if (existing == null) {
                  health.addTherapyItem(
                    TherapyItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, time: time),
                  );
                } else {
                  health.updateTherapyItem(existing.id, name: name, time: time);
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final health = context.watch<HealthProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configurazione Terapia')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SectionCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Notifiche promemoria'),
                    subtitle: const Text('Ricevi un avviso agli orari della terapia'),
                    value: settings.notificheTerapia,
                    onChanged: (value) => context.read<SettingsProvider>().setNotificheTerapia(value),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Farmaci', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final item in health.therapyItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(item.name),
                        subtitle: Text(item.time),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _addOrEditTherapy(context, existing: item),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                              onPressed: () => context.read<HealthProvider>().removeTherapyItem(item.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addOrEditTherapy(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Aggiungi Farmaco'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }
}
