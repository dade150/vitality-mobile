import 'dart:async';

import '../models/profile.dart';
import '../services/error_handler.dart';
import '../services/profile_service.dart';
import 'auth_scoped_provider.dart';

/// Stato del profilo utente (anagrafica + dati fisici), collegato a Supabase.
///
/// Stesso schema di [HealthProvider] e [ClinicalProvider]: carica all'accesso,
/// si svuota al logout, le scritture restituiscono `bool` e gli errori passano
/// da [ErrorHandler] (atteso -> [errorMessage]; imprevisto -> schermata /error).
class ProfileProvider extends AuthScopedProvider {
  ProfileProvider({ProfileService? service}) : _service = service ?? ProfileService();

  final ProfileService _service;

  Profile? _profile;

  // ---------------------------------------------------------------- Getter

  Profile? get profile => _profile;
  bool get isLoggedIn => _profile != null;
  bool get aiHealthConsent => _profile?.aiHealthConsent ?? false;

  // --------------------------------------------------------------- Caricamento

  @override
  void onClearState() {
    _profile = null;
  }

  @override
  Future<void> refresh() async {
    final uid = userId;
    if (uid == null) return;

    isLoading = true;
    loadFailed = false;
    errorMessage = null;
    notifyListeners();

    try {
      final p = await _service.fetch(uid);
      if (uid != userId) return; // utente cambiato durante il caricamento
      _profile = p;
      hasLoaded = true;
    } catch (e, st) {
      // Nessuna schermata: la UI mostra già il tasto "Riprova".
      ErrorHandler.handle(e, st, 'ProfileProvider.refresh');
      if (uid == userId) loadFailed = true;
    } finally {
      if (uid == userId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------- Scrittura

  /// Salva i campi non null e ricarica il profilo dal database.
  ///
  /// Restituisce `true` anche se la ricarica fallisce (i dati sono salvati):
  /// in quel caso si alza [loadFailed] e la UI mostra "Riprova" invece di un
  /// falso errore. In caso di errore atteso [errorMessage] contiene il motivo.
  Future<bool> updateProfile({
    String? name,
    String? surname,
    DateTime? birth,
    String? phone,
    double? peso,
    int? altezza,
    String? sesso,
    String? noteAnamnestiche,
  }) async {
    final uid = userId;
    if (uid == null) return false;

    final ok = await guard(
      () async {
        await _service.updateAnagrafica(uid,
            name: name, surname: surname, birth: birth, phone: phone);
        await _service.updateDatiFisici(uid,
            peso: peso,
            altezza: altezza,
            sesso: sesso,
            noteAnamnestiche: noteAnamnestiche);
      },
      where: 'ProfileProvider.updateProfile',
    );
    if (!ok) return false;

    try {
      await refresh();
    } catch (e, st) {
      ErrorHandler.handle(e, st, 'ProfileProvider.updateProfile.reload');
      loadFailed = true;
      notifyListeners();
    }
    return true;
  }

  /// Aggiorna o revoca il consenso esplicito al trattamento dati sanitari con IA (GDPR Art. 7.3 e Art. 9).
  Future<bool> setAiHealthConsent(bool consent) async {
    final uid = userId;
    final p = _profile;
    if (uid == null || p == null) return false;

    final ok = await guard(
      () => _service.updateAiHealthConsent(uid, consent),
      where: 'ProfileProvider.setAiHealthConsent',
    );
    if (!ok) return false;

    _profile = p.copyWith(aiHealthConsent: consent);
    notifyListeners();
    return true;
  }
}
