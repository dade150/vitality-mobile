import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/clinical_parameter.dart';
import '../../models/medical_report.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/reports_provider.dart';
import '../../services/error_handler.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_date_picker.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_card.dart';

/// Carica un referto (PDF) al backend, che lo salva su Storage ed estrae i
/// valori clinici. Una volta arrivata la risposta l'utente SCEGLIE quali
/// valori salvare (conferma manuale) e in quale data: solo allora finiscono
/// in `diabetes_data` tramite [ClinicalProvider].
class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  bool _uploading = false;
  bool _saving = false;

  String? _filename;
  List<int>? _bytes;

  ReportUploadResult? _result;

  final Set<ClinicalParameterType> _selected = {};
  final Map<ClinicalParameterType, TextEditingController> _valueCtrls = {};
  final _dateCtrl = TextEditingController();
  DateTime? _examDate;
  String? _error;

  static const _genericError = 'Operazione non riuscita. Controlla la connessione e riprova.';

  void _disposeValueControllers() {
    for (final ctrl in _valueCtrls.values) {
      ctrl.dispose();
    }
    _valueCtrls.clear();
  }

  @override
  void dispose() {
    _disposeValueControllers();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _setExamDate(DateTime d) {
    _examDate = d;
    _dateCtrl.text = AppDateFormat.dayMonthYear(d);
  }

  void _toggle(ClinicalParameterType type) {
    setState(() {
      if (!_selected.remove(type)) _selected.add(type);
    });
  }

  // ------------------------------------------------------------- Selezione

  Future<void> _pickFile() async {
    FocusScope.of(context).unfocus();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Non riesco a leggere il file selezionato.');
      return;
    }
    setState(() {
      _filename = file.name;
      _bytes = bytes;
      _result = null;
      _selected.clear();
      _disposeValueControllers();
      _examDate = null;
      _dateCtrl.clear();
      _error = null;
    });
  }

  // ------------------------------------------------------------- Caricamento

  Future<void> _upload() async {
    final bytes = _bytes;
    final filename = _filename;
    if (bytes == null || filename == null) {
      setState(() => _error = 'Scegli prima il documento da caricare.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });

    final title = filename.replaceAll(RegExp(r'\.(pdf|png|jpg|jpeg|webp)$', caseSensitive: false), '');
    final ReportUploadResult result;
    try {
      result = await ReportService.upload(bytes: bytes, filename: filename, title: title);
    } catch (e, st) {
      // Classifica: errore atteso -> messaggio qui; imprevisto -> schermata
      // di errore (già aperta da ErrorHandler).
      final failure = ErrorHandler.handle(e, st, 'AddReportScreen.upload');
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = failure.unexpected ? null : (failure.message.isNotEmpty ? failure.message : _genericError);
      });
      return;
    }
    if (!mounted) return;

    setState(() {
      _uploading = false;
      _result = result;
      _setExamDate(result.reportDate ?? DateTime.now());
      _disposeValueControllers();
      for (final item in result.extracted) {
        _valueCtrls[item.type] = TextEditingController(
          text: item.type.format(item.value),
        );
      }
      _selected
        ..clear()
        ..addAll(result.extracted.map((e) => e.type));
      if (result.extracted.isEmpty) {
        _error = 'Nessun parametro riconosciuto nel documento. Puoi aggiungerli manualmente qui sotto.';
      }
    });

    // Appare subito nella sezione "I Miei Referti" della schermata clinica.
    context.read<ReportsProvider>().addReport(
          MedicalReport(
            id: result.id,
            title: title,
            date: result.reportDate ?? DateTime.now(),
            cleanSummary: result.cleanSummary,
            filePath: result.filePath,
            extractedParams: {
              for (final v in result.extracted)
                v.type.label: '${v.type.format(v.value)} ${v.type.unit}',
            },
          ),
        );
  }

  // ---------------------------------------------------------------- Salvataggio

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await AppDateTimePicker.pickDate(
      context: context,
      initialDate: _examDate ?? today,
      firstDate: ClinicalParameterType.earliestDate,
      lastDate: today,
      helpText: "Data dell'esame",
    );
    if (picked == null || !mounted) return;
    setState(() => _setExamDate(picked));
  }

  void _addMissingParameter(ClinicalParameterType type) {
    setState(() {
      _valueCtrls.putIfAbsent(type, () => TextEditingController());
      _selected.add(type);
      _error = null;
    });
  }

  Future<void> _showAddParameterDialog() async {
    FocusScope.of(context).unfocus();
    final missing = ClinicalParameterType.values
        .where((t) => !_valueCtrls.containsKey(t))
        .toList();
    if (missing.isEmpty) return;

    final chosen = await showModalBottomSheet<ClinicalParameterType>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final cs = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aggiungi parametro clinico', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final t in missing)
                  ListTile(
                    leading: Icon(t.icon, color: cs.primary),
                    title: Text(t.label, style: theme.textTheme.titleSmall),
                    subtitle: Text('Unità: ${t.unit}', style: theme.textTheme.bodySmall),
                    onTap: () => Navigator.of(sheetCtx).pop(t),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      _addMissingParameter(chosen);
    }
  }

  /// Salva i valori spuntati e modificati nei parametri clinici (conferma manuale).
  Future<void> _saveValues() async {
    FocusScope.of(context).unfocus();
    final date = _examDate;
    if (date == null) {
      setState(() => _error = "Scegli la data dell'esame.");
      return;
    }

    final selectedTypes = _valueCtrls.keys.where((t) => _selected.contains(t)).toList();
    if (selectedTypes.isEmpty) {
      setState(() => _error = 'Spunta almeno un valore da salvare.');
      return;
    }

    final parsedValues = <ExtractedValue>[];
    for (final type in selectedTypes) {
      final rawText = _valueCtrls[type]?.text ?? '';
      final parsed = type.tryParse(rawText);
      if (parsed == null) {
        setState(() => _error = 'Inserisci un numero valido per ${type.label}.');
        return;
      }
      if (!type.isInRange(parsed)) {
        setState(
          () => _error =
              'Il valore di ${type.label} deve essere tra ${type.format(type.min)} e ${type.format(type.max)} ${type.unit}.',
        );
        return;
      }
      parsedValues.add(ExtractedValue(type: type, value: type.round(parsed)));
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final clinical = context.read<ClinicalProvider>();
    for (final v in parsedValues) {
      final ok = await clinical.addReading(v.type, v.value, date);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = clinical.errorMessage ?? _genericError;
        });
        return;
      }
    }

    if (!mounted) return;
    final res = _result;
    if (res != null) {
      final title = (_filename ?? 'Referto medico')
          .replaceAll(RegExp(r'\.(pdf|png|jpg|jpeg|webp)$', caseSensitive: false), '');
      context.read<ReportsProvider>().addReport(
            MedicalReport(
              id: res.id,
              title: title,
              date: date,
              cleanSummary: res.cleanSummary,
              filePath: res.filePath,
              extractedParams: {
                for (final v in parsedValues)
                  v.type.label: '${v.type.format(v.value)} ${v.type.unit}',
              },
            ),
          );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parsedValues.length == 1
            ? 'Valore salvato nei parametri clinici.'
            : '${parsedValues.length} valori salvati nei parametri clinici.'),
      ),
    );
    Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final result = _result;

    final isDark = theme.brightness == Brightness.dark;
    final accentTitle = isDark ? cs.primary : AppColors.accentText;

    return AppScaffold(
      navIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Torna indietro',
              ),
              const SizedBox(width: 4),
              Text(
                'Aggiungi referto',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: accentTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tutela Privacy (GDPR): i PDF digitali vengono anonimizzati in memoria prima dell\'analisi. Se carichi una foto di un referto cartaceo, inquadra solo la tabella dei valori o copri l\'intestazione con Nome e Codice Fiscale.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickFile,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(_filename ?? 'Scegli il documento (PDF o immagine)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_uploading ? 'Caricamento ed analisi...' : 'Carica e analizza documento'),
              ),
            ),
          ] else ...[
            if (result.cleanSummary != null && result.cleanSummary!.trim().isNotEmpty) ...[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.summarize_outlined, size: 20, color: cs.primary),
                        const SizedBox(width: 8),
                        Text('Sintesi clinica oggettiva', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.cleanSummary!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Parametri clinici estratti', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Spunta quelli che vuoi salvare e tocca il valore per correggerlo se necessario.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_valueCtrls.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nessun parametro riconosciuto automaticamente.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  for (final entry in _valueCtrls.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _selected.contains(entry.key),
                            onChanged: _saving ? null : (_) => _toggle(entry.key),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _saving ? null : () => _toggle(entry.key),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: entry.key.containerColor(isDark),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(entry.key.icon, color: entry.key.color(isDark), size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        entry.key.label,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 128,
                            child: TextField(
                              controller: entry.value,
                              enabled: !_saving,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: entry.key.color(isDark),
                                fontWeight: FontWeight.w700,
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: entry.key.allowsDecimals,
                                signed: false,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(entry.key.allowsDecimals ? r'[0-9.,]' : r'[0-9]'),
                                ),
                              ],
                              onChanged: (_) {
                                if (!_selected.contains(entry.key)) {
                                  setState(() => _selected.add(entry.key));
                                } else if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                suffixText: ' ${entry.key.unit}',
                                suffixStyle: theme.textTheme.bodySmall?.copyWith(
                                  color: entry.key.color(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_valueCtrls.length < ClinicalParameterType.values.length) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _saving ? null : _showAddParameterDialog,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Aggiungi parametro mancante'),
                      ),
                    ),
                  ],
                  const Divider(),
                  const SizedBox(height: 12),
                  AppPickerTile(
                    icon: Icons.calendar_month_outlined,
                    caption: "Data dell'esame",
                    valueText: _examDate == null ? 'Tocca per scegliere la data' : _dateCtrl.text,
                    enabled: !_saving,
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _uploading ? null : _saveValues,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Salvataggio...' : 'Salva nei parametri clinici'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving || _uploading ? null : _pickFile,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Scegli un altro documento'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 16)),
          ],
        ],
      ),
    );
  }
}
