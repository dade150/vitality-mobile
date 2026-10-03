import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_entry.dart';
import '../models/meal_entry.dart';
import '../models/therapy_item.dart';
import '../models/vital_readings.dart';
import '../services/health_service.dart';

/// Stato "salute" dell'app, collegato a Supabase.
///
/// Carica gli ultimi [_windowDays] giorni all'accesso (e quando si naviga
/// più indietro nel Diario), e si svuota al logout. Tutte le operazioni di
/// scrittura restituiscono `true` se riuscite, `false` altrimenti (la UI
/// mostra un messaggio generico: i dettagli dell'errore non vengono esposti).
class HealthProvider extends ChangeNotifier {
  HealthProvider({HealthService? service}) : _service = service ?? HealthService() {
    final auth = Supabase.instance.client.auth;
    _authSub = auth.onAuthStateChange.listen(_onAuthChange);

    // Provider creato (lazy) dopo il login: lo stato iniziale non arriva dallo stream.
    final user = auth.currentUser;
    if (user != null) {
      _userId = user.id;
      Future.microtask(refresh);
    }
  }

  static const int _windowDays = 30;

  final HealthService _service;
  StreamSubscription<AuthState>? _authSub;

  String? _userId;
  DateTime? _loadedSince;
  bool _loading = false;
  bool _loadFailed = false;
  bool _hasLoaded = false;

  List<TherapyItem> _therapyItems = [];
  List<TherapyLog> _therapyLogs = [];
  List<GlucoseReading> _glucose = [];
  List<BloodPressureReading> _pressure = [];
  List<ActivityEntry> _activities = [];
  List<MealEntry> _meals = [];
  final Set<String> _togglingTherapy = {};

  // ---------------------------------------------------------------- Getter

  List<TherapyItem> get therapyItems => List.unmodifiable(_therapyItems);
  List<GlucoseReading> get glucoseReadings => List.unmodifiable(_glucose);
  List<BloodPressureReading> get pressureReadings => List.unmodifiable(_pressure);
  List<ActivityEntry> get activityEntries => List.unmodifiable(_activities);
  List<MealEntry> get mealEntries => List.unmodifiable(_meals);

  bool get isLoading => _loading;
  bool get loadFailed => _loadFailed;
  bool get hasLoaded => _hasLoaded;

  GlucoseReading? get lastGlucose => _glucose.isNotEmpty ? _glucose.last : null;
  BloodPressureReading? get lastPressure => _pressure.isNotEmpty ? _pressure.last : null;

  int get todaySteps {
    final now = DateTime.now();
    return _activities.where((a) => _sameDay(a.date, now)).fold<int>(0, (s, a) => s + a.steps);
  }

  int get todayCalories {
    final now = DateTime.now();
    return _meals.where((m) => _sameDay(m.date, now)).fold<int>(0, (s, m) => s + m.calories);
  }

  /// La terapia [therapyId] risulta presa nel giorno [day]?
  bool isTherapyTaken(String therapyId, DateTime day) =>
      _therapyLogs.any((l) => l.therapyId == therapyId && _sameDay(l.takenAt, day));

  /// True mentre è in corso il salvataggio dell'assunzione [therapyId]:
  /// la UI disabilita il pulsante e non segnala l'errore del doppio tap.
  bool isTherapyToggling(String therapyId) => _togglingTherapy.contains(therapyId);

  // --------------------------------------------------------------- Caricamento

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime get _since =>
      _loadedSince ??= DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
          .subtract(const Duration(days: _windowDays));

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
    _loadedSince = null;
    _loading = false;
    _loadFailed = false;
    _hasLoaded = false;
    _therapyItems = [];
    _therapyLogs = [];
    _glucose = [];
    _pressure = [];
    _activities = [];
    _meals = [];
    if (notify) notifyListeners();
  }

  /// Ricarica tutto dalla finestra corrente.
  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null) return;

    _loading = true;
    _loadFailed = false;
    notifyListeners();

    final since = _since;
    try {
      final (vitals, meals, activities, therapies, logs) = await (
        _service.fetchVitals(since),
        _service.fetchMeals(since),
        _service.fetchActivities(since),
        _service.fetchTherapies(),
        _service.fetchTherapyLogs(since),
      ).wait;

      if (uid != _userId) return; // utente cambiato durante il caricamento

      _glucose = vitals.glucose;
      _pressure = vitals.pressure;
      _meals = meals;
      _activities = activities;
      _therapyItems = therapies;
      _therapyLogs = logs;
      _applyTakenToday();
      _hasLoaded = true;
    } catch (e) {
      _logError('refresh', e);
      if (uid == _userId) _loadFailed = true;
    } finally {
      if (uid == _userId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Se [day] è prima della finestra caricata, estende la finestra e ricarica.
  Future<void> ensureLoaded(DateTime day) async {
    final since = _loadedSince;
    if (since == null) return; // il primo refresh userà la finestra di default
    final d = DateTime(day.year, day.month, day.day);
    if (!d.isBefore(since)) return;
    _loadedSince = d.subtract(const Duration(days: _windowDays));
    await refresh();
  }

  void _applyTakenToday() {
    final today = DateTime.now();
    for (final t in _therapyItems) {
      t.taken = isTherapyTaken(t.id, today);
    }
  }

  void _logError(String where, Object e) {
    // Niente messaggi/valori nei log: potrebbero contenere dati sanitari.
    if (kDebugMode) {
      final code = e is PostgrestException ? ' (${e.code})' : '';
      debugPrint('HealthProvider.$where: ${e.runtimeType}$code');
    }
  }

  /// Esegue la scrittura e poi ricarica la parte interessata.
  ///
  /// Restituisce `true` anche se la ricarica fallisce: la riga è stata
  /// salvata e segnalare un falso errore indurrebbe l'utente a ripetere
  /// l'inserimento. In quel caso si alza invece [loadFailed], così la UI
  /// mostra il banner "Riprova" invece di una lista obsoleta.
  Future<bool> _write(Future<void> Function() op, Future<void> Function() reload) async {
    try {
      await op();
    } catch (e) {
      _logError('write', e);
      return false;
    }
    try {
      await reload();
    } catch (e) {
      _logError('reload', e);
      _loadFailed = true;
      notifyListeners();
    }
    return true;
  }

  /// Ricarica evitando di applicare i risultati se l'utente è cambiato
  /// durante la chiamata (stessa difesa di [refresh]).
  Future<T?> _reloadIfSameUser<T>(String? uid, Future<T> Function() fetch) async {
    final value = await fetch();
    if (uid != _userId) return null;
    return value;
  }

  Future<void> _reloadVitals() async {
    final uid = _userId;
    final v = await _reloadIfSameUser(uid, () => _service.fetchVitals(_since));
    if (v == null) return;
    _glucose = v.glucose;
    _pressure = v.pressure;
    notifyListeners();
  }

  Future<void> _reloadMeals() async {
    final uid = _userId;
    final meals = await _reloadIfSameUser(uid, () => _service.fetchMeals(_since));
    if (meals == null) return;
    _meals = meals;
    notifyListeners();
  }

  Future<void> _reloadActivities() async {
    final uid = _userId;
    final activities = await _reloadIfSameUser(uid, () => _service.fetchActivities(_since));
    if (activities == null) return;
    _activities = activities;
    notifyListeners();
  }

  Future<void> _reloadTherapies() async {
    final uid = _userId;
    final result = await _reloadIfSameUser(
        uid, () => (_service.fetchTherapies(), _service.fetchTherapyLogs(_since)).wait);
    if (result == null) return;
    final (items, logs) = result;
    _therapyItems = items;
    _therapyLogs = logs;
    _applyTakenToday();
    notifyListeners();
  }

  // ---------------------------------------------------------------- Terapia

  /// Segna come presa / annulla l'assunzione di OGGI.
  Future<bool> toggleTherapyTaken(String id) async {
    if (_togglingTherapy.contains(id)) return false; // doppio tap
    _togglingTherapy.add(id);
    notifyListeners(); // la UI disabilita il pulsante mentre si attende
    try {
      final today = DateTime.now();
      final existing =
          _therapyLogs.where((l) => l.therapyId == id && _sameDay(l.takenAt, today)).toList();
      return await _write(
        () => existing.isEmpty
            ? _service.insertTherapyLog(id, today)
            : _service.deleteTherapyLogs(existing.map((l) => l.id).toList()),
        _reloadTherapies,
      );
    } finally {
      _togglingTherapy.remove(id);
      notifyListeners();
    }
  }

  /// L'id di [item] viene ignorato: lo assegna il database.
  Future<bool> addTherapyItem(TherapyItem item) =>
      _write(() => _service.insertTherapy(name: item.name, time: item.time), _reloadTherapies);

  Future<bool> updateTherapyItem(String id, {String? name, String? time}) =>
      _write(() => _service.updateTherapy(id, name: name, time: time), _reloadTherapies);

  /// Disattiva la terapia (lo storico delle assunzioni viene conservato).
  Future<bool> removeTherapyItem(String id) =>
      _write(() => _service.deactivateTherapy(id), _reloadTherapies);

  // ---------------------------------------------------------------- Glicemia

  Future<bool> addGlucoseReading(double value, {DateTime? at}) =>
      _write(() => _service.insertGlucose(value, at ?? DateTime.now()), _reloadVitals);

  Future<bool> updateGlucose(String id, double value) =>
      _write(() => _service.updateGlucose(id, value), _reloadVitals);

  Future<bool> deleteGlucose(String id) => _write(() => _service.deleteVital(id), _reloadVitals);

  Future<bool> removeLastGlucose() {
    final id = lastGlucose?.id;
    return id == null ? Future.value(false) : deleteGlucose(id);
  }

  // --------------------------------------------------------------- Pressione

  Future<bool> addPressureReading(int systolic, int diastolic, {DateTime? at}) => _write(
      () => _service.insertPressure(systolic, diastolic, at ?? DateTime.now()), _reloadVitals);

  Future<bool> updatePressure(String id, int systolic, int diastolic) =>
      _write(() => _service.updatePressure(id, systolic, diastolic), _reloadVitals);

  Future<bool> deletePressure(String id) => _write(() => _service.deleteVital(id), _reloadVitals);

  Future<bool> removeLastPressure() {
    final id = lastPressure?.id;
    return id == null ? Future.value(false) : deletePressure(id);
  }

  // ---------------------------------------------------------------- Attività

  Future<bool> addActivity(ActivityEntry entry) =>
      _write(() => _service.insertActivity(entry), _reloadActivities);

  Future<bool> updateActivity(String id, {required int minutes, required int steps}) =>
      _write(() => _service.updateActivity(id, minutes: minutes, steps: steps), _reloadActivities);

  Future<bool> deleteActivity(String id) =>
      _write(() => _service.deleteActivity(id), _reloadActivities);

  // ------------------------------------------------------------------- Pasti

  Future<bool> addMeal(MealEntry entry) => _write(() => _service.insertMeal(entry), _reloadMeals);

  /// Se le calorie restano quelle stimate, il pasto resta "stimato";
  /// se l'utente le cambia diventano un dato inserito a mano.
  Future<bool> updateMeal(String id, {required String description, required int calories}) {
    final existing = _meals.where((m) => m.id == id).firstOrNull;
    final stillEstimated = existing != null && existing.isEstimated && existing.calories == calories;
    return _write(
      () => _service.updateMeal(id,
          description: description, calories: calories, isEstimated: stillEstimated),
      _reloadMeals,
    );
  }

  Future<bool> deleteMeal(String id) => _write(() => _service.deleteMeal(id), _reloadMeals);

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}