import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/error_handler.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';

/// Apre il modal bottom sheet per la configurazione e il download del Report Medico PDF.
Future<void> showPdfExportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) => const _PdfExportSheetContent(),
  );
}

class _PdfExportSheetContent extends StatefulWidget {
  const _PdfExportSheetContent();

  @override
  State<_PdfExportSheetContent> createState() => _PdfExportSheetContentState();
}

class _PdfExportSheetContentState extends State<_PdfExportSheetContent> {
  int _selectedMonths = 3;
  bool _isLoading = false;
  String? _errorMessage;

  final List<({int months, String label, String subtitle, bool isRecommended})> _options = const [
    (
      months: 2,
      label: 'Ultimi 2 mesi',
      subtitle: '60 giorni di monitoraggio e visite',
      isRecommended: false,
    ),
    (
      months: 3,
      label: 'Ultimi 3 mesi',
      subtitle: '90 giorni (Periodo ideale per la visita di controllo)',
      isRecommended: true,
    ),
    (
      months: 4,
      label: 'Ultimi 4 mesi',
      subtitle: '120 giorni di storico completo',
      isRecommended: false,
    ),
  ];

  Future<void> _generateAndSave() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Uint8List pdfBytes = await ReportService.downloadSummaryPdf(
        months: _selectedMonths,
      );

      if (!mounted) return;

      final now = DateTime.now();
      final defaultFileName =
          'Report_Medico_${_selectedMonths}M_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salva Report Medico PDF',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (outputPath != null && outputPath.isNotEmpty) {
        try {
          final file = File(outputPath);
          await file.writeAsBytes(pdfBytes);
        } catch (_) {
          // Se saveFile ha già scritto direttamente i bytes, ignoriamo errori di secondo accesso
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  outputPath != null
                      ? 'Report PDF salvato con successo.'
                      : 'Download del report completato.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e is AppFailure) {
          _errorMessage = e.message;
        } else {
          _errorMessage = 'Impossibile generare il PDF. Riprova più tardi.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barretta superiore di trascinamento
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header con icona e titolo
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.lightPeach,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Medico PDF',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Documento clinico multi-mensile stampabile',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Seleziona il periodo da includere nel report:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // Opzioni 2, 3, 4 mesi
            for (final opt in _options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: _isLoading ? null : () => setState(() => _selectedMonths = opt.months),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedMonths == opt.months
                          ? (theme.brightness == Brightness.dark
                              ? cs.surfaceContainerHigh
                              : AppColors.lightPeach.withValues(alpha: 0.5))
                          : cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMonths == opt.months
                            ? (theme.brightness == Brightness.dark ? cs.primary : AppColors.accentText)
                            : cs.outlineVariant.withValues(alpha: 0.4),
                        width: _selectedMonths == opt.months ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedMonths == opt.months
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _selectedMonths == opt.months
                              ? (theme.brightness == Brightness.dark ? cs.primary : AppColors.accentText)
                              : cs.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    opt.label,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (opt.isRecommended) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (theme.brightness == Brightness.dark
                                                ? cs.primary
                                                : AppColors.accentText)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Consigliato',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: theme.brightness == Brightness.dark
                                              ? cs.primary
                                              : AppColors.accentText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Pulsante di generazione / download
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateAndSave,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _isLoading ? 'Generazione in corso...' : 'Scarica e salva PDF',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
