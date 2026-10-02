import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Wrapper sottile sopra `supabase.auth`. Non contiene logica di stato
/// (quella vive in [AuthProvider]): si limita a tradurre le chiamate Supabase
/// nei metodi usati dall'app, con i redirect deep-link centralizzati qui.
class AuthService {
  static const _registerRedirect = 'io.supabase.vitalityassist://register-callback/';
  static const _resetRedirect = 'io.supabase.vitalityassist://reset-callback/';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) {
    return supabase.auth.signUp(
      email: email,
      password: password,
      data: metadata,
      emailRedirectTo: _registerRedirect,
    );
  }

  Future<AuthResponse> signIn({required String email, required String password}) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => supabase.auth.signOut();

  Future<void> resetPassword(String email) {
    return supabase.auth.resetPasswordForEmail(email, redirectTo: _resetRedirect);
  }

  /// Rimanda l'email di conferma registrazione, per la schermata
  /// "controlla la tua email" quando l'utente non l'ha ricevuta.
  Future<ResendResponse> resendSignupConfirmation(String email) {
    return supabase.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: _registerRedirect,);
  }

  Session? get currentSession => supabase.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => supabase.auth.onAuthStateChange;
}