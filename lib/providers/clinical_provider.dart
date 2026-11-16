import 'dart:async';

import '../models/clinical_parameter.dart';
import '../services/clinical_service.dart';
import '../services/error_handler.dart';
import 'auth_scoped_provider.dart';

/// Stato dei parametri clinici (HbA1c, eGFR, UACR, profilo lipidico).
///
/// Stesso schema di [HealthProvider]: carica all'accesso, si svuota al
/// logout, le scritture restituiscono `bool` e gli errori passano da
/// [ErrorHandler] (atteso -> [errorMessage]; imprevisto -> schermata /error).
class ClinicalProvider extends AuthScopedProvider {
  ClinicalProvider({ClinicalService? service}) : _service = service ?? ClinicalService();

  final ClinicalService _service;

  /// Per ogni parametro, i valori dal più recente al più vecchio.
  Map<ClinicalParameterType, List<ClinicalReading>> _byType = _empty();

  static Map<ClinicalParameterType, List<ClinicalReading>> _empty() =>
      {for (final t in ClinicalParameterType.values) t: <ClinicalReading>[]};

  // ----------------------------------------------------------------- Getter

  /// Ultimo valore registrato per [type] (per data d'esame), se esiste.
  ClinicalReading? latest(ClinicalParameterType type) => _byType[type]?.firstOrNull;

  /// Storico di [type], dal più recente (usato dalla futura schermata Storico).
  List<ClinicalReading> history(ClinicalParameterType type) =>
      List.unmodifiable(_byType[type] ?? const <ClinicalReading>[]);

  // --------------------------------------------------------------- Caricamento

  @override
  void onClearState() {
    _byType = _empty();
  }

  void _setReadings(List<ClinicalReading> rows) {
    final next = _empty();
    for (final r in rows) {
      next[r.type]!.add(r);
    }
    _byType = next;
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
      final rows = await _service.fetchAll();
      if (uid != userId) return; // utente cambiato durante il caricamento
      _setReadings(rows);
      hasLoaded = true;
    } catch (e, st) {
      // Nessuna schermata: la UI mostra già il banner "Riprova".
      ErrorHandler.handle(e, st, 'ClinicalProvider.refresh');
      if (uid == userId) loadFailed = true;
    } finally {
      if (uid == userId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reload() async {
    final uid = userId;
    final rows = await _service.fetchAll();
    if (uid != userId) return;
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
      loadFailed = true;
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
}