import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/clinical_parameter.dart';
import '../models/meal_entry.dart';
import '../models/proposed_entry.dart';
import '../services/health_service.dart';
import '../theme/app_colors.dart';
import 'vital_entry_sheet.dart';

class ClinicalProposalCard extends StatefulWidget {
  final String messageId;
  final ProposedEntry proposal;
  final VoidCallback onDismiss;
  final Future<bool> Function(Map<String, dynamic> finalData) onConfirm;

  const ClinicalProposalCard({
    super.key,
    required this.messageId,
    required this.proposal,
    required this.onDismiss,
    required this.onConfirm,
  });

  @override
  State<ClinicalProposalCard> createState() => _ClinicalProposalCardState();
}

class _ClinicalProposalCardState extends State<ClinicalProposalCard> {
  final _formKey = GlobalKey<FormState>();

  // Dati mutabili locali
  late Map<String, dynamic> _localData;
  late DateTime _selectedDateTime;

  // Controllers per i vari campi
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _localData = Map<String, dynamic>.from(widget.proposal.data);
    _initDateTime();
    _initControllers();
  }

  void _initDateTime() {
    final rawDate = _localData['measured_at'] ??
        _localData['meal_at'] ??
        _localData['activity_at'] ??
        _localData['appointment_at'] ??
        _localData['taken_at'] ??
        _localData['date'];

    if (rawDate is DateTime) {
      _selectedDateTime = rawDate;
    } else if (rawDate != null) {
      _selectedDateTime = DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now();
    } else {
      _selectedDateTime = DateTime.now();
    }
  }

  void _initControllers() {
    _localData.forEach((key, value) {
      if (value != null && !_isDateField(key)) {
        _controllers[key] = TextEditingController(text: value.toString());
      }
    });

    // Assicurati che i campi specifici abbiano un controller anche se inizialmente null
    _ensureControllerForTargetTable();
  }

  bool _isDateField(String key) {
    return key.contains('_at') || key == 'date';
  }

  void _ensureControllerForTargetTable() {
    void ensure(String key, [String defaultValue = '']) {
      if (!_controllers.containsKey(key)) {
        final existing = _localData[key]?.toString();
        _controllers[key] = TextEditingController(text: existing ?? defaultValue);
      }
    }

    switch (widget.proposal.targetTable) {
      case TargetTable.diabetesData:
        ensure('metric_value');
        ensure('metric_type', 'GLICEMIA');
        break;
      case TargetTable.meals:
        ensure('description');
        ensure('calories', '0');
        ensure('carbs_grams');
        break;
      case TargetTable.physicalActivities:
        ensure('duration_minutes');
        ensure('steps');
        ensure('notes');
        break;
      case TargetTable.appointments:
        ensure('title');
        ensure('doctor_name');
        ensure('notes');
        break;
      case TargetTable.therapyLogs:
        ensure('therapy_id');
        break;
      case TargetTable.therapies:
        ensure('drug_name');
        ensure('dosage', '-');
        ensure('frequency', 'Giornaliera');
        ensure('scheduled_time', '08:00');
        ensure('notes');
        break;
      case TargetTable.profile:
        ensure('peso');
        ensure('altezza');
        ensure('note_anamnestiche');
        break;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isMissing(String fieldKey) {
    if (!widget.proposal.missingFields.contains(fieldKey)) return false;
    final ctrl = _controllers[fieldKey];
    return ctrl == null || ctrl.text.trim().isEmpty;
  }

  Map<String, dynamic> _collectFinalData() {
    final result = Map<String, dynamic>.from(_localData);
    _controllers.forEach((k, v) {
      final val = v.text.trim();
      if (val.isNotEmpty) {
        result[k] = val;
      }
    });

    final dateIso = _selectedDateTime.toUtc().toIso8601String();
    switch (widget.proposal.targetTable) {
      case TargetTable.diabetesData:
        result['measured_at'] = dateIso;
        break;
      case TargetTable.meals:
        result['meal_at'] = dateIso;
        break;
      case TargetTable.physicalActivities:
        result['activity_at'] = dateIso;
        break;
      case TargetTable.appointments:
        result['appointment_at'] = dateIso;
        break;
      case TargetTable.therapyLogs:
        result['taken_at'] = dateIso;
        break;
      default:
        result['date'] = dateIso;
        break;
    }
    return result;
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    final finalData = _collectFinalData();
    await widget.onConfirm(finalData);
  }

  Future<void> _pickFutureAppointmentDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isBefore(now) ? now : _selectedDateTime,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 730)),
      helpText: 'Scegli la data dell\'appuntamento',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      helpText: 'Scegli l\'orario dell\'appuntamento',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final p = widget.proposal;
    final isSaved = p.status == ProposalStatus.saved;
    final isSaving = p.status == ProposalStatus.saving;
    final hasMissing = !p.isComplete && p.missingFields.isNotEmpty;

    // Colori di stato coerenti con il design system
    final Color topStripeColor = isSaved
        ? AppColors.secondarySeed
        : (hasMissing ? cs.error : AppColors.accent);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSaved
              ? AppColors.secondarySeed.withValues(alpha: 0.4)
              : (hasMissing
                  ? cs.error.withValues(alpha: 0.5)
                  : (isDark ? cs.outlineVariant : AppColors.lightBorder)),
          width: hasMissing || isSaved ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Barra superiore di evidenziazione stato
          Container(height: 5, color: topStripeColor),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 2. Header: Icona, Titolo, Categoria e Badge Stato
                  _buildHeader(theme, cs, isSaved, hasMissing),

                  // 3. Nota Assistente / LARN (se presente)
                  if (p.assistantNote != null && p.assistantNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildAssistantNote(theme, cs, isDark, p.assistantNote!),
                  ],

                  // 4. Banner Campi Mancanti (se incompleta)
                  if (hasMissing && !isSaved) ...[
                    const SizedBox(height: 10),
                    _buildMissingFieldsBanner(theme, cs),
                  ],

                  const SizedBox(height: 14),

                  // 5. Form Dinamico in base a TargetTable
                  _buildDynamicFields(theme, cs, isSaved || isSaving),

                  // 6. Messaggio di Errore di Salvataggio (se presente)
                  if (p.saveError != null && !isSaved) ...[
                    const SizedBox(height: 10),
                    Text(
                      p.saveError!,
                      style: TextStyle(color: cs.error, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 7. Footer Azioni (Ignora / Conferma e Salva oppure Stato Salvato)
                  _buildActionFooter(theme, cs, isSaved, isSaving),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs, bool isSaved, bool hasMissing) {
    final p = widget.proposal;
    final table = p.targetTable;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSaved
                ? AppColors.lightGreenContainer
                : (hasMissing ? cs.errorContainer : cs.primaryContainer),
          ),
          child: Icon(
            table.icon,
            color: isSaved
                ? AppColors.secondarySeed
                : (hasMissing ? cs.error : cs.primary),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                table.displayLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.summaryTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(theme, cs, isSaved, hasMissing),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme, ColorScheme cs, bool isSaved, bool hasMissing) {
    if (isSaved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.lightGreenContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondarySeed.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.secondarySeed, size: 14),
            const SizedBox(width: 4),
            Text(
              'Salvato',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.secondarySeed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (hasMissing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error, size: 14),
            const SizedBox(width: 4),
            Text(
              'Incompleto',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightPeach,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.accent, size: 15),
          const SizedBox(width: 4),
          Text(
            'Pronto',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantNote(ThemeData theme, ColorScheme cs, bool isDark, String note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLowest : AppColors.lightPeach.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? cs.outlineVariant : AppColors.lightBorder.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingFieldsBanner(ThemeData theme, ColorScheme cs) {
    final missingNames = widget.proposal.missingFields
        .map((f) => ProposedEntry.formatFieldName(f))
        .join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: cs.error, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Compila i campi evidenziati prima di salvare: $missingNames',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Dynamic Forms
  Widget _buildDynamicFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    switch (widget.proposal.targetTable) {
      case TargetTable.diabetesData:
        return _buildDiabetesFields(theme, cs, readOnly);
      case TargetTable.meals:
        return _buildMealFields(theme, cs, readOnly);
      case TargetTable.physicalActivities:
        return _buildActivityFields(theme, cs, readOnly);
      case TargetTable.appointments:
        return _buildAppointmentFields(theme, cs, readOnly);
      case TargetTable.therapyLogs:
        return _buildTherapyLogFields(theme, cs, readOnly);
      case TargetTable.therapies:
        return _buildTherapyFields(theme, cs, readOnly);
      case TargetTable.profile:
        return _buildProfileFields(theme, cs, readOnly);
    }
  }

  // 1. Diabetes Data Fields
  Widget _buildDiabetesFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    final rawType = (_localData['metric_type'] ?? 'GLICEMIA').toString().toUpperCase();
    final isPressure = rawType == 'PRESSIONE';
    final clinicalType = ClinicalParameterType.fromDb(rawType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPressure) ...[
          Row(
            children: [
              Expanded(
                child: _buildTextFormField(
                  keyName: 'metric_value',
                  label: 'Pressione (mmHg)',
                  hint: 'es. 120/80',
                  readOnly: readOnly,
                  validator: (v) => (v == null || !v.contains('/')) ? 'Formato 120/80' : null,
                ),
              ),
            ],
          ),
        ] else if (clinicalType != null) ...[
          _buildTextFormField(
            keyName: 'metric_value',
            label: '${clinicalType.label} (${clinicalType.unit})',
            hint: 'es. 6.8',
            readOnly: readOnly,
            keyboardType: TextInputType.numberWithOptions(decimal: clinicalType.allowsDecimals),
            validator: (v) {
              final val = clinicalType.tryParse(v ?? '');
              if (val == null || !clinicalType.isInRange(val)) {
                return 'Valore non valido';
              }
              return null;
            },
          ),
        ] else ...[
          _buildTextFormField(
            keyName: 'metric_value',
            label: 'Glicemia (mg/dL)',
            hint: 'es. 120',
            readOnly: readOnly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (n == null || n < 20 || n > 1000) return 'Inserisci un valore valido';
              return null;
            },
          ),
        ],
        const SizedBox(height: 12),
        WhenSelector(
          value: _selectedDateTime,
          enabled: !readOnly,
          showTime: clinicalType == null,
          label: 'Quando è stata effettuata la misurazione?',
          onChanged: (newDate) => setState(() => _selectedDateTime = newDate),
        ),
      ],
    );
  }

  // 2. Meal Fields
  Widget _buildMealFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    final rawMealType = (_localData['meal_type'] ?? 'PRANZO').toString().toUpperCase();
    final mealType = MealTypeLabel.fromDb(rawMealType, _selectedDateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MealType>(
          value: mealType,
          decoration: _inputDecoration(label: 'Tipo pasto', isMissing: false),
          items: MealType.values.map((t) {
            return DropdownMenuItem(value: t, child: Text(t.label));
          }).toList(),
          onChanged: readOnly
              ? null
              : (val) {
                  if (val != null) {
                    setState(() => _localData['meal_type'] = val.dbValue);
                  }
                },
        ),
        const SizedBox(height: 10),
        _buildTextFormField(
          keyName: 'description',
          label: 'Cosa hai mangiato?',
          hint: 'es. Pasta al pomodoro e insalata',
          readOnly: readOnly,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Descrizione obbligatoria' : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                keyName: 'carbs_grams',
                label: 'Carboidrati (g)',
                hint: 'es. 80',
                readOnly: readOnly,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                keyName: 'calories',
                label: 'Calorie (kcal)',
                hint: 'es. 450',
                readOnly: readOnly,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WhenSelector(
          value: _selectedDateTime,
          enabled: !readOnly,
          label: 'Orario del pasto',
          onChanged: (newDate) => setState(() => _selectedDateTime = newDate),
        ),
      ],
    );
  }

  // 3. Activity Fields
  Widget _buildActivityFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    final rawType = (_localData['activity_type'] ?? 'CAMMINATA').toString().toUpperCase();
    final currentType = HealthService.activityLabels.firstWhere(
      (l) => l.toUpperCase() == rawType || (rawType == 'BICICLETTA' && l == 'Ciclismo') || (rawType == 'PALESTRA' && l == 'Ginnastica'),
      orElse: () => 'Camminata',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: currentType,
          decoration: _inputDecoration(label: 'Tipo di attività', isMissing: false),
          items: HealthService.activityLabels.map((l) {
            return DropdownMenuItem(value: l, child: Text(l));
          }).toList(),
          onChanged: readOnly
              ? null
              : (val) {
                  if (val != null) {
                    setState(() => _localData['activity_type'] = val.toUpperCase());
                  }
                },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                keyName: 'duration_minutes',
                label: 'Durata (minuti)',
                hint: 'es. 30',
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Minimo 1 min';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                keyName: 'steps',
                label: 'Passi (opzionale)',
                hint: 'es. 3500',
                readOnly: readOnly,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTextFormField(
          keyName: 'notes',
          label: 'Note (opzionale)',
          hint: 'es. Passo svelto nel parco',
          readOnly: readOnly,
        ),
        const SizedBox(height: 12),
        WhenSelector(
          value: _selectedDateTime,
          enabled: !readOnly,
          label: 'Quando hai svolto l\'attività?',
          onChanged: (newDate) => setState(() => _selectedDateTime = newDate),
        ),
      ],
    );
  }

  // 4. Appointment Fields
  Widget _buildAppointmentFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    final dateFormat = DateFormat('EEEE d MMMM y, HH:mm', 'it_IT');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextFormField(
          keyName: 'title',
          label: 'Tipo visita / Titolo',
          hint: 'es. Visita Diabetologica di controllo',
          readOnly: readOnly,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Titolo obbligatorio' : null,
        ),
        const SizedBox(height: 10),
        _buildTextFormField(
          keyName: 'doctor_name',
          label: 'Medico o Luogo',
          hint: 'es. Dott. Rossi / Ospedale Maggiore',
          readOnly: readOnly,
        ),
        const SizedBox(height: 10),
        _buildTextFormField(
          keyName: 'notes',
          label: 'Note visita (opzionale)',
          hint: 'es. Portare esami sangue recenti',
          readOnly: readOnly,
        ),
        const SizedBox(height: 12),
        Text('Data e ora appuntamento', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        InkWell(
          onTap: readOnly ? null : _pickFutureAppointmentDateTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
              color: readOnly ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateFormat.format(_selectedDateTime),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!readOnly)
                  Icon(Icons.edit_calendar_rounded, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 5. Therapy Log Fields
  Widget _buildTherapyLogFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextFormField(
          keyName: 'therapy_id',
          label: 'ID Farmaco / Terapia',
          hint: 'es. 1',
          readOnly: readOnly,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'ID terapia obbligatorio' : null,
        ),
        const SizedBox(height: 12),
        WhenSelector(
          value: _selectedDateTime,
          enabled: !readOnly,
          label: 'Orario di assunzione',
          onChanged: (newDate) => setState(() => _selectedDateTime = newDate),
        ),
      ],
    );
  }

  // 6. Therapy Fields
  Widget _buildTherapyFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextFormField(
          keyName: 'drug_name',
          label: 'Nome farmaco',
          hint: 'es. Metformina',
          readOnly: readOnly,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome obbligatorio' : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                keyName: 'dosage',
                label: 'Dosaggio',
                hint: 'es. 500 mg',
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                keyName: 'scheduled_time',
                label: 'Orario (HH:MM)',
                hint: 'es. 08:00',
                readOnly: readOnly,
                inputFormatters: const [TimeTextInputFormatter()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTextFormField(
          keyName: 'frequency',
          label: 'Frequenza',
          hint: 'es. Giornaliera',
          readOnly: readOnly,
        ),
        const SizedBox(height: 10),
        _buildTextFormField(
          keyName: 'notes',
          label: 'Note (es. prima dei pasti)',
          hint: 'es. Subito prima di colazione',
          readOnly: readOnly,
        ),
      ],
    );
  }

  // 7. Profile Fields
  Widget _buildProfileFields(ThemeData theme, ColorScheme cs, bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                keyName: 'peso',
                label: 'Peso (kg)',
                hint: 'es. 75.5',
                readOnly: readOnly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                keyName: 'altezza',
                label: 'Altezza (cm)',
                hint: 'es. 175',
                readOnly: readOnly,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTextFormField(
          keyName: 'note_anamnestiche',
          label: 'Note cliniche / anamnesi',
          hint: 'es. Intolleranza al lattosio',
          readOnly: readOnly,
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required String keyName,
    required String label,
    required String hint,
    required bool readOnly,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final ctrl = _controllers[keyName];
    final isMissing = _isMissing(keyName);

    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        isMissing: isMissing,
      ),
      validator: validator ??
          (v) {
            if (isMissing && (v == null || v.trim().isEmpty)) {
              return 'Campo richiesto';
            }
            return null;
          },
      onChanged: (val) {
        if (isMissing) setState(() {});
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required bool isMissing,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isMissing ? cs.error : cs.outlineVariant,
          width: isMissing ? 1.6 : 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isMissing ? cs.error : AppColors.accent,
          width: 2.0,
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Action Footer
  Widget _buildActionFooter(ThemeData theme, ColorScheme cs, bool isSaved, bool isSaving) {
    if (isSaved) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.lightGreenContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all_rounded, color: AppColors.secondarySeed, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Dato registrato con successo nel diario',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondarySeed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Pulsante Annulla / Ignora
        Expanded(
          flex: 4,
          child: OutlinedButton.icon(
            onPressed: isSaving ? null : widget.onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Ignora'),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: cs.onSurfaceVariant,
              side: BorderSide(color: cs.outlineVariant),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Pulsante Conferma e Salva
        Expanded(
          flex: 6,
          child: FilledButton.icon(
            onPressed: isSaving ? null : _handleConfirm,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(isSaving ? 'Salvataggio...' : 'Conferma e Salva'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
