import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/navigation.dart';

/// Esito classificato di un errore.
/// - [unexpected] == false: errore "atteso" (validazione, rete, credenziali…).
///   Resta in UI come snackbar/messaggio inline, la schermata NON compare.
/// - [unexpected] == true: bug, 5xx, RLS/JWT, TypeError… -> schermata errore.
class AppFailure implements Exception {
  final String message;
  final bool unexpected;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppFailure(
    this.message, {
    this.unexpected = false,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() => 'AppFailure($message, unexpected: $unexpected, cause: $cause)';
}

class ErrorHandler {
  ErrorHandler._();

  static const genericMessage =
      'Si è verificato un errore imprevisto. Riprova tra qualche istante.';

  static bool _screenVisible = false;
  static bool _remoteLogging = false;

  // ---------------------------------------------------------------------
  // Classificazione
  // ---------------------------------------------------------------------
  static AppFailure classify(Object error, [StackTrace? st]) {
    if (error is AppFailure) return error;

    // Rete assente / timeout: atteso.
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException ||
        error is AuthRetryableFetchException) {
      return AppFailure('Connessione assente o instabile. Riprova.',
          cause: error, stackTrace: st);
    }

    // Auth: i messaggi utente li mappa già AuthProvider; qui distinguiamo
    // solo i 5xx (server Supabase giù) dagli errori "normali".
    if (error is AuthException) {
      final code = int.tryParse(error.statusCode ?? '');
      final serverSide = code != null && code >= 500;
      return AppFailure(serverSide ? genericMessage : error.message,
          unexpected: serverSide, cause: error, stackTrace: st);
    }

    // Postgres / PostgREST: i codici SQLSTATE di validazione sono attesi
    // (CHECK su glicemia/pressione/pasti/attività, ecc.).
    if (error is PostgrestException) {
      switch (error.code) {
        case '23514': // check_violation
        case '22003': // numeric_value_out_of_range
        case '22P02': // invalid_text_representation
          return AppFailure('Uno dei valori inseriti non è valido o è fuori dai limiti consentiti.',
              cause: error, stackTrace: st);
        case '23505': // unique_violation
          return AppFailure('Questo elemento esiste già.', cause: error, stackTrace: st);
        case '23502': // not_null_violation
          return AppFailure('Mancano alcuni dati obbligatori.', cause: error, stackTrace: st);
      }
      // 42501 (RLS), PGRST301 (JWT), 5xx, ecc. -> imprevisto
      return AppFailure(genericMessage, unexpected: true, cause: error, stackTrace: st);
    }

    // Validazione lato client (HealthService._check*, parsing dei campi):
    // è l'utente a dover correggere, non un bug -> resta in UI.
    if (error is ArgumentError || error is FormatException) {
      return AppFailure('Uno dei valori inseriti non è valido o è fuori dai limiti consentiti.',
          cause: error, stackTrace: st);
    }

    // Tutto il resto (StateError, TypeError, errori Dart generici…) è un
    // bug o un problema di configurazione/permessi -> schermata errore.
    return AppFailure(genericMessage, unexpected: true, cause: error, stackTrace: st);
  }

  // ---------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------

  /// Classifica, logga e, se imprevisto, mostra la schermata errore.
  /// Ritorna sempre il [AppFailure] così il chiamante può mostrare
  /// il messaggio inline per gli errori attesi.
  static AppFailure handle(Object error, [StackTrace? st, String? where]) {
    final failure = classify(error, st ?? (error is Error ? error.stackTrace : null));
    _log(failure, where);
    if (failure.unexpected) _showErrorScreen(failure);
    return failure;
  }

  /// Solo log, senza schermata (es. errori di rendering/layout in
  /// FlutterError.onError: navigare da lì può innescare loop di rebuild).
  static void logOnly(Object error, [StackTrace? st, String? where]) {
    _log(classify(error, st), where, forceRemote: true);
  }

  /// Chiamato da ErrorScreen.dispose().
  static void onScreenClosed() => _screenVisible = false;

  // ---------------------------------------------------------------------
  // Interni
  // ---------------------------------------------------------------------
  static void _log(AppFailure f, String? where, {bool forceRemote = false}) {
    debugPrint('[ErrorHandler]${where != null ? ' ($where)' : ''} $f\n${f.stackTrace ?? ''}');
    if (f.unexpected || forceRemote) {
      unawaited(_remoteLog(f, where));
    }
  }

  /// IMPORTANTE: l'insert è `await`-ato dentro try/catch. Un insert senza
  /// await genererebbe un'eccezione async non gestita ->
  /// PlatformDispatcher.onError -> di nuovo log -> loop infinito finché la
  /// tabella `app_logs` non esiste. Il flag _remoteLogging taglia comunque
  /// la ricorsione.
  static Future<void> _remoteLog(AppFailure f, String? where) async {
    if (_remoteLogging) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return; // RLS: serve auth.uid()
    _remoteLogging = true;
    try {
      final stack = (f.stackTrace ?? StackTrace.current).toString();
      var message = '${f.cause ?? f.message}';
      if (message.length > 2000) message = message.substring(0, 2000);
      await client.from('app_logs').insert({
        'message': message,
        'context': where,
        'stacktrace': stack.length > 4000 ? stack.substring(0, 4000) : stack,
      });
    } catch (e) {
      debugPrint('[ErrorHandler] log remoto fallito: $e');
    } finally {
      _remoteLogging = false;
    }
  }

  static void _showErrorScreen(AppFailure f) {
    if (_screenVisible) return; // niente schermate impilate
    _screenVisible = true;

    // Mai navigare durante build/layout: aspettiamo la fine del frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        _screenVisible = false;
        return;
      }
      try {
        nav.pushNamed('/error', arguments: f);
      } catch (e) {
        // Route non disponibile (non dovrebbe capitare: /error è registrata
        // in main.dart): non bloccare la coda delle schermate di errore.
        _screenVisible = false;
        debugPrint('[ErrorHandler] impossibile aprire la schermata di errore: $e');
      }
    });
    // Se l'app è "ferma" il callback non scatterebbe: forziamo un frame.
    SchedulerBinding.instance.scheduleFrame();
  }
}