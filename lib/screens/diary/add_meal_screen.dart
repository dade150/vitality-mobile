import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_entry.dart';
import '../../models/nutrition_estimate.dart';
import '../../providers/health_provider.dart';
import '../../services/health_service.dart';
import '../../services/nutrition_service.dart';
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
  final _carbsController = TextEditingController();
  final _timeController = TextEditingController();
  final _nutritionService = NutritionService();

  MealType _type = MealType.colazione;
  bool _isEstimated = false;
  bool _estimating = false;
  MealEstimateResponse? _estimateResult;

  late DateTime _day;
  bool _dayInitialized = false;
  ModalRoute<dynamic>? _route;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      if (mounted) setState(() {});
    });
  }

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
    _carbsController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _estimateWithAI() async {
    final text = _descriptionController.text.trim();
    if (text.length < 2) {
      _showMessage('Scrivi cosa hai mangiato prima di richiedere la stima.');
      return;
    }

    setState(() => _estimating = true);
    try {
      final result = await _nutritionService.estimateMeal(
        description: text,
        mealType: _type,
      );
      if (!mounted) return;

      setState(() {
        _estimateResult = result;
        _caloriesController.text = result.totalCalories.toString();
        _carbsController.text = result.totalCarbsGrams.toString();
        _isEstimated = true;
      });

      _showMessage(
        result.hasCreaItems
            ? 'Valori calcolati sulle tabelle ufficiali CREA.'
            : 'Valori nutrizionali stimati con intelligenza artificiale.',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Stima momentaneamente non disponibile. Inserisci i valori manualmente.');
    } finally {
      if (mounted) {
        setState(() => _estimating = false);
      }
    }
  }

  Future<void> _save() async {
    final description = _descriptionController.text.trim();
    if (description.length > 500) {
      _showMessage('La descrizione è troppo lunga (massimo 500 caratteri).');
      return;
    }

    // Se sia calorie che carboidrati sono vuoti ma c'è una descrizione, esegue prima la stima
    if (_caloriesController.text.trim().isEmpty && description.isNotEmpty) {
      await _estimateWithAI();
      if (!mounted) return;
    }

    final rawCalories = _caloriesController.text.trim();
    final parsedCalories = int.tryParse(rawCalories);
    if (parsedCalories == null || parsedCalories < 0 || parsedCalories > 10000) {
      _showMessage('Inserisci le calorie (valore tra 0 e 10000 kcal).');
      return;
    }

    int? parsedCarbs;
    final rawCarbs = _carbsController.text.trim();
    if (rawCarbs.isNotEmpty) {
      parsedCarbs = int.tryParse(rawCarbs);
      if (parsedCarbs == null || parsedCarbs < 0 || parsedCarbs > 2000) {
        _showMessage('Inserisci carboidrati validi (tra 0 e 2000 g).');
        return;
      }
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
        calories: parsedCalories,
        carbsGrams: parsedCarbs,
        isEstimated: _isEstimated,
      ),
    );
    if (!mounted) return;
    if (ok) {
      if (_route?.isCurrent ?? false) Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      _showMessage(
        health.errorMessage ?? 'Salvataggio non riuscito. Controlla la connessione e riprova.',
      );
    }
  }

  Widget _buildEstimateBreakdownCard(ThemeData theme) {
    final res = _estimateResult;
    if (res == null) return const SizedBox.shrink();

    final cs = theme.colorScheme;
    final isCrea = res.hasCreaItems;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCrea ? AppColors.accent.withValues(alpha: 0.4) : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCrea ? Icons.verified_rounded : Icons.auto_awesome_rounded,
                color: isCrea ? AppColors.accent : cs.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCrea
                      ? 'Dati nutrizionali ufficiali CREA Alimenti'
                      : 'Stima nutrizionale intelligente',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCrea ? AppColors.accent : cs.primary,
                  ),
                ),
              ),
            ],
          ),
          if (res.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Ingredienti identificati:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final it in res.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        '${it.name} (${it.quantityG.toInt()} g)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${it.calories} kcal · ${it.carbsGrams} g carb',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (res.notes != null && res.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      res.notes!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!MealType.values.contains(_type)) {
      _type = MealType.colazione;
    }
    final isFuoriPasto = _type == MealType.fuoriPasto;
    final canEstimate = _descriptionController.text.trim().length >= 2 && !_estimating && !_saving;

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
                          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Text(
                          'Aggiungi Pasto',
                          style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent),
                        ),
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
                            enabled: !_saving,
                            decoration: const InputDecoration(
                              hintText: 'es. 80g di pasta integrale con pomodoro e un cucchiaio di parmigiano',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: canEstimate ? _estimateWithAI : null,
                              icon: _estimating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                              label: Text(
                                _estimating ? 'Calcolo nutrizionale in corso...' : 'Calcola con AI (Tabelle CREA)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                          _buildEstimateBreakdownCard(theme),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Calorie (kcal)', style: theme.textTheme.labelLarge),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _caloriesController,
                                      enabled: !_saving,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(hintText: 'es. 450'),
                                      onChanged: (_) => _isEstimated = false,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Carboidrati (g)', style: theme.textTheme.labelLarge),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _carbsController,
                                      enabled: !_saving,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(hintText: 'es. 60'),
                                      onChanged: (_) => _isEstimated = false,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                            isFuoriPasto ? 'Orario fuori pasto (es. 17:30)' : 'Orario (opzionale, es. 13:00)',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _timeController,
                            enabled: !_saving,
                            keyboardType: TextInputType.datetime,
                            inputFormatters: const [TimeTextInputFormatter()],
                            decoration: InputDecoration(
                              hintText: isFuoriPasto ? 'es. 17:30' : 'Lascia vuoto se è l\'orario abituale',
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
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Salva Pasto', style: TextStyle(fontSize: 16)),
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
