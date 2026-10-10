import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/clinical_parameter.dart';
import '../utils/date_format.dart';

/// Foglio per aggiungere o modificare un valore clinico.
///
/// - Aggiunta ([existing] null): la data parte VUOTA e va scelta: serve la
///   data dell'esame, non il momento in cui l'utente inserisce il dato.
/// - Modifica ([existing] valorizzato): valore e data precompilati, con "Elimina".
///
/// Stessa logica di `entry_edit_sheet.dart` (stato "occupato", chiusura solo
/// se il foglio è ancora la route in cima, messaggio d'errore dal provider),
/// ma con il selettore di data, che i campi solo-testo di quel foglio non hanno.
Future<void> showClinicalEntrySheet({
  required BuildContext context,
  required ClinicalParameterType type,
  ClinicalReading? existing,
  required Future<bool> Function(double value, DateTime date) onSave,
  Future<bool> Function()? onDelete,
  String? Function()? errorMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _ClinicalEntrySheet(
      type: type,
      existing: existing,
      onSave: onSave,
      onDelete: onDelete,
      errorMessage: errorMessage,
    ),
  );
}

class _ClinicalEntrySheet extends StatefulWidget {
  final ClinicalParameterType type;
  final ClinicalReading? existing;
  final Future<bool> Function(double value, DateTime date) onSave;
  final Future<bool> Function()? onDelete;
  final String? Function()? errorMessage;

  const _ClinicalEntrySheet({
    required this.type,
    required this.existing,
    required this.onSave,
    required this.onDelete,
    required this.errorMessage,
  });

  @override
  State<_ClinicalEntrySheet> createState() => _ClinicalEntrySheetState();
}

class _ClinicalEntrySheetState extends State<_ClinicalEntrySheet> {
  late final TextEditingController _valueCtrl;
  final _dateCtrl = TextEditingController();
  DateTime? _date;
  String? _error;
  bool _busy = false;
  ModalRoute<dynamic>? _route;

  static const _genericError = 'Operazione non riuscita. Controlla la connessione e riprova.';

  ClinicalParameterType get _type => widget.type;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _valueCtrl = TextEditingController(text: e == null ? '' : _type.format(e.value));
    if (e != null) _setDate(e.measuredOn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _setDate(DateTime d) {
    _date = d;
    _dateCtrl.text = AppDateFormat.dayMonthYear(d);
  }

  /// Chiude solo se il foglio è ancora la route in cima (vedi entry_edit_sheet).
  void _closeSheet() {
    if (_route?.isCurrent ?? false) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: ClinicalParameterType.earliestDate,
      lastDate: today,
      helpText: "Data dell'esame",
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _setDate(picked);
      _error = null;
    });
  }

  String? _validate(double? value) {
    if (value == null) return 'Scrivi il valore come numero.';
    if (!_type.isInRange(value)) {
      return 'Il valore deve essere tra ${_type.format(_type.min)} e ${_type.format(_type.max)} ${_type.unit}.';
    }
    if (_date == null) return "Scegli la data dell'esame.";
    return null;
  }

  Future<void> _save() async {
    final value = _type.tryParse(_valueCtrl.text);
    final message = _validate(value);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onSave(_type.round(value!), _date!);
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

  Future<void> _delete() async {
    final cs = Theme.of(context).colorScheme;
    setState(() {
      _busy = true;
      _error = null;
    });

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sei sicuro?'),
            content: const Text("Vuoi davvero eliminare questo valore? L'operazione non è reversibile."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Indietro'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (!confirmed) {
      setState(() => _busy = false);
      return;
    }

    final ok = await widget.onDelete!();
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
            Text(_isEdit ? 'Modifica ${_type.label}' : 'Aggiungi ${_type.label}',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(_type.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            Text('Valore (${_type.unit})', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _valueCtrl,
              enabled: !_busy,
              keyboardType: TextInputType.numberWithOptions(decimal: _type.allowsDecimals),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(_type.allowsDecimals ? r'[0-9.,]' : r'[0-9]')),
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(suffixText: _type.unit),
            ),
            const SizedBox(height: 16),
            Text("Data dell'esame", style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _dateCtrl,
              readOnly: true,
              enabled: !_busy,
              onTap: _pickDate,
              decoration: const InputDecoration(
                hintText: 'Tocca per scegliere la data',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 16)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salva'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                textStyle: theme.textTheme.labelLarge,
              ),
            ),
            if (_isEdit && widget.onDelete != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Elimina questo valore'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error, width: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}