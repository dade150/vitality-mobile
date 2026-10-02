import 'package:flutter/material.dart';
import '../../models/request/registration_request.dart';

class RegisterStep1Profile extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final RegistrationData data;

  const RegisterStep1Profile({
    super.key,
    required this.formKey,
    required this.data,
  });

  @override
  State<RegisterStep1Profile> createState() => _RegisterStep1ProfileState();
}

class _RegisterStep1ProfileState extends State<RegisterStep1Profile> {
  late final _nameController = TextEditingController(text: widget.data.name);
  late final _surnameController = TextEditingController(text: widget.data.surname);
  late final _altezzaController =
      TextEditingController(text: widget.data.altezza?.toString() ?? '');
  late final _pesoController =
      TextEditingController(text: widget.data.peso?.toString() ?? '');
  late final _noteController = TextEditingController(text: widget.data.noteAnamnestiche);

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _altezzaController.dispose();
    _pesoController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.data.birth ?? DateTime(now.year - 60, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Data di nascita',
    );
    if (picked != null) {
      setState(() => widget.data.birth = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profilo Base', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => widget.data.name = v.trim(),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Inserisci il tuo nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _surnameController,
              decoration: const InputDecoration(labelText: 'Cognome'),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => widget.data.surname = v.trim(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Inserisci il tuo cognome' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data di nascita'),
                child: Text(
                  widget.data.birth == null ? 'gg/mm/aaaa' : _formatDate(widget.data.birth!),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Sesso biologico', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'maschio', label: Text('Maschio')),
                ButtonSegment(value: 'femmina', label: Text('Femmina')),
              ],
              selected: {if (widget.data.sesso != null) widget.data.sesso!},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) =>
                  setState(() => widget.data.sesso = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _altezzaController,
                    decoration: const InputDecoration(labelText: 'Altezza (cm)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => widget.data.altezza = int.tryParse(v),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 50 || n > 250) return 'Non valida';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _pesoController,
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => widget.data.peso = double.tryParse(v),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 20 || n > 300) return 'Non valido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note anamnestiche (opzionale)',
                hintText: 'Altre patologie o informazioni utili da tenere in considerazione',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              onChanged: (v) => widget.data.noteAnamnestiche = v,
            ),
          ],
        ),
      ),
    );
  }
}