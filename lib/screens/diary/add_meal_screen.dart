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

  void _save() {
    final estimated = _useEstimate || _caloriesController.text.trim().isEmpty;
    final calories =
        estimated ? _estimateCalories() : (int.tryParse(_caloriesController.text) ?? _estimateCalories());
    context.read<HealthProvider>().addMeal(
          MealEntry(
            date: DateTime.now(),
            type: _type,
            description: _descriptionController.text.trim().isEmpty ? _type.label : _descriptionController.text.trim(),
            calories: calories,
            isEstimated: estimated,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Text('Aggiungi Pasto', style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
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
                          items: MealType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
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
                            onPressed: _save,
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
    );
  }
}
