import 'package:flutter/material.dart';
import '../models/therapy_item.dart';
import '../services/health_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_date_picker.dart';

enum _FrequencyMode { daily, weekly, customDays }

/// Dialog riutilizzabile per inserire o modificare un farmaco della terapia.
/// Usato sia nella schermata di configurazione terapia ([TherapyConfigScreen])
/// sia durante la procedura di registrazione utente ([RegisterStepTherapy]).
class TherapyItemDialog extends StatefulWidget {
  final TherapyItem? existing;
  final Future<bool> Function(String name, String time, String frequency) onSave;

  const TherapyItemDialog({
    super.key,
    this.existing,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    TherapyItem? existing,
    required Future<bool> Function(String name, String time, String frequency) onSave,
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
  late _FrequencyMode _mode;
  late Set<int> _selectedWeekdays;
  bool _busy = false;
  String? _error;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _timeController = TextEditingController(text: widget.existing?.time ?? '');
    final parsedDays = TherapyItem.parseWeekdays(widget.existing?.frequency);
    if (parsedDays.length == 7) {
      _mode = _FrequencyMode.daily;
      _selectedWeekdays = Set<int>.from(TherapyItem.allWeekdays);
    } else if (parsedDays.length == 1) {
      _mode = _FrequencyMode.weekly;
      _selectedWeekdays = Set<int>.from(parsedDays);
    } else {
      _mode = _FrequencyMode.customDays;
      _selectedWeekdays = Set<int>.from(parsedDays);
    }
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

  void _selectMode(_FrequencyMode next) {
    setState(() {
      _mode = next;
      _error = null;
      if (next == _FrequencyMode.daily) {
        _selectedWeekdays = Set<int>.from(TherapyItem.allWeekdays);
      } else if (next == _FrequencyMode.weekly) {
        final fallbackDay = _selectedWeekdays.length == 1
            ? _selectedWeekdays.first
            : DateTime.now().weekday;
        _selectedWeekdays = {fallbackDay};
      } else {
        if (_selectedWeekdays.length == 7) {
          _selectedWeekdays = {DateTime.monday, DateTime.wednesday, DateTime.friday};
        } else if (_selectedWeekdays.isEmpty) {
          _selectedWeekdays = {DateTime.now().weekday};
        }
      }
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      _error = null;
      if (_mode == _FrequencyMode.weekly) {
        _selectedWeekdays = {weekday};
      } else {
        if (_selectedWeekdays.contains(weekday)) {
          if (_selectedWeekdays.length > 1) {
            _selectedWeekdays.remove(weekday);
          }
        } else {
          _selectedWeekdays.add(weekday);
        }
      }
    });
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
      setState(() => _error = 'Seleziona l\'orario di assunzione.');
      return;
    }
    if (_mode != _FrequencyMode.daily && _selectedWeekdays.isEmpty) {
      setState(() => _error = 'Seleziona almeno un giorno della settimana.');
      return;
    }

    final frequency = _mode == _FrequencyMode.daily
        ? TherapyItem.defaultFrequency
        : TherapyItem.formatFrequency(_selectedWeekdays);

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await widget.onSave(name, time, frequency);

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

  Widget _buildModeChip({
    required _FrequencyMode mode,
    required String label,
    required ThemeData theme,
  }) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selected = _mode == mode;
    final activeBg = isDark ? cs.primary : AppColors.accent;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : cs.onSurface,
        ),
      ),
      selected: selected,
      selectedColor: activeBg,
      backgroundColor: cs.surfaceContainerHighest,
      showCheckmark: false,
      side: BorderSide(
        color: selected ? activeBg : cs.outlineVariant,
      ),
      onSelected: _busy ? null : (_) => _selectMode(mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeBg = isDark ? cs.primary : AppColors.accent;

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(existing == null ? 'Aggiungi farmaco' : 'Modifica farmaco'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 16),
              Text('Frequenza', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModeChip(mode: _FrequencyMode.daily, label: 'Tutti i giorni', theme: theme),
                  _buildModeChip(mode: _FrequencyMode.weekly, label: '1 volta/settimana', theme: theme),
                  _buildModeChip(mode: _FrequencyMode.customDays, label: 'Giorni specifici', theme: theme),
                ],
              ),
              if (_mode != _FrequencyMode.daily) ...[
                const SizedBox(height: 12),
                Text(
                  _mode == _FrequencyMode.weekly
                      ? 'In quale giorno della settimana?'
                      : 'Scegli i giorni della settimana:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in TherapyItem.weekdayShortLabels.entries)
                      ChoiceChip(
                        label: Text(
                          entry.value,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _selectedWeekdays.contains(entry.key)
                                ? Colors.white
                                : cs.onSurface,
                          ),
                        ),
                        selected: _selectedWeekdays.contains(entry.key),
                        selectedColor: activeBg,
                        backgroundColor: cs.surfaceContainerHighest,
                        showCheckmark: false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: _selectedWeekdays.contains(entry.key)
                              ? activeBg
                              : cs.outlineVariant,
                        ),
                        onSelected: _busy ? null : (_) => _toggleWeekday(entry.key),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
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
