import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/error_handler.dart';
import '../services/profile_service.dart';
import 'error_provider.dart';

/// Stato del profilo utente (anagrafica + dati fisici), collegato a Supabase.
///
/// Stesso schema di [HealthProvider] e [ClinicalProvider]: carica all'accesso,
/// si svuota al logout, le scritture restituiscono `bool` e gli errori passano
/// da [ErrorHandler] (atteso -> [errorMessage]; imprevisto -> schermata /error).
///
/// Il caricamento è agganciato allo stream di auth: prima non veniva mai
/// invocato e la schermata profilo restava in spinner perenne.
class ProfileProvider extends ChangeNotifier with ErrorReporting {
  ProfileProvider({ProfileService? service}) : _service = service ?? ProfileService() {
    final auth = Supabase.instance.client.auth;
    _authSub = auth.onAuthStateChange.listen(_onAuthChange);

    // Provider creato all'avvio: lo stato iniziale non arriva dallo stream.
    final user = auth.currentUser;
    if (user != null) {
      _userId = user.id;
      Future.microtask(refresh);
    }
  }

  final ProfileService _service;
  StreamSubscription<AuthState>? _authSub;

  String? _userId;
  Profile? _profile;
  bool _loading = false;
  bool _loadFailed = false;
  bool _hasLoaded = false;

  // ---------------------------------------------------------------- Getter

  Profile? get profile => _profile;
  bool get isLoading => _loading;
  bool get loadFailed => _loadFailed;
  bool get hasLoaded => _hasLoaded;
  bool get isLoggedIn => _profile != null;

  // --------------------------------------------------------------- Caricamento

  void _onAuthChange(AuthState data) {
    final uid = data.session?.user.id;
    if (data.event == AuthChangeEvent.signedOut || uid == null) {
      _clear();
      return;
    }
    if (uid != _userId) {
      _clear(notify: false);
      _userId = uid;
      unawaited(refresh());
    }
  }

  void _clear({bool notify = true}) {
    _userId = null;
    _profile = null;
    _loading = false;
    _loadFailed = false;
    _hasLoaded = false;
    errorMessage = null;
    if (notify) notifyListeners();
  }

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null) return;

    _loading = true;
    _loadFailed = false;
    errorMessage = null;
    notifyListeners();

    try {
      final p = await _service.fetch(uid);
      if (uid != _userId) return; // utente cambiato durante il caricamento
      _profile = p;
      _hasLoaded = true;
    } catch (e, st) {
      // Nessuna schermata: la UI mostra già il tasto "Riprova".
      ErrorHandler.handle(e, st, 'ProfileProvider.refresh');
      if (uid == _userId) _loadFailed = true;
    } finally {
      if (uid == _userId) {
        _loading = false;
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
    final uid = _userId;
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
      _loadFailed = true;
      notifyListeners();
    }
    return true;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
