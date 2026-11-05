import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
  static bool _remoteLogDisabled = false;

  // ---------------------------------------------------------------------
  // Mappatura errori Auth noti all'utente
  // ---------------------------------------------------------------------
  static String? mapKnownAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Email o password non corretti.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Devi prima confermare l\'indirizzo email. Controlla la tua posta.';
    }
    if (msg.contains('user already registered') || msg.contains('already been registered')) {
      return 'Esiste già un account con questa email.';
    }
    if (msg.contains('for security purposes') || msg.contains('rate limit')) {
      return 'Troppi tentativi ravvicinati. Riprova tra qualche minuto.';
    }
    if (msg.contains('password should be') || msg.contains('weak password')) {
      return 'Password non accettata: prova una combinazione più forte.';
    }
    return null;
  }

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

    // Eccezioni di piattaforma (plugin nativi, permessi negati, ecc.)
    if (error is PlatformException) {
      final msg = (error.message ?? '').toLowerCase();
      if (msg.contains('permission') || msg.contains('permessi') || msg.contains('denied')) {
        return AppFailure('Permesso negato. Puoi abilitarlo dalle impostazioni del dispositivo.',
            cause: error, stackTrace: st);
      }
      return AppFailure(genericMessage, unexpected: true, cause: error, stackTrace: st);
    }

    // Auth: verifichiamo se è un errore utente atteso (credenziali errate, email duplicata...).
    // Se è un errore del database, 5xx o non mappato, è classificato come imprevisto.
    if (error is AuthException) {
      final code = int.tryParse(error.statusCode ?? '');
      final msg = error.message.toLowerCase();
      final isServerOrDbError = (code != null && code >= 500) ||
          msg.contains('database error') ||
          msg.contains('unexpected_failure') ||
          msg.contains('saving new user') ||
          msg.contains('internal server error') ||
          error.message.trim().startsWith('{');

      if (isServerOrDbError) {
        return AppFailure(genericMessage, unexpected: true, cause: error, stackTrace: st);
      }

      final known = mapKnownAuthError(error);
      if (known != null) {
        return AppFailure(known, unexpected: false, cause: error, stackTrace: st);
      }

      return AppFailure(genericMessage, unexpected: true, cause: error, stackTrace: st);
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

    // Validazione lato client (HealthService._check*, parsing dei campi)
    if (error is ArgumentError) {
      final msg = error.message?.toString();
      final isFriendly = msg != null &&
          msg.isNotEmpty &&
          !msg.startsWith('{') &&
          !msg.contains('Exception:');
      return AppFailure(
        isFriendly ? msg : 'Uno dei valori inseriti non è valido o è fuori dai limiti consentiti.',
        cause: error,
        stackTrace: st,
      );
    }
    if (error is FormatException) {
      return AppFailure('Uno dei valori inseriti non è valido o è fuori dai limiti consentiti.',
          cause: error, stackTrace: st);
    }

    // Rileva stringhe di errore JSON grezze (es. {"code": "...", "message": "..."}) o dump DB
    final errStr = error.toString().trim();
    if (errStr.startsWith('{') && (errStr.contains('"code"') || errStr.contains('"message"'))) {
      return AppFailure(genericMessage, unexpected: true, cause: error, stackTrace: st);
    }
    if (errStr.contains('duplicate key value') ||
        errStr.contains('violates foreign key') ||
        errStr.contains('relation "') ||
        errStr.contains('column "') ||
        errStr.contains('syntax error at or near') ||
        errStr.contains('Database error')) {
      return AppFailure(genericMessage, unexpected: true, cause: error, stackTrace: st);
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
    // D3: Invia i log remoti su app_logs solo per errori imprevisti in modalità release (o se forzato)
    if ((f.unexpected || forceRemote) && (kReleaseMode || forceRemote)) {
      unawaited(_remoteLog(f, where));
    }
  }

  static String _scrubLogText(String input) {
    return input
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          '[REDACTED_JWT]',
        )
        .replaceAll(
          RegExp(r'\bBearer\s+[A-Za-z0-9._-]+', caseSensitive: false),
          'Bearer [REDACTED_TOKEN]',
        )
        .replaceAll(
          RegExp(r'\b[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]\b', caseSensitive: false),
          '[REDACTED_CF]',
        )
        .replaceAll(
          RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
          '[REDACTED_EMAIL]',
        )
        .replaceAll(
          RegExp(r'(?:\+39\s?)?3\d{2}[\s.-]?\d{3}[\s.-]?\d{3,4}\b'),
          '[REDACTED_PHONE]',
        )
        .replaceAll(
          RegExp(r'Failing row contains \([^)]+\)', caseSensitive: false),
          'Failing row contains ([REDACTED_DB_ROW])',
        );
  }

  /// IMPORTANTE: l'insert è `await`-ato dentro try/catch. Un insert senza
  /// await genererebbe un'eccezione async non gestita ->
  /// PlatformDispatcher.onError -> di nuovo log -> loop infinito finché la
  /// tabella `app_logs` non esiste. Il flag _remoteLogging taglia comunque
  /// la ricorsione.
  static Future<void> _remoteLog(AppFailure f, String? where) async {
    if (_remoteLogging || _remoteLogDisabled) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return; // RLS: serve auth.uid()
    _remoteLogging = true;
    try {
      final stack = _scrubLogText((f.stackTrace ?? StackTrace.current).toString());
      var message = _scrubLogText('${f.cause ?? f.message}');
      if (message.length > 2000) message = message.substring(0, 2000);
      await client.from('app_logs').insert({
        'message': message,
        'context': where,
        'stacktrace': stack.length > 4000 ? stack.substring(0, 4000) : stack,
      });
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        _remoteLogDisabled = true;
      }
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