import 'package:flutter/material.dart';
import '../models/therapy_item.dart';
import '../services/health_service.dart';
import '../utils/app_date_picker.dart';

/// Dialog riutilizzabile per inserire o modificare un farmaco della terapia.
/// Usato sia nella schermata di configurazione terapia ([TherapyConfigScreen])
/// sia durante la procedura di registrazione utente ([RegisterStepTherapy]).
class TherapyItemDialog extends StatefulWidget {
  final TherapyItem? existing;
  final Future<bool> Function(String name, String time) onSave;

  const TherapyItemDialog({
    super.key,
    this.existing,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    TherapyItem? existing,
    required Future<bool> Function(String name, String time) onSave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TherapyItemDialog(existing: existing, onSave: onSave),
    );
  }

  @override
  State<TherapyItemDialog> createState() => _TherapyItemDialogState();
}

class _TherapyItemDialogState extends State<TherapyItemDialog> {
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

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    TimeOfDay initial = now;
    final current = HealthService.normalizeTime(_timeController.text);
    if (current != null) {
      final parts = current.split(':');
      initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    final picked = await AppDateTimePicker.pickTime(
      context: context,
      initialTime: initial,
      helpText: 'Orario di assunzione',
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _timeController.text = '$hh:$mm';
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
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

    final ok = await widget.onSave(name, time);

    if (!mounted) return;
    if (ok) {
      if (_route?.isCurrent ?? false) Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = 'Operazione non riuscita. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(existing == null ? 'Aggiungi farmaco' : 'Modifica farmaco'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome farmaco',
                hintText: 'Es. Metformina 500mg',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
            ),
            const SizedBox(height: 14),
            AppPickerTile(
              icon: Icons.schedule_rounded,
              caption: 'Orario di assunzione',
              valueText: _timeController.text.isEmpty ? 'Seleziona orario' : _timeController.text,
              enabled: !_busy,
              onTap: _pickTime,
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
