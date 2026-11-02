import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/clinical_parameter.dart';
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
  static const _endpoint = '/reports';

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
      files: [http.MultipartFile.fromBytes('file', bytes, filename: filename)],
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
