import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/clinical_parameter.dart';
import '../models/medical_report.dart';
import 'api_services.dart';
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

  /// Apre il referto tramite l'applicazione predefinita del telefono (PDF viewer / Galleria).
  static Future<void> openReportWithExternalApp(BuildContext context, MedicalReport report) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = Supabase.instance.client;

    // 1. Se il referto ha già un file_path su Supabase Storage, genera il Signed URL e aprilo
    if (report.filePath != null && report.filePath!.trim().isNotEmpty) {
      try {
        final signedUrl = await db.storage
            .from('patient-reports')
            .createSignedUrl(report.filePath!.trim(), 300);
        final uri = Uri.parse(signedUrl);
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Fallback al download dal backend se il bucket o il file non sono raggiungibili
      }
    }

    // 2. Scarica il documento PDF dal backend (/api/reports/{id}/document)
    final numId = int.tryParse(report.id);
    if (numId == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Documento ancora in fase di sincronizzazione. Riprova tra poco.')),
      );
      return;
    }

    try {
      final response = await ApiService.get(
        '$_endpoint/$numId/document',
        timeout: const Duration(seconds: 30),
      );
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw const AppFailure('Il documento del referto è vuoto.');
      }

      // Prova a caricarlo nel bucket privato patient-reports per aprirlo direttamente con app esterna
      final uid = db.auth.currentUser?.id;
      if (uid != null) {
        final storagePath = '$uid/referto_$numId.pdf';
        try {
          await db.storage.from('patient-reports').uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
              );
          await db.from('patient_reports').update({'file_path': storagePath}).eq('id', numId);
          final signedUrl = await db.storage.from('patient-reports').createSignedUrl(storagePath, 300);
          if (await launchUrl(Uri.parse(signedUrl), mode: LaunchMode.externalApplication)) {
            return;
          }
        } catch (_) {
          // Se il bucket Storage non è attivo, procediamo col salvataggio/apertura locale
        }
      }

      // 3. Fallback universale: salva e apri il file PDF sul dispositivo
      final safeName = report.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = '${safeName.isEmpty ? "Referto_$numId" : safeName}.pdf';
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Apri o Salva Referto PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (outputPath != null && outputPath.isNotEmpty) {
        try {
          await File(outputPath).writeAsBytes(bytes);
        } catch (_) {}
      }
    } catch (e) {
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
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf') || (bytes.length >= 5 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46)) {
      return http.MediaType('application', 'pdf');
    }
    if (lower.endsWith('.png') || (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47)) {
      return http.MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return http.MediaType('image', 'webp');
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF)) {
      return http.MediaType('image', 'jpeg');
    }
    return http.MediaType('application', 'pdf');
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
