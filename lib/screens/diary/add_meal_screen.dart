import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../models/meal_entry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();
  MealType _type = MealType.colazione;
  bool _useEstimate = true;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  /// Stima molto approssimativa delle calorie, basata sul tipo di pasto e
  /// sulla lunghezza della descrizione. Non è un calcolo nutrizionale reale:
  /// serve solo come punto di partenza comodo che l'utente può correggere.
  int _estimateCalories() {
    const base = {
      MealType.colazione: 350,
      MealType.pranzo: 650,
      MealType.cena: 550,
      MealType.spuntino: 150,
    };
    final text = _descriptionController.text.trim();
    final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return (base[_type] ?? 400) + (wordCount * 15);
  }

  bool _saving = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final description = _descriptionController.text.trim();
    if (description.length > 500) {
      _showMessage('La descrizione è troppo lunga (massimo 500 caratteri).');
      return;
    }

    final estimated = _useEstimate || _caloriesController.text.trim().isEmpty;
    int calories;
    if (estimated) {
      calories = _estimateCalories();
    } else {
      final parsed = int.tryParse(_caloriesController.text.trim());
      if (parsed == null || parsed < 0 || parsed > 10000) {
        _showMessage('Inserisci calorie tra 0 e 10000.');
        return;
      }
      calories = parsed;
    }

    // Il Diario passa il momento da usare (giorno selezionato); altrimenti adesso.
    final arg = ModalRoute.of(context)?.settings.arguments;
    final when = arg is DateTime ? arg : DateTime.now();
    final health = context.read<HealthProvider>();

    setState(() => _saving = true);
    final ok = await health.addMeal(
      MealEntry(
        date: when,
        type: _type,
        description: description.isEmpty ? _type.label : description,
        calories: calories,
        isEstimated: estimated,
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
                        Text('Aggiungi Pasto',
                            style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tipo di pasto', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<MealType>(
                            initialValue: _type,
                            items: MealType.values
                                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                                .toList(),
                            onChanged: (v) => setState(() => _type = v ?? _type),
                          ),
                          const SizedBox(height: 20),
                          Text('Cosa hai mangiato?', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(hintText: 'es. Pasta integrale con verdure'),
                          ),
                          const SizedBox(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Stima automatica delle calorie'),
                            subtitle: const Text('Calcolo approssimativo basato sul tipo di pasto'),
                            value: _useEstimate,
                            onChanged: (v) => setState(() => _useEstimate = v),
                          ),
                          if (!_useEstimate) ...[
                            const SizedBox(height: 8),
                            Text('Calorie (kcal)', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _caloriesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'es. 500'),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Salva Pasto'),
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
