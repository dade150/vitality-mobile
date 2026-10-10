import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clinical_parameter.dart';
import '../services/clinical_service.dart';
import '../services/error_handler.dart';
import 'error_provider.dart';

/// Stato dei parametri clinici (HbA1c, eGFR, UACR, profilo lipidico).
///
/// Stesso schema di [HealthProvider]: carica all'accesso, si svuota al
/// logout, le scritture restituiscono `bool` e gli errori passano da
/// [ErrorHandler] (atteso -> [errorMessage]; imprevisto -> schermata /error).
class ClinicalProvider extends ChangeNotifier with ErrorReporting {
  ClinicalProvider({ClinicalService? service}) : _service = service ?? ClinicalService() {
    final auth = Supabase.instance.client.auth;
    _authSub = auth.onAuthStateChange.listen(_onAuthChange);

    // Provider creato (lazy) dopo il login: lo stato iniziale non arriva dallo stream.
    final user = auth.currentUser;
    if (user != null) {
      _userId = user.id;
      Future.microtask(refresh);
    }
  }

  final ClinicalService _service;
  StreamSubscription<AuthState>? _authSub;

  String? _userId;
  bool _loading = false;
  bool _loadFailed = false;
  bool _hasLoaded = false;

  /// Per ogni parametro, i valori dal più recente al più vecchio.
  Map<ClinicalParameterType, List<ClinicalReading>> _byType = _empty();

  static Map<ClinicalParameterType, List<ClinicalReading>> _empty() =>
      {for (final t in ClinicalParameterType.values) t: <ClinicalReading>[]};

  // ----------------------------------------------------------------- Getter

  bool get isLoading => _loading;
  bool get loadFailed => _loadFailed;
  bool get hasLoaded => _hasLoaded;

  /// Ultimo valore registrato per [type] (per data d'esame), se esiste.
  ClinicalReading? latest(ClinicalParameterType type) => _byType[type]?.firstOrNull;

  /// Storico di [type], dal più recente (usato dalla futura schermata Storico).
  List<ClinicalReading> history(ClinicalParameterType type) =>
      List.unmodifiable(_byType[type] ?? const <ClinicalReading>[]);

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
    _loading = false;
    _loadFailed = false;
    _hasLoaded = false;
    errorMessage = null;
    _byType = _empty();
    if (notify) notifyListeners();
  }

  void _setReadings(List<ClinicalReading> rows) {
    final next = _empty();
    for (final r in rows) {
      next[r.type]!.add(r);
    }
    _byType = next;
  }

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null) return;

    _loading = true;
    _loadFailed = false;
    errorMessage = null;
    notifyListeners();

    try {
      final rows = await _service.fetchAll();
      if (uid != _userId) return; // utente cambiato durante il caricamento
      _setReadings(rows);
      _hasLoaded = true;
    } catch (e, st) {
      // Nessuna schermata: la UI mostra già il banner "Riprova".
      ErrorHandler.handle(e, st, 'ClinicalProvider.refresh');
      if (uid == _userId) _loadFailed = true;
    } finally {
      if (uid == _userId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reload() async {
    final uid = _userId;
    final rows = await _service.fetchAll();
    if (uid != _userId) return;
    _setReadings(rows);
    notifyListeners();
  }

  /// Scrittura + ricarica. Restituisce `true` anche se la ricarica fallisce
  /// (la riga è salvata): in quel caso si alza [loadFailed] e la UI mostra
  /// il banner "Riprova" invece di un falso errore (stessa logica di HealthProvider).
  Future<bool> _write(Future<void> Function() op, {required String where}) async {
    final ok = await guard(op, where: 'ClinicalProvider.$where');
    if (!ok) return false;
    try {
      await _reload();
    } catch (e, st) {
      ErrorHandler.handle(e, st, 'ClinicalProvider.$where.reload');
      _loadFailed = true;
      notifyListeners();
    }
    return true;
  }

  // ---------------------------------------------------------------- Scrittura

  /// [date] è la data dell'esame scelta dall'utente.
  Future<bool> addReading(ClinicalParameterType type, double value, DateTime date) =>
      _write(() => _service.insert(type, value, date), where: 'addReading');

  Future<bool> updateReading(String id, ClinicalParameterType type, double value, DateTime date) =>
      _write(() => _service.update(id, type, value, date), where: 'updateReading');

  Future<bool> deleteReading(String id) =>
      _write(() => _service.delete(id), where: 'deleteReading');

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}