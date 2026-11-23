import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../models/activity_entry.dart';
import '../../services/health_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/vital_entry_sheet.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _minutesController = TextEditingController();
  final _stepsController = TextEditingController();
  late DateTime _when;
  bool _whenInitialized = false;
  ModalRoute<dynamic>? _route;

  // Stesse etichette usate dal servizio per scrivere `activity_type` e `intensity`.
  static final List<String> _types = HealthService.activityLabels;
  static final List<String> _intensities = HealthService.intensityLabels;
  String _type = HealthService.activityLabels.first;
  String _intensity = 'Moderata';

  bool get _isWalking => _type == 'Camminata';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (!_whenInitialized) {
      final arg = _route?.settings.arguments;
      _when = WhenSelector.clampNotFuture(arg is DateTime ? arg : DateTime.now());
      _whenInitialized = true;
    }
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  bool _saving = false;

  void _showMessage(String text) {
    AppFeedback.showErrorDialog(context, message: text);
  }

  Future<void> _save() async {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > 1440) {
      _showMessage('Inserisci una durata tra 1 e 1440 minuti.');
      return;
    }
    final int steps;
    if (_isWalking) {
      final stepsText = _stepsController.text.trim();
      final parsedSteps = stepsText.isEmpty ? 0 : int.tryParse(stepsText);
      if (parsedSteps == null || parsedSteps < 0 || parsedSteps > 200000) {
        _showMessage('Inserisci un numero di passi tra 0 e 200000.');
        return;
      }
      steps = parsedSteps;
    } else {
      steps = 0;
    }

    final health = context.read<HealthProvider>();

    setState(() => _saving = true);
    final ok = await health.addActivity(
      ActivityEntry(
        date: _when,
        type: _type,
        minutes: minutes,
        intensity: _intensity,
        steps: steps,
      ),
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
    final cs = theme.colorScheme;

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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                              _saving ? null : () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Torna indietro',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Aggiungi attività',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Tipo di attività', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      items: _types
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) {
                              final next = v ?? _type;
                              setState(() {
                                _type = next;
                                if (!_isWalking) _stepsController.clear();
                              });
                            },
                    ),
                    const SizedBox(height: 20),
                    Text('Intensità', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _intensity,
                      items: _intensities
                          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _intensity = v ?? _intensity),
                    ),
                    const SizedBox(height: 20),
                    Text('Durata (minuti)', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      textInputAction: _isWalking ? TextInputAction.next : TextInputAction.done,
                      decoration: const InputDecoration(hintText: 'es. 30'),
                      onSubmitted: _isWalking ? null : (_) => _save(),
                    ),
                    if (_isWalking) ...[
                      const SizedBox(height: 20),
                      Text('Passi (opzionale)', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _stepsController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(hintText: 'es. 2500'),
                        onSubmitted: (_) => _save(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    WhenSelector(
                      label: "Quando hai svolto l'attività?",
                      value: _when,
                      enabled: !_saving,
                      onChanged: (v) => setState(() => _when = v),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Salva attività'),
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