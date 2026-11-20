import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Limite massimo accettato dal backend per un allegato (5 MB).
const int kMaxUploadAttachmentBytes = 5 * 1024 * 1024;

/// Budget di sicurezza per le immagini (3.5 MB) così che anche in Base64 (+33% su /chat)
/// restino ampiamente sotto i 5 MB di file e i 7 MB di body HTTP.
const int kTargetImageUploadBytes = 3500000;

/// Verifica la firma binaria `%PDF-` di un documento PDF.
bool isPdfBytes(List<int> bytes) {
  return bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2D;
}

/// Rileva il MIME reale dai magic bytes (es. PNG prodotto da [blackoutImageHeader])
/// per evitare mismatch MIME/firma lato backend (HTTP 400).
String detectImageMimeType(Uint8List bytes, {String fallback = 'image/jpeg'}) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return fallback;
}

/// Allinea l'estensione del nome file al formato reale rilevato dai magic bytes.
String normalizeMaskedFileName(String fileName, Uint8List bytes) {
  final mime = detectImageMimeType(bytes, fallback: '');
  if (mime.isEmpty) return fileName;

  final lower = fileName.toLowerCase();
  final dotIdx = fileName.lastIndexOf('.');
  final base = dotIdx > 0 ? fileName.substring(0, dotIdx) : fileName;

  if (mime == 'image/png' && !lower.endsWith('.png')) {
    return '$base.png';
  }
  if (mime == 'image/jpeg' && !lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) {
    return '$base.jpg';
  }
  if (mime == 'image/webp' && !lower.endsWith('.webp')) {
    return '$base.webp';
  }
  return fileName;
}

Future<({int width, int height})> _probeImageDimensions(Uint8List imageBytes) async {
  final codec = await ui.instantiateImageCodec(imageBytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      return (width: frame.image.width, height: frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

List<int> _candidateDimensions(int origMax, int maxDimension) {
  final start = origMax < maxDimension ? origMax : maxDimension;
  final candidates = <int>[start];
  for (final step in const [1280, 1024, 800, 640]) {
    if (step < start) {
      candidates.add(step);
    }
  }
  return candidates;
}

Future<Uint8List> _renderImageToPng(
  Uint8List imageBytes, {
  required int origW,
  required int origH,
  required int targetMaxDim,
  double? headerRatio,
}) async {
  final bool needsScale = origW > targetMaxDim || origH > targetMaxDim;
  final bool landscape = origW >= origH;

  final codec = await ui.instantiateImageCodec(
    imageBytes,
    targetWidth: needsScale && landscape ? targetMaxDim : null,
    targetHeight: needsScale && !landscape ? targetMaxDim : null,
  );

  ui.Image? image;
  ui.Picture? picture;
  ui.Image? renderedImage;
  try {
    final frame = await codec.getNextFrame();
    image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );

    // 1. Disegna l'immagine (decodificata dal codec nativo: supporta JPEG, PNG, WebP, HEIC/HEIF)
    canvas.drawImage(image, Offset.zero, Paint());

    // 2. Se richiesto, applica un rettangolo nero opaco sull'intestazione superiore
    if (headerRatio != null && headerRatio > 0) {
      final blackPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      final maskHeight = image.height * headerRatio;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), maskHeight),
        blackPaint,
      );
    }

    // 3. Renderizza in byte PNG puliti (senza metadati EXIF)
    picture = recorder.endRecording();
    renderedImage = await picture.toImage(image.width, image.height);
    final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Codifica PNG dell\'immagine non riuscita.');
    }
    return byteData.buffer.asUint8List();
  } finally {
    codec.dispose();
    image?.dispose();
    picture?.dispose();
    renderedImage?.dispose();
  }
}

/// Normalizza un'immagine prima dell'upload senza mascheramento:
/// - se è già JPEG, PNG o WebP entro [maxBytes], mantiene i byte originali invariati;
/// - se è un altro formato (es. HEIC/HEIF) oppure supera [maxBytes], la decodifica
///   e ridimensiona progressivamente in PNG finché rientra nel limite sicuro.
Future<Uint8List> normalizeImageForUpload(
  Uint8List imageBytes, {
  int maxBytes = kTargetImageUploadBytes,
  int maxDimension = 1600,
}) async {
  final detectedMime = detectImageMimeType(imageBytes, fallback: '');
  if (detectedMime.isNotEmpty && imageBytes.length <= maxBytes) {
    return imageBytes;
  }

  final dims = await _probeImageDimensions(imageBytes);
  final origMax = dims.width >= dims.height ? dims.width : dims.height;
  Uint8List? lastOutput;

  for (final targetDim in _candidateDimensions(origMax, maxDimension)) {
    final candidate = await _renderImageToPng(
      imageBytes,
      origW: dims.width,
      origH: dims.height,
      targetMaxDim: targetDim,
    );
    lastOutput = candidate;
    if (candidate.length <= maxBytes) {
      return candidate;
    }
  }

  if (lastOutput != null && lastOutput.length <= kMaxUploadAttachmentBytes) {
    return lastOutput;
  }
  throw StateError('Immagine troppo pesante anche dopo il ridimensionamento.');
}

/// Sovrascrive fisicamente con pixel neri opachi i primi [headerRatio] dell'immagine in memoria.
/// Ridimensiona progressivamente le immagini ad alta risoluzione per mantenere il PNG sotto i 3.5 MB
/// (ben al di sotto del limite backend di 5 MB e 7 MB Base64) rilasciando sempre le risorse native.
Future<Uint8List> blackoutImageHeader(
  Uint8List imageBytes, {
  required double headerRatio,
  int maxDimension = 1600,
  int maxBytes = kTargetImageUploadBytes,
}) async {
  final dims = await _probeImageDimensions(imageBytes);
  final origMax = dims.width >= dims.height ? dims.width : dims.height;
  Uint8List? lastOutput;

  for (final targetDim in _candidateDimensions(origMax, maxDimension)) {
    final candidate = await _renderImageToPng(
      imageBytes,
      origW: dims.width,
      origH: dims.height,
      targetMaxDim: targetDim,
      headerRatio: headerRatio,
    );
    lastOutput = candidate;
    if (candidate.length <= maxBytes) {
      return candidate;
    }
  }

  if (lastOutput != null && lastOutput.length <= kMaxUploadAttachmentBytes) {
    return lastOutput;
  }
  throw StateError('Immagine mascherata troppo pesante anche dopo il ridimensionamento.');
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
  String? _errorText;
  double? _imageAspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  Future<void> _resolveAspectRatio() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      try {
        final frame = await codec.getNextFrame();
        final ratio = frame.image.height > 0 ? frame.image.width / frame.image.height : null;
        frame.image.dispose();
        if (mounted && ratio != null && ratio > 0) {
          setState(() => _imageAspectRatio = ratio);
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // Se il probe fallisce, il widget usa il fallback grafico senza crash
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _processing = true;
      _errorText = null;
    });
    try {
      if (_maskEnabled) {
        final sanitized = await blackoutImageHeader(
          widget.imageBytes,
          headerRatio: _headerRatio,
        );
        if (mounted) Navigator.of(context).pop(sanitized);
      } else {
        // Anche senza fascia oscurante normalizza formato (es. HEIC -> PNG) e peso <= 3.5 MB
        final normalized = await normalizeImageForUpload(widget.imageBytes);
        if (mounted) Navigator.of(context).pop(normalized);
      }
    } catch (_) {
      // FAIL-CLOSED (GDPR Art. 25): non inviare MAI i byte originali non mascherati
      // se l'utente aveva richiesto l'oscuramento e il rendering ha fallito.
      if (mounted) {
        setState(() {
          _processing = false;
          _errorText = _maskEnabled
              ? 'Impossibile applicare la fascia oscurante su questa immagine. '
                  'Per proteggere i tuoi dati l\'invio è stato bloccato: riprova con una foto più leggera o ritagliata.'
              : 'Formato immagine non supportato o file troppo grande. '
                  'Riprova con una foto in formato JPG, PNG o WebP più leggera.';
        });
      }
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
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

              // Anteprima grafica referto allineata esattamente all'aspect ratio reale dell'immagine
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: _buildAlignedPreview(theme),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
                      onChanged: (val) => setState(() {
                        _maskEnabled = val;
                        _errorText = null;
                      }),
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

  Widget _buildPreviewError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'Anteprima non disponibile per questo file.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignedPreview(ThemeData theme) {
    Widget stackForBox(double boxHeight) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            widget.imageBytes,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => _buildPreviewError(theme),
          ),
          if (_maskEnabled)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: boxHeight * _headerRatio,
              child: Container(
                color: Colors.black.withValues(alpha: 0.88),
                padding: const EdgeInsets.all(6),
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
    }

    if (_imageAspectRatio != null) {
      return AspectRatio(
        aspectRatio: _imageAspectRatio!,
        child: LayoutBuilder(
          builder: (_, c) => stackForBox(c.maxHeight),
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, c) => Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Image.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildPreviewError(theme),
            ),
          ),
          if (_maskEnabled)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: c.maxHeight * _headerRatio,
              child: Container(color: Colors.black.withValues(alpha: 0.88)),
            ),
        ],
      ),
    );
  }
}
