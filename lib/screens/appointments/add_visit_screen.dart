import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointments_provider.dart';
import '../../models/appointment.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class AddVisitScreen extends StatefulWidget {
  const AddVisitScreen({super.key});

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _typeController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void dispose() {
    _typeController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (_typeController.text.trim().isEmpty || _date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila tipo, data e ora della visita.')),
      );
      return;
    }
    context.read<AppointmentsProvider>().addAppointment(
          Appointment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: _typeController.text.trim(),
            date: _date!,
            time: _time!,
            location: _locationController.text.trim(),
            notes: _notesController.text.trim(),
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
                      Text('Nuova Visita', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      'Pianifica un nuovo appuntamento medico.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tipo di visita', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _typeController,
                          decoration: const InputDecoration(hintText: 'es. Cardiologica, Diabetologica'),
                        ),
                        const SizedBox(height: 20),
                        Text('Data', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
                            child: Text(_date == null
                                ? 'gg/mm/aaaa'
                                : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Ora', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(suffixIcon: Icon(Icons.access_time_rounded)),
                            child: Text(_time == null
                                ? '--:--'
                                : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Luogo / Studio Medico', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(hintText: 'es. Ospedale San Raffaele'),
                        ),
                        const SizedBox(height: 20),
                        Text('Note (Opzionale)', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Aggiungi dettagli o promemoria...'),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Salva Appuntamento'),
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
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }
}
