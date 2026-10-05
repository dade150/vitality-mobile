import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../models/activity_entry.dart';
import '../../services/health_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _minutesController = TextEditingController();
  final _stepsController = TextEditingController();
  ModalRoute<dynamic>? _route;

  // Stesse etichette usate dal servizio per scrivere `activity_type`.
  static final List<String> _types = HealthService.activityLabels;
  String _type = HealthService.activityLabels.first;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  bool _saving = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > 1440) {
      _showMessage('Inserisci una durata tra 1 e 1440 minuti.');
      return;
    }
    final stepsText = _stepsController.text.trim();
    final steps = stepsText.isEmpty ? 0 : int.tryParse(stepsText);
    if (steps == null || steps < 0 || steps > 200000) {
      _showMessage('Inserisci un numero di passi tra 0 e 200000.');
      return;
    }

    // Il Diario passa il momento da usare (giorno selezionato); altrimenti adesso.
    final arg = ModalRoute.of(context)?.settings.arguments;
    final when = arg is DateTime ? arg : DateTime.now();
    final health = context.read<HealthProvider>();

    setState(() => _saving = true);
    final ok = await health.addActivity(
      ActivityEntry(date: when, type: _type, minutes: minutes, steps: steps),
    );
    if (!mounted) return;
    if (ok) {
      // Chiude solo questa schermata: se è già stata chiusa nel frattempo, un
      // pop incondizionato chiuderebbe il Diario sottostante.
      if (_route?.isCurrent ?? false) Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      _showMessage(
          health.errorMessage ?? 'Salvataggio non riuscito. Controlla la connessione e riprova.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // La PopScope blocca back e predictive back finché il salvataggio è in
    // corso: se la schermata venisse chiusa durante l'await, l'esito non
    // potrebbe più essere mostrato all'utente.
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                              _saving ? null : () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Text('Aggiungi Attività',
                            style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Registra la tua attività fisica di oggi.',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tipo di attività', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _type,
                            items: _types
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) => setState(() => _type = v ?? _type),
                          ),
                          const SizedBox(height: 20),
                          Text('Durata (minuti)', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _minutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'es. 30'),
                          ),
                          const SizedBox(height: 20),
                          Text('Passi (opzionale)', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _stepsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'es. 2500'),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Salva Attività'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
      ),
    );
  }
}