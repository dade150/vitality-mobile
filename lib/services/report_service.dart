import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clinical_parameter.dart';
import '../models/medical_report.dart';
import '../screens/reports/report_viewer_screen.dart';
import 'api_services.dart';
import 'device_file_service.dart';
import 'error_handler.dart';

/// Un valore recuperato dal referto, già associato al parametro clinico.
class ExtractedValue {
  final ClinicalParameterType type;
  final double value;

  const ExtractedValue({required this.type, required this.value});
}

/// Esito dell'upload di un referto: id/path della riga salvata dal backend
/// e valori estratti dal documento.
class ReportUploadResult {
  final String id;
  final String? filePath;
  final List<ExtractedValue> extracted;
  final String? cleanSummary;
  final String? reportType;
  final DateTime? reportDate;
  final String? extractionMethod;

  const ReportUploadResult({
    required this.id,
    required this.filePath,
    required this.extracted,
    this.cleanSummary,
    this.reportType,
    this.reportDate,
    this.extractionMethod,
  });
}

/// Caricamento di un referto al backend Python (`/api/reports`).
///
/// Il backend riceve il file, lo salva su Supabase Storage (bucket privato,
/// cartella dell'utente), crea la riga in `patient_reports`, estrae i valori con
/// l'LLM, rimuove PII e genera l'embedding semantico; questa classe si limita a
/// inviare la richiesta e a tradurre la risposta.
class ReportService {
  static const _endpoint = '/api/reports';

  /// Scarica privatamente il referto (con JWT autenticato, senza esporre Signed URL
  /// nella cronologia del browser esterno) e lo apre direttamente nel visualizzatore
  /// in-app, offrendo accesso immediato a "Apri con Galleria / app esterna" e salvataggio locale.
  static Future<void> openReportWithExternalApp(BuildContext context, MedicalReport report) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final db = Supabase.instance.client;

    // Mostra breve indicatore durante il download autenticato
    var loaderOpen = true;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(width: 14),
                  Text('Apertura referto...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    void closeLoader() {
      if (loaderOpen && rootNavigator.canPop()) {
        loaderOpen = false;
        rootNavigator.pop();
      }
    }

    Uint8List? bytes;
    String ext = 'pdf';

    try {
      // 1. Download autenticato diretto dal bucket privato Storage sotto RLS (zero Signed URL nel browser)
      final path = report.filePath?.trim();
      if (path != null && path.isNotEmpty) {
        try {
          final downloaded = await db.storage.from('patient-reports').download(path);
          if (downloaded.isNotEmpty) {
            bytes = downloaded;
            final dotIdx = path.lastIndexOf('.');
            if (dotIdx > 0 && dotIdx < path.length - 1) {
              final candidate = path.substring(dotIdx + 1).toLowerCase();
              if (const {'pdf', 'png', 'jpg', 'jpeg', 'webp'}.contains(candidate)) {
                ext = candidate;
              }
            }
          }
        } catch (stErr, stTrace) {
          ErrorHandler.logOnly(stErr, stTrace, 'ReportService.storageDownload');
          // Fallback al download PDF dal backend se il file non è presente in Storage
        }
      }

      // 2. Fallback: scarica il documento PDF generato dal backend (/api/reports/{id}/document)
      final numId = int.tryParse(report.id);
      if (bytes == null) {
        if (numId == null) {
          closeLoader();
          messenger?.showSnackBar(
            const SnackBar(content: Text('Documento ancora in fase di sincronizzazione. Riprova tra poco.')),
          );
          return;
        }
        final response = await ApiService.get(
          '$_endpoint/$numId/document',
          timeout: const Duration(seconds: 30),
        );
        if (response.bodyBytes.isEmpty) {
          throw const AppFailure('Il documento del referto è vuoto.');
        }
        bytes = response.bodyBytes;
        ext = 'pdf';
      }

      closeLoader();
      if (!context.mounted) return;

      final fileBytes = bytes;
      final mimeType = DeviceFileService.detectMimeType(fileBytes, fallbackExt: ext);
      final resolvedExt = DeviceFileService.extensionForMime(mimeType);
      final safeName = report.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fallbackLabel = numId != null ? 'Referto_$numId' : 'Referto';
      final fileName = '${safeName.isEmpty ? fallbackLabel : safeName}.$resolvedExt';

      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ReportViewerScreen(
            report: report,
            bytes: fileBytes,
            fileName: fileName,
            mimeType: mimeType,
          ),
        ),
      );
    } catch (e, st) {
      ErrorHandler.logOnly(e, st, 'ReportService.openReport');
      closeLoader();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            e is AppFailure ? e.message : 'Impossibile aprire il referto in questo momento.',
          ),
        ),
      );
    }
  }

  /// Scarica dal backend il report PDF clinico aggregato per il medico (2, 3 o 4 mesi).
  static Future<Uint8List> downloadSummaryPdf({required int months}) async {
    if (months != 2 && months != 3 && months != 4) {
      throw ArgumentError('Il periodo selezionato deve essere di 2, 3 o 4 mesi.');
    }

    final response = await ApiService.get(
      '$_endpoint/summary-pdf?months=$months',
      timeout: const Duration(seconds: 40),
    );

    if (response.bodyBytes.isEmpty) {
      throw const AppFailure(
        'Il report PDF generato è vuoto. Riprova tra poco.',
        cause: 'bodyBytes vuoto da /reports/summary-pdf',
      );
    }

    return response.bodyBytes;
  }

  static http.MediaType _detectMediaType(String filename, List<int> bytes) {
    // Priorità assoluta ai magic bytes reali per evitare mismatch MIME/firma (HTTP 400).
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D) {
      return http.MediaType('application', 'pdf');
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
      return http.MediaType('image', 'png');
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return http.MediaType('image', 'jpeg');
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
      return http.MediaType('image', 'webp');
    }

    // Fallback sull'estensione solo se la firma binaria non è riconosciuta
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return http.MediaType('application', 'pdf');
    }
    if (lower.endsWith('.png')) {
      return http.MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return http.MediaType('image', 'webp');
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return http.MediaType('image', 'jpeg');
    }
    return http.MediaType('application', 'octet-stream');
  }

  static Future<ReportUploadResult> upload({
    required List<int> bytes,
    required String filename,
    required String title,
    DateTime? reportDate,
  }) async {
    final date = reportDate ?? DateTime.now();

    final response = await ApiService.postMultipart(
      _endpoint,
      fields: {
        'title': title,
        'report_date': _isoDay(date),
      },
      files: [
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: _detectMediaType(filename, bytes),
        ),
      ],
      timeout: const Duration(seconds: 45),
    );

    return _parse(response.body);
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Errore atteso (resta in UI come messaggio): il corpo non è il JSON
  /// previsto, quindi non è un problema dell'utente ma del backend.
  static ReportUploadResult _parse(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw _badResponse(body);
    }
    if (decoded is! Map) throw _badResponse(body);

    final id = decoded['id']?.toString();
    if (id == null || id.isEmpty) throw _badResponse(body);

    final extracted = <ExtractedValue>[];
    final raw = decoded['extracted'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final type = ClinicalParameterType.fromDb(item['type']?.toString());
        final value = double.tryParse(item['value']?.toString() ?? '');
        if (type == null || value == null || !type.isInRange(value)) continue;
        extracted.add(ExtractedValue(type: type, value: type.round(value)));
      }
    }

    final rawDate = decoded['report_date'] ?? decoded['report_at'];
    DateTime? parsedDate;
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString());
    }

    return ReportUploadResult(
      id: id,
      filePath: decoded['file_path']?.toString(),
      extracted: extracted,
      cleanSummary: decoded['clean_summary']?.toString(),
      reportType: decoded['report_type']?.toString(),
      reportDate: parsedDate,
      extractionMethod: decoded['extraction_method']?.toString(),
    );
  }

  static AppFailure _badResponse(String body) => AppFailure(
        'Il server ha risposto in un modo inatteso. Riprova più tardi.',
        cause: 'corpo non valido: $body',
      );
}
