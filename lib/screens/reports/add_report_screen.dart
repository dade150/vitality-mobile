import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/clinical_parameter.dart';
import '../../models/medical_report.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/reports_provider.dart';
import '../../services/device_file_service.dart';
import '../../services/error_handler.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_date_picker.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/report_privacy_mask_dialog.dart';
import '../../widgets/section_card.dart';
import '../../widgets/vital_entry_sheet.dart';

enum _ReportSourceChoice {
  camera,
  gallery,
  pdf,
}

class _PickedReportFile {
  final Uint8List bytes;
  final String filename;

  const _PickedReportFile({required this.bytes, required this.filename});
}

/// Flusso di caricamento referto (Foto, Galleria o PDF) con analisi automatica
/// e conferma Human-in-the-Loop dei parametri clinici estratti.
class AddReportScreen extends StatefulWidget {
  final Uint8List? initialBytes;
  final String? initialFilename;

  const AddReportScreen({
    super.key,
    this.initialBytes,
    this.initialFilename,
  });

  /// Apre direttamente il menu a 3 opzioni (Foto Referto Clinico, Carica da Galleria,
  /// Carica PDF); appena il documento è selezionato/confermato apre subito l'analisi
  /// e la schermata di salvataggio parametri, saltando qualsiasi pagina intermedia.
  static Future<void> startFlow(BuildContext context) async {
    final aiConsent = context.read<ProfileProvider>().profile?.aiHealthConsent ?? false;
    if (!aiConsent) {
      AppFeedback.showErrorDialog(
        context,
        title: 'Consenso richiesto',
        message:
            'Il consenso al trattamento dati sanitari con IA è disattivato. Riattivalo da Impostazioni > Privacy e gestione dati per caricare i referti.',
      );
      return;
    }

    final picked = await _pickReportWithOptions(context);
    if (picked == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddReportScreen(
          initialBytes: picked.bytes,
          initialFilename: picked.filename,
        ),
      ),
    );
  }

  static String _timestampedPhotoName(Uint8List bytes) {
    final now = DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${p2(now.month)}${p2(now.day)}_${p2(now.hour)}${p2(now.minute)}${p2(now.second)}';
    final mime = DeviceFileService.detectMimeType(bytes, fallbackExt: 'png');
    final ext = DeviceFileService.extensionForMime(mime);
    return 'Referto_$stamp.$ext';
  }

  static Future<_PickedReportFile?> _pickReportWithOptions(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final choice = await showModalBottomSheet<_ReportSourceChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.document_scanner_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Foto Referto Clinico', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(modalContext, _ReportSourceChoice.camera),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.photo_library_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Carica da Galleria', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(modalContext, _ReportSourceChoice.gallery),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.picture_as_pdf_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Carica PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(modalContext, _ReportSourceChoice.pdf),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !context.mounted) return null;

    if (choice == _ReportSourceChoice.pdf) {
      return _pickPdfReport(context);
    }
    return _pickImageReport(
      context,
      source: choice == _ReportSourceChoice.camera ? ImageSource.camera : ImageSource.gallery,
    );
  }

  static Future<_PickedReportFile?> _pickImageReport(
    BuildContext context, {
    required ImageSource source,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null || !context.mounted) return null;

      final rawBytes = await pickedFile.readAsBytes();
      if (!context.mounted) return null;

      final sanitized = await ReportPrivacyMaskDialog.show(
        context,
        imageBytes: rawBytes,
        fileName: pickedFile.name,
      );
      if (sanitized == null || !context.mounted) return null;

      final mimeType = detectImageMimeType(sanitized, fallback: '');
      if (mimeType.isEmpty) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Formato immagine non supportato. Usa un file JPG, PNG o WebP.',
        );
        return null;
      }
      if (sanitized.length > kMaxUploadAttachmentBytes) {
        AppFeedback.showErrorDialog(
          context,
          message: 'L\'immagine supera il limite massimo di 5 MB. Prova con una foto più leggera.',
        );
        return null;
      }

      final fileName = source == ImageSource.camera
          ? _timestampedPhotoName(sanitized)
          : normalizeMaskedFileName(pickedFile.name, sanitized);

      // Salva automaticamente una copia della foto scattata in Galleria (Pictures/diaLog2)
      if (source == ImageSource.camera && DeviceFileService.isAndroid) {
        try {
          final dest = await DeviceFileService.saveReportToDevice(
            bytes: sanitized,
            fileName: fileName,
            mimeType: mimeType,
          );
          if (dest != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Foto referto salvata in $dest.')),
            );
          }
        } catch (_) {}
      }

      return _PickedReportFile(bytes: sanitized, filename: fileName);
    } catch (_) {
      if (context.mounted) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Impossibile selezionare l\'immagine. Riprova.',
        );
      }
      return null;
    }
  }

  static Future<_PickedReportFile?> _pickPdfReport(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !context.mounted) return null;

      final file = result.files.first;
      Uint8List? rawBytes = file.bytes;
      if (rawBytes == null && file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          rawBytes = await f.readAsBytes();
        }
      }
      if (!context.mounted) return null;

      if (rawBytes == null || rawBytes.isEmpty) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Impossibile leggere il file selezionato.',
        );
        return null;
      }
      if (!isPdfBytes(rawBytes)) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Il file selezionato non è un documento PDF valido.',
        );
        return null;
      }
      if (rawBytes.length > kMaxUploadAttachmentBytes) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Il documento PDF supera il limite massimo di 5 MB.',
        );
        return null;
      }

      return _PickedReportFile(bytes: rawBytes, filename: file.name);
    } catch (_) {
      if (context.mounted) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Impossibile selezionare il PDF. Riprova.',
        );
      }
      return null;
    }
  }

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

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null && widget.initialFilename != null) {
      _bytes = widget.initialBytes;
      _filename = widget.initialFilename;
      _uploading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _upload();
      });
    }
  }

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
    _dateCtrl.text = WhenSelector.formatDayLabel(d);
  }

  void _toggle(ClinicalParameterType type) {
    setState(() {
      if (!_selected.remove(type)) _selected.add(type);
    });
  }

  // ------------------------------------------------------------- Selezione + Upload immediato

  Future<void> _pickAndUpload() async {
    FocusScope.of(context).unfocus();
    final aiConsent = context.read<ProfileProvider>().profile?.aiHealthConsent ?? false;
    if (!aiConsent) {
      setState(() {
        _error = 'Hai revocato il consenso al trattamento con Intelligenza Artificiale (GDPR Art. 9). '
            'Riattivalo da Impostazioni > Privacy e gestione dati per analizzare automaticamente i referti.';
      });
      return;
    }

    final picked = await AddReportScreen._pickReportWithOptions(context);
    if (picked == null || !mounted) return;

    setState(() {
      _filename = picked.filename;
      _bytes = picked.bytes;
      _result = null;
      _selected.clear();
      _disposeValueControllers();
      _examDate = null;
      _dateCtrl.clear();
      _error = null;
    });

    await _upload();
  }

  // ------------------------------------------------------------- Caricamento

  Future<void> _upload() async {
    final aiConsent = context.read<ProfileProvider>().profile?.aiHealthConsent ?? false;
    if (!aiConsent) {
      setState(() {
        _uploading = false;
        _error = 'Hai revocato il consenso al trattamento con Intelligenza Artificiale (GDPR Art. 9). '
            'Riattivalo da Impostazioni > Privacy e gestione dati per analizzare automaticamente i referti.';
      });
      return;
    }

    final bytes = _bytes;
    final filename = _filename;
    if (bytes == null || filename == null) {
      setState(() {
        _uploading = false;
        _error = 'Scegli prima il documento da caricare.';
      });
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });

    final title = filename.replaceAll(RegExp(r'\.(pdf|png|jpg|jpeg|webp|heic|heif)$', caseSensitive: false), '');
    final ReportUploadResult result;
    try {
      result = await ReportService.upload(bytes: bytes, filename: filename, title: title);
    } catch (e, st) {
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

    return AppScaffold(
      navIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Torna indietro',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  result == null ? 'Caricamento referto' : 'Parametri del referto',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_uploading) ...[
            SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Caricamento e analisi del referto...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (_filename != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _filename!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (result == null) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _pickAndUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Carica referto'),
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
                  Text("Data dell'esame", style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  AppPickerTile(
                    icon: Icons.calendar_month_outlined,
                    caption: 'Giorno',
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
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving || _uploading ? null : _saveValues,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Salvataggio...' : 'Salva nei parametri clinici'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving || _uploading ? null : _pickAndUpload,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Carica un altro referto'),
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
