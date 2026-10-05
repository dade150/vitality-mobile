import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/error_handler.dart';

/// Stato di autenticazione esposto alla UI tramite `provider`.
///
/// Non tiene mai in mano il token esplicitamente: si limita ad ascoltare
/// `onAuthStateChange` di Supabase (che gestisce persistenza e refresh da
/// solo) e a notificare i listener quando la sessione cambia.
///
/// Gestione errori: gli errori propri di Supabase Auth vengono mappati da
/// [_mapAuthError] (messaggi utente già pronti); tutto il resto (rete,
/// timeout, bug) passa da `ErrorHandler`, che classifica l'errore e, se è
/// imprevisto, apre la schermata di errore.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  Session? _session;
  bool _isLoading = false;
  String? _errorMessage;
  bool _pendingEmailConfirmation = false;
  Stream<AuthState> get authStateChanges => _authService.onAuthStateChange;

  AuthProvider() {
    _session = _authService.currentSession;
    // onError è obbligatorio secondo la documentazione ufficiale: senza,
    // un errore di rete durante il refresh (es. app offline) diventerebbe
    // un'eccezione non gestita e farebbe crashare l'app.
    _authService.onAuthStateChange.listen(
      (data) {
        _session = data.session;
        if (data.event == AuthChangeEvent.signedIn) {
          _pendingEmailConfirmation = false;
        }
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Auth stream error: $error');
        // Non propaghiamo: l'utente resta con la sessione locale già
        // caricata finché la connessione non torna disponibile.
      },
    );
  }

  Session? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get pendingEmailConfirmation => _pendingEmailConfirmation;

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.signIn(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e, st) {
      _errorMessage = ErrorHandler.handle(e, st, 'AuthProvider.signIn').message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// [metadata] è il pacchetto completo prodotto da
  /// `RegistrationData.toMetadata()`: il trigger `handle_new_user` lo legge
  /// per popolare `user`, `profile` e `user_settings` in un colpo solo.
  Future<bool> signUp(
    Map<String, dynamic> metadata, {
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
        metadata: metadata,
      );
      final user = response.user;
      if (user != null && (user.identities?.isEmpty ?? false)) {
        _errorMessage = 'Esiste già un account con questa email.';
        return false;
      }

      _pendingEmailConfirmation = response.session == null;
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e, st) {
      _errorMessage = ErrorHandler.handle(e, st, 'AuthProvider.signUp').message;
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<bool> resendConfirmation(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.resendSignupConfirmation(email);
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e, st) {
      _errorMessage = ErrorHandler.handle(e, st, 'AuthProvider.resendConfirmation').message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e, st) {
      // Logout localmente riuscito: la revoca remota può fallire offline.
      // Solo log, mai la schermata di errore in fase di uscita.
      ErrorHandler.logOnly(e, st, 'AuthProvider.signOut');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapAuthError(AuthException e) {
    final msg = e.message;
    if (msg.contains('Invalid login credentials')) {
      return 'Email o password non corretti.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Devi prima confermare l\'indirizzo email. Controlla la tua posta.';
    }
    if (msg.contains('User already registered') || msg.contains('already been registered')) {
      return 'Esiste già un account con questa email.';
    }
    if (msg.contains('For security purposes') || msg.contains('rate limit')) {
      return 'Troppi tentativi. Riprova tra qualche minuto.';
    }
    if (msg.contains('Password should be')) {
      return 'Password non accettata: prova una combinazione più forte.';
    }
    return msg;
  }
}
