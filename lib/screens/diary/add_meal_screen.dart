import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../models/meal_entry.dart';
import '../../services/health_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/vital_entry_sheet.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _timeController = TextEditingController();
  MealType _type = MealType.colazione;
  bool _useEstimate = true;
  late DateTime _day;
  bool _dayInitialized = false;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (!_dayInitialized) {
      final arg = _route?.settings.arguments;
      final base = WhenSelector.clampNotFuture(arg is DateTime ? arg : DateTime.now());
      _day = DateTime(base.year, base.month, base.day);
      _dayInitialized = true;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _caloriesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  /// Stima molto approssimativa delle calorie, basata sul tipo di pasto e
  /// sulla lunghezza della descrizione. Non è un calcolo nutrizionale reale:
  /// serve solo come punto di partenza comodo che l'utente può correggere.
  int _estimateCalories() {
    const base = {
      MealType.colazione: 350,
      MealType.spuntinoMattina: 150,
      MealType.pranzo: 650,
      MealType.spuntinoPomeriggio: 180,
      MealType.cena: 550,
      MealType.fuoriPasto: 200,
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

    final rawTime = _timeController.text.trim();
    DateTime when;
    if (rawTime.isNotEmpty) {
      final normalized = HealthService.normalizeTime(rawTime);
      if (normalized == null) {
        _showMessage('Orario non valido: usa il formato HH:MM (es. 13:30).');
        return;
      }
      final parts = normalized.split(':');
      // second = 1 indica che l'orario è stato specificato esplicitamente dall'utente.
      when = DateTime(
        _day.year,
        _day.month,
        _day.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
        1,
      );
    } else if (_type == MealType.fuoriPasto) {
      final now = DateTime.now();
      when = DateTime(_day.year, _day.month, _day.day, now.hour, now.minute, 1);
    } else {
      final def = _type.defaultTime;
      when = DateTime(_day.year, _day.month, _day.day, def.hour, def.minute, 0);
    }

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
    if (!MealType.values.contains(_type)) {
      _type = MealType.colazione;
    }
    final isFuoriPasto = _type == MealType.fuoriPasto;

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
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _type = v;
                                if (_type == MealType.fuoriPasto && _timeController.text.isEmpty) {
                                  _timeController.text = WhenSelector.hhmm(DateTime.now());
                                }
                              });
                            },
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
                          const SizedBox(height: 20),
                          WhenSelector(
                            label: 'Giorno del pasto',
                            value: _day,
                            showTime: false,
                            enabled: !_saving,
                            onChanged: (v) => setState(() => _day = DateTime(v.year, v.month, v.day)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isFuoriPasto
                                ? 'Orario fuori pasto (es. 17:30)'
                                : 'Orario (opzionale, es. 13:00)',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _timeController,
                            enabled: !_saving,
                            keyboardType: TextInputType.datetime,
                            inputFormatters: const [TimeTextInputFormatter()],
                            decoration: InputDecoration(
                              hintText: isFuoriPasto
                                  ? 'es. 17:30'
                                  : 'Lascia vuoto se è l\'orario abituale',
                              prefixIcon: const Icon(Icons.schedule_rounded, color: AppColors.accent),
                              suffixIcon: _timeController.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Rimuovi orario',
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () => setState(() => _timeController.clear()),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
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
