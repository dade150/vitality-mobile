// lib/services/api_services.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_handler.dart';

/// Accesso al backend Python.
///
/// Le risposte non-2xx non vengono restituite così come sono: vengono
/// convertite in [AppFailure] già classificato, così il chiamante può
/// buttarle in `ErrorHandler.handle` (o nel mixin `ErrorReporting.guard`)
/// come qualsiasi altro errore:
/// - 4xx      -> errore atteso: messaggio utente, nessuna schermata
/// - 5xx/403  -> imprevisto: schermata di errore
class ApiService {
  // Cambia con l'URL di produzione quando sarà il momento; probabilmente lo passiamo da .env
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  /// Senza timeout un BE appeso bloccherebbe la UI in stato "loading" per
  /// sempre. TimeoutException è classificata da ErrorHandler come errore
  /// atteso ("Connessione assente o instabile. Riprova.").
  static const Duration timeout = Duration(seconds: 15);

  static Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final r = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers).timeout(timeout);
    return _ensure(r);
  }

  static Future<http.Response> post(String endpoint, String body) async {
    final headers = await _getHeaders();
    final r =
        await http.post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: body)
            .timeout(timeout);
    return _ensure(r);
  }

  /// POST multipart (upload di un file + campi testo).
  ///
  /// Usato per caricare un referto al backend, che lo salva su Storage ed
  /// estrae i valori. Il Content-Type va rimosso: lo imposterebbe a
  /// `application/json` e romperebbe il boundary del multipart.
  static Future<http.Response> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
  }) async {
    final headers = await _getHeaders()..remove('Content-Type');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'))
      ..headers.addAll(headers)
      ..fields.addAll(fields)
      ..files.addAll(files);
    final r = await http.Response.fromStream(await request.send().timeout(timeout));
    return _ensure(r);
  }

  // ------------------------------------------------------------------ Errori

  /// Lancia [AppFailure] se la risposta non è 2xx, altrimenti la restituisce.
  static http.Response _ensure(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return r;
    throw _failureFrom(r);
  }

  static AppFailure _failureFrom(http.Response r) {
    final detail = _detailFrom(r);
    // 403 = permessi: non è un errore di validazione ma un problema di
    // configurazione -> schermata di errore, come RLS/JWT su Supabase.
    if (r.statusCode >= 500 || r.statusCode == 403) {
      return AppFailure(
        ErrorHandler.genericMessage,
        unexpected: true,
        cause: 'HTTP ${r.statusCode}: $detail',
      );
    }
    return AppFailure(_messageFor(r.statusCode, detail), cause: 'HTTP ${r.statusCode}: $detail');
  }

  /// Preferisce il corpo d'errore prodotto dal BE (`message`/`detail`/`error`);
  /// se non leggibile restituisce la stringa vuota e si usa il messaggio
  /// generico associato allo status.
  static String _detailFrom(http.Response r) {
    if (r.body.isEmpty) return '';
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is Map) {
        for (final key in ['message', 'detail', 'error']) {
          final v = decoded[key];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    } catch (_) {
      // corpo non JSON: si ricade sul messaggio di default per lo status
    }
    return '';
  }

  static String _messageFor(int status, String detail) {
    if (detail.isNotEmpty) return detail;
    if (status == 401) return 'Sessione scaduta. Accedi di nuovo.';
    if (status == 404) return 'Risorsa non trovata.';
    if (status == 409) return 'Questo elemento esiste già.';
    if (status == 429) return 'Troppi tentativi. Riprova tra qualche minuto.';
    if (status == 400 || status == 422) {
      return 'Uno dei valori inseriti non è valido o è fuori dai limiti consentiti.';
    }
    return 'Richiesta non riuscita. Riprova tra qualche istante.';
  }
}
