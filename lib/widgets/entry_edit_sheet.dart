import 'package:flutter/material.dart';

/// Campo di testo del foglio di modifica.
class EntryField {
  final String label;
  final String initialValue;
  final TextInputType keyboardType;
  final int maxLines;

  const EntryField({
    required this.label,
    required this.initialValue,
    this.keyboardType = TextInputType.number,
    this.maxLines = 1,
  });
}

/// Una voce modificabile (una misurazione, un pasto, un'attività).
class EditableEntry {
  final String id;
  final String title;
  final String subtitle;
  final List<EntryField> fields;

  const EditableEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fields,
  });
}

/// Mostra l'elenco delle voci del giorno; toccandone una si apre il form
/// con "Salva" e "Elimina" (con conferma). A operazione riuscita il foglio
/// si chiude: la schermata si aggiorna da sola perché il provider notifica.
Future<void> showEditEntriesSheet({
  required BuildContext context,
  required String title,
  required String deleteLabel,
  required List<EditableEntry> entries,
  required String? Function(EditableEntry entry, List<String> values) validate,
  required Future<bool> Function(EditableEntry entry, List<String> values) onSave,
  required Future<bool> Function(EditableEntry entry) onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _EditEntriesSheet(
      title: title,
      deleteLabel: deleteLabel,
      entries: entries,
      validate: validate,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}

class _EditEntriesSheet extends StatefulWidget {
  final String title;
  final String deleteLabel;
  final List<EditableEntry> entries;
  final String? Function(EditableEntry entry, List<String> values) validate;
  final Future<bool> Function(EditableEntry entry, List<String> values) onSave;
  final Future<bool> Function(EditableEntry entry) onDelete;

  const _EditEntriesSheet({
    required this.title,
    required this.deleteLabel,
    required this.entries,
    required this.validate,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditEntriesSheet> createState() => _EditEntriesSheetState();
}

class _EditEntriesSheetState extends State<_EditEntriesSheet> {
  EditableEntry? _selected;
  List<TextEditingController> _controllers = [];
  String? _error;
  bool _busy = false;
  ModalRoute<dynamic>? _route;

  static const _genericError = 'Operazione non riuscita. Controlla la connessione e riprova.';

  @override
  void initState() {
    super.initState();
    if (widget.entries.length == 1) _open(widget.entries.first);
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
    _controllers = [];
    super.dispose();
  }

  /// Rilascia i controller non più usati. Il rilascio viene rinviato a fine
  /// frame: i [TextField] che li hanno ancora montati vengono aggiornati o
  /// rimossi proprio in quel frame, così nessuno resta a contatto con un
  /// controller già smontato.
  void _disposeControllers() {
    final old = _controllers;
    _controllers = [];
    if (old.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }

  void _open(EditableEntry entry) {
    _disposeControllers();
    _selected = entry;
    _error = null;
    _controllers = [for (final f in entry.fields) TextEditingController(text: f.initialValue)];
  }

  /// Chiude il foglio solo se è ancora la route in cima: se nel frattempo è
  /// stato già chiuso (back o trascinamento), un pop incondizionato
  /// chiuderebbe la schermata sottostante.
  void _closeSheet() {
    if (_route?.isCurrent ?? false) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final entry = _selected!;
    final values = _controllers.map((c) => c.text.trim()).toList();
    final message = widget.validate(entry, values);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onSave(entry, values);
    if (!mounted) return;
    if (ok) {
      _closeSheet();
    } else {
      setState(() {
        _busy = false;
        _error = _genericError;
      });
    }
  }

  Future<void> _delete() async {
    final entry = _selected!;
    final cs = Theme.of(context).colorScheme;

    // Blocca back e barriera finché la conferma e l'eliminazione sono in
    // corso: il foglio non deve potersi chiudere da solo durante l'await.
    setState(() {
      _busy = true;
      _error = null;
    });

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sei sicuro?'),
            content: const Text("Vuoi davvero eliminare questo dato? L'operazione non è reversibile."),
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

    final ok = await widget.onDelete(entry);
    if (!mounted) return;
    if (ok) {
      _closeSheet();
    } else {
      setState(() {
        _busy = false;
        _error = _genericError;
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
            if (_selected == null) ..._buildList(theme) else ..._buildForm(theme, cs),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildList(ThemeData theme) {
    return [
      Text(widget.title, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('Scegli quale voce modificare.', style: theme.textTheme.bodySmall),
      const SizedBox(height: 16),
      for (final e in widget.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              title: Text(e.title, style: theme.textTheme.titleSmall),
              subtitle: Text(e.subtitle, style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => setState(() => _open(e)),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildForm(ThemeData theme, ColorScheme cs) {
    final entry = _selected!;
    return [
      Row(
        children: [
          if (widget.entries.length > 1)
            IconButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _disposeControllers();
                        _selected = null;
                        _error = null;
                      }),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          Expanded(child: Text(entry.title, style: theme.textTheme.headlineSmall)),
        ],
      ),
      Padding(
        padding: EdgeInsets.only(left: widget.entries.length > 1 ? 8 : 0, bottom: 16),
        child: Text(entry.subtitle, style: theme.textTheme.bodySmall),
      ),
      for (var i = 0; i < entry.fields.length; i++) ...[
        Text(entry.fields[i].label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _controllers[i],
          enabled: !_busy,
          keyboardType: entry.fields[i].keyboardType,
          maxLines: entry.fields[i].maxLines,
        ),
        const SizedBox(height: 16),
      ],
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
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _busy ? null : _delete,
        icon: const Icon(Icons.delete_outline_rounded),
        label: Text(widget.deleteLabel),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error, width: 2),
        ),
      ),
    ];
  }
}