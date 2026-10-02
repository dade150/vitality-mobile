import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../models/activity_entry.dart';
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
  String _type = 'Camminata';

  static const _types = ['Camminata', 'Corsa', 'Nuoto', 'Ciclismo', 'Ginnastica', 'Altro'];

  @override
  void dispose() {
    _minutesController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final steps = int.tryParse(_stepsController.text) ?? 0;
    context.read<HealthProvider>().addActivity(
          ActivityEntry(date: DateTime.now(), type: _type, minutes: minutes, steps: steps),
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
                      Text('Aggiungi Attività', style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Registra la tua attività fisica di oggi.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                            onPressed: _save,
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
    );
  }
}
