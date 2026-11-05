import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/therapy_item.dart';
import '../../widgets/section_card.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/therapy_dialog.dart';

class TherapyConfigScreen extends StatelessWidget {
  const TherapyConfigScreen({super.key});

  static const String _genericError = 'Operazione non riuscita. Controlla la connessione e riprova.';

  void _showMessage(BuildContext context, String text) {
    AppFeedback.showErrorDialog(context, message: text);
  }

  Future<void> _addOrEditTherapy(BuildContext context, {TherapyItem? existing}) {
    final health = context.read<HealthProvider>();
    return TherapyItemDialog.show(
      context: context,
      existing: existing,
      onSave: (name, time) async {
        if (existing == null) {
          return await health.addTherapyItem(TherapyItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            time: time,
          ));
        } else {
          return await health.updateTherapyItem(existing.id, name: name, time: time);
        }
      },
    );
  }

  Future<void> _deleteTherapy(BuildContext context, TherapyItem item) async {
    final ok = await context.read<HealthProvider>().removeTherapyItem(item.id);
    if (!ok && context.mounted) _showMessage(context, _genericError);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final health = context.watch<HealthProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configurazione terapia')),
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
                              onPressed: () => _deleteTherapy(context, item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addOrEditTherapy(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Aggiungi farmaco'),
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
