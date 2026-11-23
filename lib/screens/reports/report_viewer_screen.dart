import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/medical_report.dart';
import '../../services/device_file_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';

/// Visualizzatore in-app per referti medici salvati (immagini e PDF).
///
/// Permette di:
/// - consultare subito il referto direttamente nell'app (con pinch-to-zoom);
/// - aprirlo con un tocco nell'app esterna di sistema ("Apri con Galleria" / lettore PDF);
/// - salvarne una copia in Galleria (`Pictures/diaLog2`) o Archivio (`Download/diaLog2`).
class ReportViewerScreen extends StatefulWidget {
  final MedicalReport report;
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const ReportViewerScreen({
    super.key,
    required this.report,
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  bool _openingExternal = false;
  bool _savingDevice = false;

  bool _loadingPdf = false;
  List<Uint8List>? _pdfPages;

  bool get _isImage => DeviceFileService.isImageMime(widget.mimeType);

  @override
  void initState() {
    super.initState();
    if (!_isImage) {
      _loadPdfPreview();
    }
  }

  Future<void> _loadPdfPreview() async {
    setState(() => _loadingPdf = true);
    final pages = await DeviceFileService.renderPdfPages(widget.bytes);
    if (!mounted) return;
    setState(() {
      _pdfPages = pages;
      _loadingPdf = false;
    });
  }

  Future<void> _openExternal() async {
    if (_openingExternal) return;
    setState(() => _openingExternal = true);
    try {
      final ok = await DeviceFileService.openWithExternalApp(
        bytes: widget.bytes,
        fileName: widget.fileName,
        mimeType: widget.mimeType,
        chooserTitle: _isImage ? 'Apri con Galleria' : 'Apri PDF con',
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessuna app trovata per aprire questo file. Puoi salvarlo in Archivio.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile aprire con un\'app esterna in questo momento.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingExternal = false);
    }
  }

  Future<void> _saveToDevice() async {
    if (_savingDevice) return;
    setState(() => _savingDevice = true);
    try {
      final dest = await DeviceFileService.saveReportToDevice(
        bytes: widget.bytes,
        fileName: widget.fileName,
        mimeType: widget.mimeType,
      );
      if (!mounted) return;
      if (dest != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Referto salvato in $dest.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile salvare il referto sul dispositivo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDevice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.report.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              AppDateFormat.dayMonthYear(widget.report.date),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: _isImage ? _buildImageViewer(theme, cs) : _buildPdfViewer(theme, cs),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _savingDevice ? null : _saveToDevice,
                  icon: _savingDevice
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isImage ? Icons.save_alt_rounded : Icons.download_rounded,
                          size: 19,
                        ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_isImage ? 'Salva in Galleria' : 'Salva in Archivio'),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openingExternal ? null : _openExternal,
                  icon: _openingExternal
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _isImage ? Icons.photo_library_outlined : Icons.open_in_new_rounded,
                          size: 19,
                        ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_isImage ? 'Apri con Galleria' : 'Apri con...'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageViewer(ThemeData theme, ColorScheme cs) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 5.0,
        child: Center(
          child: Image.memory(
            widget.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Impossibile visualizzare questa immagine. Usa "Apri con Galleria" qui sotto.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer(ThemeData theme, ColorScheme cs) {
    if (_loadingPdf) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparazione anteprima PDF...'),
          ],
        ),
      );
    }

    final pages = _pdfPages;
    if (pages != null && pages.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: pages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, idx) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    'Pagina ${idx + 1} di ${pages.length}',
                    style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _ZoomablePdfPage(pageBytes: pages[idx]),
              ),
            ],
          );
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 64, color: cs.primary),
            const SizedBox(height: 14),
            Text(
              widget.fileName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tocca "Apri con..." qui sotto per leggere il documento PDF con l\'app del tuo dispositivo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pagina PDF con pinch-to-zoom che non interferisce con lo scorrimento verticale
/// della lista finché la pagina resta a scala 1x.
class _ZoomablePdfPage extends StatefulWidget {
  final Uint8List pageBytes;

  const _ZoomablePdfPage({required this.pageBytes});

  @override
  State<_ZoomablePdfPage> createState() => _ZoomablePdfPageState();
}

class _ZoomablePdfPageState extends State<_ZoomablePdfPage> {
  final TransformationController _controller = TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncZoomState() {
    final zoomedNow = _controller.value.getMaxScaleOnAxis() > 1.05;
    if (zoomedNow != _isZoomed && mounted) {
      setState(() => _isZoomed = zoomedNow);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: _isZoomed,
      onInteractionUpdate: (_) => _syncZoomState(),
      onInteractionEnd: (_) => _syncZoomState(),
      child: Image.memory(widget.pageBytes, fit: BoxFit.contain),
    );
  }
}
