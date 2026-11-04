import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/app_date_picker.dart';
import '../utils/date_format.dart';

/// Formatter che facilita la digitazione dell'orario senza orologio:
/// accetta cifre e `:`, e se l'utente digita 3 o 4 cifre di fila (es. `0830`)
/// inserisce automaticamente i due punti (`08:30`).
class TimeTextInputFormatter extends TextInputFormatter {
  const TimeTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll('.', ':');
    if (raw.contains(':')) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9:]'), '');
      if (cleaned.length > 5) return oldValue;
      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) return oldValue;
    if (digits.length >= 3 && newValue.text.length > oldValue.text.length) {
      final formatted = '${digits.substring(0, 2)}:${digits.substring(2)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// Selettore accessibile di Data e Ora ("Quando?") pensato per pazienti T2D,
/// **senza quadrante dell'orologio**.
///
/// - Se [showTime] è `true`: mostra il pulsante **Giorno** (calendario), una
///   casella di testo semplice **Orario (es. 08:30)** e quattro scelte rapide
///   a singolo tocco (*Adesso*, *08:00*, *13:00*, *20:00*).
/// - Se [showTime] è `false`: mostra solo la scelta del **Giorno** (*Oggi*,
///   *Ieri* o calendario).
class WhenSelector extends StatefulWidget {
  final String label;
  final DateTime value;
  final bool enabled;
  final bool showTime;
  final bool showPresets;
  final ValueChanged<DateTime> onChanged;

  const WhenSelector({
    super.key,
    this.label = 'Quando hai fatto la misurazione?',
    required this.value,
    this.enabled = true,
    this.showTime = true,
    this.showPresets = true,
    required this.onChanged,
  });

  static final DateTime _earliestDate = DateTime(2000, 1, 1);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String formatDayLabel(DateTime d) {
    final now = DateTime.now();
    if (sameDay(d, now)) return 'Oggi, ${AppDateFormat.daySmall(d)} ${AppDateFormat.monthShort(d)}';
    if (sameDay(d, now.subtract(const Duration(days: 1)))) {
      return 'Ieri, ${AppDateFormat.daySmall(d)} ${AppDateFormat.monthShort(d)}';
    }
    return '${AppDateFormat.daySmall(d)} ${AppDateFormat.monthShort(d)} ${d.year}';
  }

  /// Impedisce di selezionare un orario nel futuro se il giorno scelto è oggi.
  static DateTime clampNotFuture(DateTime candidate) {
    final now = DateTime.now();
    return candidate.isAfter(now) ? now : candidate;
  }

  @override
  State<WhenSelector> createState() => _WhenSelectorState();
}

class _WhenSelectorState extends State<WhenSelector> {
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = DateTime(widget.value.year, widget.value.month, widget.value.day);
    final picked = await AppDateTimePicker.pickDate(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: WhenSelector._earliestDate,
      lastDate: today,
      helpText: 'Scegli il giorno',
    );
    if (picked == null) return;
    final updated = DateTime(
      picked.year,
      picked.month,
      picked.day,
      widget.value.hour,
      widget.value.minute,
    );
    widget.onChanged(WhenSelector.clampNotFuture(updated));
  }

  Future<void> _pickTime(BuildContext context) async {
    final initialTime = TimeOfDay(hour: widget.value.hour, minute: widget.value.minute);
    final picked = await AppDateTimePicker.pickTime(
      context: context,
      initialTime: initialTime,
      helpText: 'Scegli l\'orario',
    );
    if (picked == null) return;
    final updated = DateTime(
      widget.value.year,
      widget.value.month,
      widget.value.day,
      picked.hour,
      picked.minute,
    );
    widget.onChanged(WhenSelector.clampNotFuture(updated));
  }

  void _applyPreset(DateTime target) {
    widget.onChanged(WhenSelector.clampNotFuture(target));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final v = widget.value;
    final isNowSelected = v.difference(now).abs().inMinutes <= 2 && WhenSelector.sameDay(v, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        if (!widget.showTime) ...[
          AppPickerTile(
            icon: Icons.calendar_month_outlined,
            caption: 'Giorno',
            valueText: WhenSelector.formatDayLabel(v),
            enabled: widget.enabled,
            onTap: () => _pickDate(context),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: AppPickerTile(
                  icon: Icons.calendar_month_outlined,
                  caption: 'Giorno',
                  valueText: WhenSelector.formatDayLabel(v),
                  enabled: widget.enabled,
                  onTap: () => _pickDate(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: AppPickerTile(
                  icon: Icons.schedule_rounded,
                  caption: 'Orario',
                  valueText: WhenSelector.hhmm(v),
                  enabled: widget.enabled,
                  onTap: () => _pickTime(context),
                ),
              ),
            ],
          ),
          if (widget.showPresets) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickTimeChip(
                  label: 'Adesso',
                  selected: isNowSelected,
                  enabled: widget.enabled,
                  onTap: () => _applyPreset(DateTime.now()),
                ),
                _QuickTimeChip(
                  label: '08:00',
                  selected: !isNowSelected && v.hour == 8 && v.minute == 0,
                  enabled: widget.enabled,
                  onTap: () => _applyPreset(DateTime(v.year, v.month, v.day, 8, 0)),
                ),
                _QuickTimeChip(
                  label: '13:00',
                  selected: !isNowSelected && v.hour == 13 && v.minute == 0,
                  enabled: widget.enabled,
                  onTap: () => _applyPreset(DateTime(v.year, v.month, v.day, 13, 0)),
                ),
                _QuickTimeChip(
                  label: '20:00',
                  selected: !isNowSelected && v.hour == 20 && v.minute == 0,
                  enabled: widget.enabled,
                  onTap: () => _applyPreset(DateTime(v.year, v.month, v.day, 20, 0)),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _QuickTimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickTimeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeBg = isDark ? cs.primary : AppColors.accent;

    return Material(
      color: selected ? activeBg : cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? activeBg : cs.outlineVariant,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: selected ? (isDark ? cs.onPrimary : Colors.white) : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Definizione di un campo numerico per il foglio di inserimento parametri vitali.
class VitalFieldSpec {
  final String label;
  final String hint;
  final String unit;
  final bool decimal;

  const VitalFieldSpec({
    required this.label,
    required this.hint,
    required this.unit,
    this.decimal = false,
  });
}

/// Foglio che sale dal basso (stile `clinical_entry_sheet.dart`) per inserire
/// Glicemia o Pressione Arteriosa con scelta semplificata di data e ora.
Future<void> showVitalEntrySheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required IconData icon,
  required List<VitalFieldSpec> fields,
  required DateTime initialDateTime,
  required String? Function(List<double?> values, DateTime when) validate,
  required Future<bool> Function(List<double> values, DateTime when) onSave,
  String? Function()? errorMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _VitalEntrySheet(
      title: title,
      subtitle: subtitle,
      icon: icon,
      fields: fields,
      initialDateTime: initialDateTime,
      validate: validate,
      onSave: onSave,
      errorMessage: errorMessage,
    ),
  );
}

class _VitalEntrySheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<VitalFieldSpec> fields;
  final DateTime initialDateTime;
  final String? Function(List<double?> values, DateTime when) validate;
  final Future<bool> Function(List<double> values, DateTime when) onSave;
  final String? Function()? errorMessage;

  const _VitalEntrySheet({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.fields,
    required this.initialDateTime,
    required this.validate,
    required this.onSave,
    required this.errorMessage,
  });

  @override
  State<_VitalEntrySheet> createState() => _VitalEntrySheetState();
}

class _VitalEntrySheetState extends State<_VitalEntrySheet> {
  late final List<TextEditingController> _controllers;
  late DateTime _when;
  String? _error;
  bool _busy = false;
  ModalRoute<dynamic>? _route;

  static const _genericError = 'Salvataggio non riuscito. Controlla la connessione e riprova.';

  @override
  void initState() {
    super.initState();
    _controllers = [for (final _ in widget.fields) TextEditingController()];
    _when = WhenSelector.clampNotFuture(widget.initialDateTime);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  void _closeSheet() {
    if (_route?.isCurrent ?? false) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final values = _controllers.map((c) => _parseNumber(c.text)).toList();
    final msg = widget.validate(values, _when);
    if (msg != null) {
      setState(() => _error = msg);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onSave(values.cast<double>(), _when);
    if (!mounted) return;
    if (ok) {
      _closeSheet();
    } else {
      setState(() {
        _busy = false;
        _error = widget.errorMessage?.call() ?? _genericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(widget.icon, color: cs.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title, style: theme.textTheme.headlineSmall),
                      if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(widget.subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.fields.length == 1) ...[
              Text(
                '${widget.fields.first.label} (${widget.fields.first.unit})',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controllers.first,
                autofocus: true,
                enabled: !_busy,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 26),
                keyboardType: TextInputType.numberWithOptions(
                  decimal: widget.fields.first.decimal,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(widget.fields.first.decimal ? r'[-0-9.,]' : r'[-0-9]'),
                  ),
                ],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: widget.fields.first.hint,
                  suffixText: widget.fields.first.unit,
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.fields[i].label, style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _controllers[i],
                            autofocus: i == 0,
                            enabled: !_busy,
                            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 26),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: widget.fields[i].decimal,
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(widget.fields[i].decimal ? r'[-0-9.,]' : r'[-0-9]'),
                              ),
                            ],
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                            decoration: InputDecoration(
                              hintText: widget.fields[i].hint,
                              suffixText: widget.fields[i].unit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            WhenSelector(
              value: _when,
              enabled: !_busy,
              onChanged: (newWhen) => setState(() {
                _when = newWhen;
                _error = null;
              }),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: cs.error, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salva'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                shape: const StadiumBorder(),
                textStyle: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
