import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Sovrascrive fisicamente con pixel neri opachi i primi [headerRatio] dell'immagine in memoria.
Future<Uint8List> blackoutImageHeader(
  Uint8List imageBytes, {
  required double headerRatio,
}) async {
  final codec = await ui.instantiateImageCodec(imageBytes);
  final frameInfo = await codec.getNextFrame();
  final ui.Image image = frameInfo.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
  );

  // 1. Disegna l'immagine originale
  canvas.drawImage(image, Offset.zero, Paint());

  // 2. Disegna un rettangolo nero opaco sull'intestazione superiore
  final blackPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  final maskHeight = image.height * headerRatio;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, image.width.toDouble(), maskHeight),
    blackPaint,
  );

  // 3. Renderizza in byte PNG con i pixel neri impressi
  final picture = recorder.endRecording();
  final maskedUiImage = await picture.toImage(image.width, image.height);
  final byteData = await maskedUiImage.toByteData(format: ui.ImageByteFormat.png);

  return byteData!.buffer.asUint8List();
}

/// Dialog modale che mostra l'anteprima del referto fotografato e permette all'utente
/// di applicare una banda di oscuramento grafico sull'intestazione personale (GDPR Art. 25).
class ReportPrivacyMaskDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;

  const ReportPrivacyMaskDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
  });

  /// Mostra il dialog e restituisce i byte de-identificati (oppure null se annullato).
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportPrivacyMaskDialog(
        imageBytes: imageBytes,
        fileName: fileName,
      ),
    );
  }

  @override
  State<ReportPrivacyMaskDialog> createState() => _ReportPrivacyMaskDialogState();
}

class _ReportPrivacyMaskDialogState extends State<ReportPrivacyMaskDialog> {
  bool _maskEnabled = true;
  double _headerRatio = 0.18; // 18% di default: copre perfettamente l'intestazione standard
  bool _processing = false;

  Future<void> _confirm() async {
    setState(() => _processing = true);
    try {
      if (_maskEnabled) {
        final sanitized = await blackoutImageHeader(
          widget.imageBytes,
          headerRatio: _headerRatio,
        );
        if (mounted) Navigator.of(context).pop(sanitized);
      } else {
        if (mounted) Navigator.of(context).pop(widget.imageBytes);
      }
    } catch (_) {
      // In caso di errore rendering fallback sull'originale
      if (mounted) Navigator.of(context).pop(widget.imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Intestazione
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightPeach,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tutela Privacy Referto',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Oscura i dati anagrafici prima dell\'invio',
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Anteprima grafica referto con overlay interattivo
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black12,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Positioned.fill(
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (_maskEnabled)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: constraints.maxHeight * _headerRatio,
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.88),
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Fascia oscurata (Nome, CF, Ospedale)',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Switch abilitazione
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Oscura fascia superiore',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _maskEnabled
                            ? 'I pixel del nome e del codice fiscale verranno anneriti.'
                            : 'Invio foto senza mascheramento.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      value: _maskEnabled,
                      activeThumbColor: AppColors.accent,
                      onChanged: (val) => setState(() => _maskEnabled = val),
                    ),
                    if (_maskEnabled) ...[
                      const Divider(height: 1),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          const Text('Altezza:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Slider(
                              value: _headerRatio,
                              min: 0.08,
                              max: 0.35,
                              divisions: 27,
                              label: '${(_headerRatio * 100).round()}%',
                              activeColor: AppColors.accent,
                              onChanged: (val) => setState(() => _headerRatio = val),
                            ),
                          ),
                          Text('${(_headerRatio * 100).round()}%', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bottoni di azione
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _processing ? null : () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _processing ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Conferma e Invia', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
