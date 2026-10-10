import 'dart:convert';

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

  const ReportUploadResult({
    required this.id,
    required this.filePath,
    required this.extracted,
  });
}

/// Caricamento di un referto al backend Python (`/api/reports`).
///
/// Il backend riceve il file, lo salva su Supabase Storage (bucket privato,
/// cartella dell'utente), crea la riga in `reports` ed estrae i valori con
/// l'LLM; questa classe si limita a inviare la richiesta e a tradurre la
/// risposta, così l'app è già pronta appena l'endpoint esiste.
///
/// Contratto atteso (multipart, `Authorization: Bearer <token Supabase>`):
///
///   POST /api/reports
///   campi:  title (testo), report_date (YYYY-MM-DD)
///   file:   file (bytes del PDF)
///   risposta 2xx:
///   {
///     "id": "uuid",
///     "file_path": "<user_id>/<uuid>.pdf",
///     "extracted": [ {"type": "HBA1C", "value": 6.8}, ... ]
///   }
///
/// `type` usa lo stesso codice di `ClinicalParameterType.dbCode`: un codice
/// sconosciuto o un valore non numerico viene scartato invece di far
/// fallire l'intero caricamento (potrebbe arrivare un parametro che
/// l'applicazione ancora non gestisce).
class ReportService {
  static const _endpoint = '/reports';

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

    return ReportUploadResult(
      id: id,
      filePath: decoded['file_path']?.toString(),
      extracted: extracted,
    );
  }

  static AppFailure _badResponse(String body) => AppFailure(
        'Il server ha risposto in un modo inatteso. Riprova più tardi.',
        cause: 'corpo non valido: $body',
      );
}
