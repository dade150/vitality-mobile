import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ponte nativo per salvare referti direttamente in Galleria / Archivio
/// (Android MediaStore, senza permessi runtime su Android 10+) e aprirli con
/// le app di sistema (Galleria, Google Foto, lettore PDF) tramite FileProvider.
class DeviceFileService {
  static const MethodChannel _channel =
      MethodChannel('com.example.vitality_assist/device_files');

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static bool isImageMime(String mimeType) =>
      mimeType.toLowerCase().startsWith('image/');

  /// Rileva il MIME reale dai magic bytes per evitare estensioni o MIME errati.
  static String detectMimeType(Uint8List bytes, {String? fallbackExt}) {
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D) {
      return 'application/pdf';
    }
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
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
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
    switch ((fallbackExt ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/pdf';
    }
  }

  static String extensionForMime(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/webp':
        return 'webp';
      default:
        return 'pdf';
    }
  }

  /// Salva un referto direttamente nella Galleria (`Pictures/diaLog2`) se è un'immagine,
  /// oppure nella cartella Archivio (`Download/diaLog2`) se è un PDF.
  /// Restituisce il percorso leggibile di destinazione (o `null` se annullato/fallito).
  static Future<String?> saveReportToDevice({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) return null;

    if (isAndroid) {
      final method =
          isImageMime(mimeType) ? 'saveImageToGallery' : 'saveFileToDownloads';
      final res = await _channel.invokeMapMethod<String, dynamic>(method, {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      return res?['location']?.toString() ??
          (isImageMime(mimeType) ? 'Galleria/diaLog2' : 'Download/diaLog2');
    }

    final ext = extensionForMime(mimeType);
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salva Referto Clinico',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [ext],
      bytes: bytes,
    );
    if (outputPath != null && outputPath.isNotEmpty) {
      try {
        await File(outputPath).writeAsBytes(bytes);
      } catch (_) {}
      return outputPath;
    }
    return null;
  }

  /// Apre il referto con il selettore nativo Android ("Apri con Galleria / Google Foto / Lettore PDF").
  static Future<bool> openWithExternalApp({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? chooserTitle,
  }) async {
    if (bytes.isEmpty) return false;

    if (isAndroid) {
      final title = chooserTitle ??
          (isImageMime(mimeType) ? 'Apri con Galleria' : 'Apri referto con');
      final ok = await _channel.invokeMethod<bool>('openFileWithChooser', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
        'chooserTitle': title,
      });
      return ok == true;
    }

    final saved = await saveReportToDevice(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    return saved != null;
  }

  /// Renderizza in-memory le pagine di un PDF su Android (`PdfRenderer`) per la visualizzazione
  /// diretta dentro l'app con zoom. Restituisce `null` su piattaforme non supportate.
  static Future<List<Uint8List>?> renderPdfPages(
    Uint8List bytes, {
    int maxPages = 10,
  }) async {
    if (!isAndroid || bytes.isEmpty) return null;
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('renderPdfPages', {
        'bytes': bytes,
        'maxPages': maxPages,
      });
      if (raw == null) return null;
      return raw.whereType<Uint8List>().toList();
    } catch (_) {
      return null;
    }
  }
}
