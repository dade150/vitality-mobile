import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../providers/appointments_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class AddVisitScreen extends StatefulWidget {
  final Appointment? existing;

  const AddVisitScreen({super.key, this.existing});

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _typeController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  Appointment? _editing;
  bool _initialized = false;
  bool _busy = false;
  String? _error;

  static const _genericError = 'Operazione non riuscita. Controlla la connessione e riprova.';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    final existing = widget.existing ?? (arg is Appointment ? arg : null);
    if (existing != null) {
      _editing = existing;
      _typeController.text = existing.type;
      _locationController.text = existing.location;
      _notesController.text = existing.notes;
      _date = existing.date;
      _time = existing.time;
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 5);
    var initial = _date ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Data della visita',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _error = null;
      });
    }
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      helpText: 'Orario della visita',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final type = _typeController.text.trim();
    if (type.isEmpty || _date == null || _time == null) {
      setState(() => _error = 'Compila tipo, data e ora della visita.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final provider = context.read<AppointmentsProvider>();
    final appt = Appointment(
      id: _editing?.id ?? '',
      type: type,
      date: _date!,
      time: _time!,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
    );

    final ok = _editing == null
        ? await provider.addAppointment(appt)
        : await provider.updateAppointment(appt);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = provider.errorMessage ?? _genericError;
      });
    }
  }

  Future<void> _delete() async {
    final editing = _editing;
    if (editing == null) return;
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Elimina visita'),
            content: const Text('Vuoi davvero eliminare questo appuntamento?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final provider = context.read<AppointmentsProvider>();
    final ok = await provider.removeAppointment(editing.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = provider.errorMessage ?? _genericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEdit = _editing != null;

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
                        onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          isEdit ? 'Modifica Visita' : 'Nuova Visita',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      isEdit
                          ? 'Aggiorna i dettagli o l\'orario dell\'appuntamento.'
                          : 'Pianifica un nuovo appuntamento medico.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
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
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            hintText: 'es. Cardiologica, Diabetologica',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Data', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _busy ? null : _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _date == null
                                  ? 'gg/mm/aaaa'
                                  : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Ora', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _busy ? null : _pickTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              suffixIcon: Icon(Icons.access_time_rounded),
                            ),
                            child: Text(
                              _time == null
                                  ? '--:--'
                                  : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Luogo / Studio Medico', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationController,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            hintText: 'es. Ospedale San Raffaele',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Note (Opzionale)', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          enabled: !_busy,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Aggiungi dettagli o promemoria...',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!, style: TextStyle(color: cs.error, fontSize: 16)),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(_busy ? 'Salvataggio...' : 'Salva Appuntamento'),
                          ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _delete,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Elimina Visita'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.error,
                                side: BorderSide(color: cs.error, width: 2),
                              ),
                            ),
                          ),
                        ],
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
