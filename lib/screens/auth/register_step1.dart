import 'package:flutter/material.dart';
import '../../models/request/registration_request.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_date_picker.dart';

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
    final picked = await AppDateTimePicker.pickDate(
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

  Widget _buildSexOption({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? cs.primary : AppColors.accentText;
    final isSelected = widget.data.sesso == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            widget.data.sesso = isSelected ? null : value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : cs.outlineVariant.withValues(alpha: 0.7),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? activeColor : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? activeColor : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profilo base', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (v) => widget.data.name = v.trim(),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Inserisci il tuo nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _surnameController,
              decoration: const InputDecoration(labelText: 'Cognome'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (v) => widget.data.surname = v.trim(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Inserisci il tuo cognome' : null,
            ),
            const SizedBox(height: 16),
            AppPickerTile(
              icon: Icons.calendar_today_outlined,
              caption: 'Data di nascita',
              valueText: widget.data.birth == null ? 'gg/mm/aaaa' : _formatDate(widget.data.birth!),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 18),
            // Selezione sesso senza dicitura "Sesso biologico"
            Row(
              children: [
                _buildSexOption(
                  context: context,
                  value: 'maschio',
                  label: 'Maschio',
                  icon: Icons.male_rounded,
                ),
                const SizedBox(width: 12),
                _buildSexOption(
                  context: context,
                  value: 'femmina',
                  label: 'Femmina',
                  icon: Icons.female_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Altezza disposta uno sopra l'altro con label "cm" a destra del campo
            TextFormField(
              controller: _altezzaController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Altezza',
                suffixText: 'cm',
                suffixStyle: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => widget.data.altezza = int.tryParse(v),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 50 || n > 250) return 'Inserisci un\'altezza valida';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Peso disposto uno sopra l'altro con label "kg" a destra del campo
            TextFormField(
              controller: _pesoController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Peso',
                suffixText: 'kg',
                suffixStyle: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => widget.data.peso = double.tryParse(v),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 20 || n > 300) return 'Inserisci un peso valido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              textInputAction: TextInputAction.done,
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
