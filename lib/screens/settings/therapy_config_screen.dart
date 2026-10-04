import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/therapy_item.dart';
import '../../services/health_service.dart';
import '../../widgets/section_card.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class TherapyConfigScreen extends StatelessWidget {
  const TherapyConfigScreen({super.key});

  static const String _genericError = 'Operazione non riuscita. Controlla la connessione e riprova.';

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addOrEditTherapy(BuildContext context, {TherapyItem? existing}) {
    final health = context.read<HealthProvider>();
    return showDialog<void>(
      context: context,
      builder: (_) => _TherapyDialog(health: health, existing: existing),
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

/// Dialog di inserimento/modifica di una terapia.
///
/// Possiede i propri [TextEditingController] e li smonta nel proprio
/// [dispose], cioè quando il dialogo viene davvero smontato dall'albero, e non
/// subito dopo il pop mentre l'animazione di uscita è ancora in corso.
///
/// Mentre il salvataggio è in corso la [PopScope] blocca back e barriera; la
/// chiusura finale viene inoltre verificata sulla route del dialogo, così un
/// pop tardivo non può mai chiudere la schermata sottostante.
class _TherapyDialog extends StatefulWidget {
  const _TherapyDialog({required this.health, this.existing});

  final HealthProvider health;
  final TherapyItem? existing;

  @override
  State<_TherapyDialog> createState() => _TherapyDialogState();
}

class _TherapyDialogState extends State<_TherapyDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _timeController;
  bool _busy = false;
  String? _error;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _timeController = TextEditingController(text: widget.existing?.time ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    // Stessa normalizzazione usata dal servizio: un orario non valido viene
    // rifiutato qui, con un messaggio chiaro, invece di fallire in modo
    // silenzioso dopo che il dialogo si è già chiuso.
    final time = HealthService.normalizeTime(_timeController.text);
    if (name.isEmpty) {
      setState(() => _error = 'Inserisci il nome del farmaco.');
      return;
    }
    if (name.length > 100) {
      setState(() => _error = 'Nome troppo lungo (massimo 100 caratteri).');
      return;
    }
    if (time == null) {
      setState(() => _error = 'Orario non valido: usa il formato 08:00.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final existing = widget.existing;
    final ok = existing == null
        ? await widget.health.addTherapyItem(TherapyItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            time: time,
          ))
        : await widget.health.updateTherapyItem(existing.id, name: name, time: time);

    if (!mounted) return;
    if (ok) {
      // Chiude solo questo dialogo: se è già stato chiuso nel frattempo, un
      // pop incondizionato chiuderebbe la schermata sottostante.
      if (_route?.isCurrent ?? false) Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = TherapyConfigScreen._genericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(existing == null ? 'Aggiungi Farmaco' : 'Modifica Farmaco'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Nome farmaco'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeController,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Orario (es. 08:00)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
