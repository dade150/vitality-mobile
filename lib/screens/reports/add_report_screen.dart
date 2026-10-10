import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/clinical_parameter.dart';
import '../../models/medical_report.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/reports_provider.dart';
import '../../services/error_handler.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
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
  final _dateCtrl = TextEditingController();
  DateTime? _examDate;
  String? _error;

  static const _genericError = 'Operazione non riuscita. Controlla la connessione e riprova.';

  @override
  void dispose() {
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
      allowedExtensions: ['pdf'],
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

    final title = filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
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
      _setExamDate(DateTime.now());
      _selected
        ..clear()
        ..addAll(result.extracted.map((e) => e.type));
      if (result.extracted.isEmpty) {
        _error = 'Nessun parametro riconosciuto nel documento.';
      }
    });

    // Appare subito nella sezione "I Miei Referti" della schermata clinica.
    context.read<ReportsProvider>().addReport(
          MedicalReport(
            id: result.id,
            title: title,
            date: DateTime.now(),
            extractedParams: {
              for (final v in result.extracted)
                v.type.label: '${v.type.format(v.value)} ${v.type.unit}',
            },
          ),
        );
  }

  // ---------------------------------------------------------------- Salvataggio

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? today,
      firstDate: ClinicalParameterType.earliestDate,
      lastDate: today,
      helpText: "Data dell'esame",
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (picked == null || !mounted) return;
    setState(() => _setExamDate(picked));
  }

  /// Salva i valori spuntati nei parametri clinici (conferma manuale).
  Future<void> _saveValues() async {
    final date = _examDate;
    final values = _selected.isEmpty
        ? const <ExtractedValue>[]
        : _result!.extracted.where((v) => _selected.contains(v.type)).toList();
    if (date == null) {
      setState(() => _error = "Scegli la data dell'esame.");
      return;
    }
    if (values.isEmpty) {
      setState(() => _error = 'Spunta almeno un valore da salvare.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final clinical = context.read<ClinicalProvider>();
    for (final v in values) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(values.length == 1
            ? 'Valore salvato nei parametri clinici.'
            : '${values.length} valori salvati nei parametri clinici.'),
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
              ),
              // Titolo sempre arancione, indipendentemente dal tema (chiaro/scuro).
              Text('Aggiungi Referto', style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 16),
          if (result == null) ...[
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickFile,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(_filename ?? 'Scegli il documento (PDF)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_uploading ? 'Caricamento...' : 'Carica Documento'),
              ),
            ),
          ] else ...[
            Text('Parametri Clinici Estratti', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Spunta quelli che vuoi salvare: compaiono in "Parametri Clinici".',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (result.extracted.isEmpty)
              Text('Il documento non contiene parametri riconosciuti.',
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))
            else
              SectionCard(
                child: Column(
                  children: [
                    for (final v in result.extracted)
                      InkWell(
                        onTap: _saving ? null : () => _toggle(v.type),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _selected.contains(v.type),
                              onChanged: _saving ? null : (_) => _toggle(v.type),
                            ),
                            Expanded(
                              child: _paramRow(context,
                                  icon: v.type.icon,
                                  label: v.type.label,
                                  value: '${v.type.format(v.value)} ${v.type.unit}'),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Text("Data dell'esame", style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dateCtrl,
                      readOnly: true,
                      enabled: !_saving,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        hintText: 'Tocca per scegliere la data',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
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
          if (result != null) ...[
            const SizedBox(height: 28),
            Text('Note e Screening Medici', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _noteRow(context,
                      icon: Icons.visibility_outlined,
                      title: 'Visita Oculistica',
                      date: '15 Maggio 2023',
                      note: 'Retinopatia assente, prossimo controllo tra 1 anno.'),
                  const SizedBox(height: 16),
                  _noteRow(context,
                      icon: Icons.directions_walk_outlined,
                      title: 'Controllo Piede',
                      date: '10 Aprile 2023',
                      note: 'Nessuna lesione riscontrata, sensibilità conservata.'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Attività Recente', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.description_outlined, color: cs.primary),
                    title: const Text('Referto Cardiologico'),
                    subtitle: const Text('Oggi, 10:30'),
                    trailing: Icon(Icons.check_circle_rounded, color: cs.secondary),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.image_outlined, color: cs.primary),
                    title: const Text('Ricetta Medica'),
                    subtitle: const Text('Ieri, 15:45'),
                    trailing: Icon(Icons.check_circle_rounded, color: cs.secondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paramRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(color: cs.primary)),
        ],
      ),
    );
  }

  Widget _noteRow(BuildContext context,
      {required IconData icon, required String title, required String date, required String note}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                  Text(date, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(note, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }
}
