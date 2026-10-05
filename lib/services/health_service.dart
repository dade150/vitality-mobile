import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_entry.dart';
import '../models/meal_entry.dart';
import '../models/therapy_item.dart';
import '../models/vital_readings.dart';
import 'error_handler.dart';

/// Registrazione di un'assunzione di terapia (riga di `therapy_logs`).
class TherapyLog {
  final String id;
  final String therapyId;
  final DateTime takenAt;

  const TherapyLog({required this.id, required this.therapyId, required this.takenAt});
}

/// Accesso a Supabase per il Diario.
///
/// Sicurezza:
/// - `user_id` NON viene mai inviato: lo imposta il database
///   (`default auth.uid()`), e la RLS verifica che coincida con l'utente.
/// - Update e delete controllano che almeno una riga sia stata toccata:
///   se la RLS blocca l'operazione Supabase non dà errore ma 0 righe.
/// - Gli insert NON fanno lo stesso controllo: con la RLS un insert negato
///   genera errore (quindi viene già intercettato), mentre un `.select()`
///   subito dopo l'insert può restituire vuoto se manca la policy di lettura
///   e farebbe fallire un salvataggio in realtà riuscito.
/// - I valori vengono validati anche qui (oltre che nella UI e nei CHECK
///   del database).
class HealthService {
  HealthService([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  // Tipi di attività: etichetta dell'app -> enum del database.
  static const Map<String, String> _activityToDb = {
    'Camminata': 'CAMMINATA',
    'Corsa': 'CORSA',
    'Nuoto': 'NUOTO',
    'Ciclismo': 'BICICLETTA',
    'Ginnastica': 'PALESTRA',
    'Altro': 'ALTRO',
  };
  static final Map<String, String> _activityFromDb = {
    for (final e in _activityToDb.entries) e.value: e.key,
  };

  /// Etichette mostrate nella UI: sono le chiavi di [_activityToDb], così
  /// l'elenco del menu e i valori scritti nel database non possono divergere.
  static final List<String> activityLabels = List.unmodifiable(_activityToDb.keys);

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  /// 0 righe toccate = la riga non c'è più (lista obsoleta, doppia
  /// eliminazione) oppure la RLS non consente l'operazione: Supabase non
  /// genera errore ma restituisce un result set vuoto. E' una condizione
  /// "attesa" che l'utente può capire, quindi viene lanciata come
  /// [AppFailure] non imprevisto: il messaggio finisce nel form/snackbar
  /// invece che nella schermata di errore.
  static void _requireAffected(List<dynamic> rows) {
    if (rows.isEmpty) {
      throw const AppFailure(
        'L\'elemento non esiste più o non puoi modificarlo.',
        cause: 'nessuna riga interessata (record assente o bloccato da RLS)',
      );
    }
  }

  // ------------------------------------------------- Conversioni da PostgREST
  //
  // I valori arrivano come `dynamic`: una riga anche solo parzialmente
  // malformata non deve far fallire l'intero caricamento del Diario (e non
  // deve produrre id fittizi come la stringa "null").

  static String? _str(dynamic v) => v?.toString();

  /// Id di riga: `null` se assente o inutilizzabile, mai la stringa "null".
  static String? _id(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }

  static int _int(dynamic v, [int orElse = 0]) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? orElse;
  }

  static bool _bool(dynamic v) => v == true;

  // ------------------------------------------------------------ Validazioni

  static void _checkGlucose(double v) {
    if (v.isNaN || v < 20 || v > 600) throw ArgumentError('glicemia fuori range');
  }

  static void _checkPressure(int sys, int dia) {
    if (sys < 50 || sys > 260 || dia < 30 || dia > 150 || sys <= dia) {
      throw ArgumentError('pressione fuori range');
    }
  }

  static void _checkMeal(String description, int calories) {
    if (description.trim().isEmpty || description.length > 500) {
      throw ArgumentError('descrizione pasto non valida');
    }
    if (calories < 0 || calories > 10000) throw ArgumentError('calorie fuori range');
  }

  static void _checkActivity(int minutes, int steps) {
    if (minutes < 1 || minutes > 1440) throw ArgumentError('durata fuori range');
    if (steps < 0 || steps > 200000) throw ArgumentError('passi fuori range');
  }

  /// "8:00" / "08:00" -> "08:00"; null se non valido.
  static String? normalizeTime(String input) {
    final m = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(input.trim());
    if (m == null) return null;
    return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  }

  // ------------------------------------------------- Glicemia e pressione

  Future<({List<GlucoseReading> glucose, List<BloodPressureReading> pressure})> fetchVitals(
      DateTime since) async {
    final rows = await _db
        .from('diabetes_data')
        .select('id, metric_type, metric_value, measured_at')
        .inFilter('metric_type', ['GLICEMIA', 'PRESSIONE'])
        .gte('measured_at', _iso(since))
        .order('measured_at', ascending: true);

    final glucose = <GlucoseReading>[];
    final pressure = <BloodPressureReading>[];

    for (final r in rows) {
      final time = DateTime.tryParse(_str(r['measured_at']) ?? '')?.toLocal();
      final raw = _str(r['metric_value']);
      final type = _str(r['metric_type']);
      final id = _id(r['id']);
      if (time == null || raw == null || type == null || id == null) continue;

      if (type == 'GLICEMIA') {
        final v = double.tryParse(raw);
        if (v != null) glucose.add(GlucoseReading(id: id, time: time, value: v));
      } else if (type == 'PRESSIONE') {
        final parts = raw.split('/');
        if (parts.length != 2) continue;
        final s = int.tryParse(parts[0].trim());
        final d = int.tryParse(parts[1].trim());
        if (s != null && d != null) {
          pressure.add(BloodPressureReading(id: id, time: time, systolic: s, diastolic: d));
        }
      }
    }
    return (glucose: glucose, pressure: pressure);
  }

  static String _fmtGlucose(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> insertGlucose(double value, DateTime at) async {
    _checkGlucose(value);
    await _db.from('diabetes_data').insert({
      'metric_type': 'GLICEMIA',
      'metric_value': _fmtGlucose(value),
      'measured_at': _iso(at),
    });
  }

  Future<void> updateGlucose(String id, double value) async {
    _checkGlucose(value);
    final rows = await _db
        .from('diabetes_data')
        .update({'metric_value': _fmtGlucose(value)})
        .eq('id', id)
        .eq('metric_type', 'GLICEMIA')
        .select('id');
    _requireAffected(rows);
  }

  Future<void> insertPressure(int sys, int dia, DateTime at) async {
    _checkPressure(sys, dia);
    await _db.from('diabetes_data').insert({
      'metric_type': 'PRESSIONE',
      'metric_value': '$sys/$dia',
      'measured_at': _iso(at),
    });
  }

  Future<void> updatePressure(String id, int sys, int dia) async {
    _checkPressure(sys, dia);
    final rows = await _db
        .from('diabetes_data')
        .update({'metric_value': '$sys/$dia'})
        .eq('id', id)
        .eq('metric_type', 'PRESSIONE')
        .select('id');
    _requireAffected(rows);
  }

  /// Elimina una misurazione (glicemia o pressione).
  Future<void> deleteVital(String id) async {
    final rows = await _db
        .from('diabetes_data')
        .delete()
        .eq('id', id)
        .inFilter('metric_type', ['GLICEMIA', 'PRESSIONE'])
        .select('id');
    _requireAffected(rows);
  }

  // ------------------------------------------------------------------ Pasti

  Future<List<MealEntry>> fetchMeals(DateTime since) async {
    final rows = await _db
        .from('meals')
        .select('id, meal_type, description, calories, is_estimated, meal_at')
        .gte('meal_at', _iso(since))
        .order('meal_at', ascending: true);

    final out = <MealEntry>[];
    for (final r in rows) {
      final date = DateTime.tryParse(_str(r['meal_at']) ?? '')?.toLocal();
      final id = _id(r['id']);
      if (date == null || id == null) continue;
      final dbType = _str(r['meal_type']) ?? '';
      out.add(MealEntry(
        id: id,
        date: date,
        type: MealType.values.firstWhere(
          (t) => t.name.toUpperCase() == dbType,
          orElse: () => MealType.spuntino,
        ),
        description: _str(r['description']) ?? '',
        calories: _int(r['calories']),
        isEstimated: _bool(r['is_estimated']),
      ));
    }
    return out;
  }

  Future<void> insertMeal(MealEntry e) async {
    _checkMeal(e.description, e.calories);
    await _db.from('meals').insert({
      'meal_type': e.type.name.toUpperCase(),
      'description': e.description.trim(),
      'calories': e.calories,
      'is_estimated': e.isEstimated,
      'meal_at': _iso(e.date),
    });
  }

  Future<void> updateMeal(
    String id, {
    required String description,
    required int calories,
    required bool isEstimated,
  }) async {
    _checkMeal(description, calories);
    final rows = await _db
        .from('meals')
        .update({
          'description': description.trim(),
          'calories': calories,
          'is_estimated': isEstimated,
        })
        .eq('id', id)
        .select('id');
    _requireAffected(rows);
  }

  Future<void> deleteMeal(String id) async {
    final rows = await _db.from('meals').delete().eq('id', id).select('id');
    _requireAffected(rows);
  }

  // -------------------------------------------------------------- Attività

  Future<List<ActivityEntry>> fetchActivities(DateTime since) async {
    final rows = await _db
        .from('physical_activities')
        .select('id, activity_type, duration_minutes, steps, activity_at')
        .gte('activity_at', _iso(since))
        .order('activity_at', ascending: true);

    final out = <ActivityEntry>[];
    for (final r in rows) {
      final date = DateTime.tryParse(_str(r['activity_at']) ?? '')?.toLocal();
      final id = _id(r['id']);
      if (date == null || id == null) continue;
      out.add(ActivityEntry(
        id: id,
        date: date,
        type: _activityFromDb[_str(r['activity_type'])] ?? 'Altro',
        minutes: _int(r['duration_minutes']),
        steps: _int(r['steps']),
      ));
    }
    return out;
  }

  Future<void> insertActivity(ActivityEntry e) async {
    _checkActivity(e.minutes, e.steps);
    await _db.from('physical_activities').insert({
      'activity_type': _activityToDb[e.type] ?? 'ALTRO',
      'duration_minutes': e.minutes,
      'steps': e.steps > 0 ? e.steps : null,
      'activity_at': _iso(e.date),
    });
  }

  Future<void> updateActivity(String id, {required int minutes, required int steps}) async {
    _checkActivity(minutes, steps);
    final rows = await _db
        .from('physical_activities')
        .update({'duration_minutes': minutes, 'steps': steps > 0 ? steps : null})
        .eq('id', id)
        .select('id');
    _requireAffected(rows);
  }

  Future<void> deleteActivity(String id) async {
    final rows = await _db.from('physical_activities').delete().eq('id', id).select('id');
    _requireAffected(rows);
  }

  // ---------------------------------------------------------------- Terapia

  /// Terapie attive. `taken` viene impostato dal provider in base ai log.
  Future<List<TherapyItem>> fetchTherapies() async {
    final rows = await _db
        .from('therapies')
        .select('id, drug_name, scheduled_time')
        .eq('is_active', true)
        .order('scheduled_time', ascending: true, nullsFirst: false)
        .order('id', ascending: true);

    final out = <TherapyItem>[];
    for (final r in rows) {
      final id = _id(r['id']);
      if (id == null) continue;
      out.add(TherapyItem(
        id: id,
        name: _str(r['drug_name']) ?? '',
        time: _hhmm(r['scheduled_time']),
      ));
    }
    return out;
  }

  static String _hhmm(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : '--:--';
  }

  Future<void> insertTherapy({required String name, required String time}) async {
    final n = name.trim();
    if (n.isEmpty || n.length > 100) throw ArgumentError('nome terapia non valido');
    final t = normalizeTime(time);
    if (t == null) throw ArgumentError('orario non valido');
    await _db.from('therapies').insert({
      // La schermata di configurazione non raccoglie ancora tipo/dosaggio/
      // frequenza (colonne NOT NULL): valori di ripiego.
      'therapy_type': 'ALTRO',
      'drug_name': n,
      'dosage': '-',
      'frequency': 'Giornaliera',
      'scheduled_time': t,
      'is_active': true,
    });
  }

  Future<void> updateTherapy(String id, {String? name, String? time}) async {
    final data = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      if (name.trim().length > 100) throw ArgumentError('nome terapia non valido');
      data['drug_name'] = name.trim();
    }
    if (time != null && time.trim().isNotEmpty) {
      final t = normalizeTime(time);
      if (t == null) throw ArgumentError('orario non valido');
      data['scheduled_time'] = t;
    }
    if (data.isEmpty) return;
    final rows = await _db.from('therapies').update(data).eq('id', id).select('id');
    _requireAffected(rows);
  }

  /// Disattiva la terapia (soft delete): lo storico delle assunzioni resta.
  Future<void> deactivateTherapy(String id) async {
    final rows =
        await _db.from('therapies').update({'is_active': false}).eq('id', id).select('id');
    _requireAffected(rows);
  }

  Future<List<TherapyLog>> fetchTherapyLogs(DateTime since) async {
    final rows = await _db
        .from('therapy_logs')
        .select('id, therapy_id, taken_at')
        .eq('status', 'taken')
        .gte('taken_at', _iso(since))
        .order('taken_at', ascending: true);

    final out = <TherapyLog>[];
    for (final r in rows) {
      final at = DateTime.tryParse(_str(r['taken_at']) ?? '')?.toLocal();
      final id = _id(r['id']);
      final therapyId = _id(r['therapy_id']);
      if (at == null || id == null || therapyId == null) continue;
      out.add(TherapyLog(id: id, therapyId: therapyId, takenAt: at));
    }
    return out;
  }

  Future<void> insertTherapyLog(String therapyId, DateTime at) async {
    final raw = therapyId.trim();
    if (raw.isEmpty || raw == 'null') throw ArgumentError('id terapia non valido');
    // L'id arriva come String dal fetch: se è numerico (bigint) si riconverte,
    // altrimenti si invia così com'è (uuid) e a convertire è il database.
    final Object id = int.tryParse(raw) ?? raw;
    await _db.from('therapy_logs').insert({
      'therapy_id': id,
      'taken_at': _iso(at),
      'status': 'taken',
    });
  }

  Future<void> deleteTherapyLogs(List<String> ids) async {
    if (ids.isEmpty) return;
    final rows = await _db.from('therapy_logs').delete().inFilter('id', ids).select('id');
    _requireAffected(rows);
  }
}