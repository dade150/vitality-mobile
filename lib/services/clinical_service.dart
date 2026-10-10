import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clinical_parameter.dart';
import 'error_handler.dart';

/// Accesso a Supabase per i parametri clinici, nella tabella `diabetes_data`
/// (stessa di glicemia e pressione, distinti da `metric_type`).
///
/// Regole come [HealthService]:
/// - `user_id` NON viene mai inviato: lo imposta il database
///   (`default auth.uid()`) e la RLS ne verifica la corrispondenza.
/// - ogni query è limitata ai tipi clinici (`_codes`): questo service non può
///   leggere né toccare glicemia e pressione.
/// - update/delete controllano che almeno una riga sia stata toccata
///   (con la RLS un'operazione negata non dà errore ma 0 righe).
/// - i valori vengono validati anche qui, oltre che nella UI e nei CHECK.
///
/// Data: l'utente sceglie il GIORNO dell'esame. `measured_at` è un timestamptz,
/// quindi si salva a mezzogiorno locale: nessuno scivolamento di giorno
/// per differenze di fuso orario. `created_at` resta l'istante di inserimento.
class ClinicalService {
  ClinicalService([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const _table = 'diabetes_data';

  static final List<String> _codes = List.unmodifiable(
    ClinicalParameterType.values.map((t) => t.dbCode),
  );

  // ------------------------------------------------------------ Conversioni
  static String? _id(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }

  /// Giorno scelto -> ISO UTC di mezzogiorno locale.
  static String _isoForDay(DateTime d) => DateTime(d.year, d.month, d.day, 12).toUtc().toIso8601String();

  /// measured_at -> solo giorno, nel fuso del dispositivo.
  static DateTime? _dayOf(dynamic v) {
    final t = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    return t == null ? null : DateTime(t.year, t.month, t.day);
  }

  /// Formato richiesto dal CHECK (punto decimale, decimali fissi): "6.8", "92".
  static String _fmt(ClinicalParameterType type, double v) =>
      type.round(v).toStringAsFixed(type.decimals);

  static void _requireAffected(List<dynamic> rows) {
    if (rows.isEmpty) {
      throw const AppFailure(
        'L\'elemento non esiste più o non puoi modificarlo.',
        cause: 'nessuna riga interessata (record assente o bloccato da RLS)',
      );
    }
  }

  // ------------------------------------------------------------ Validazioni
  static void _check(ClinicalParameterType type, double value, DateTime on) {
    if (!type.isInRange(value)) throw ArgumentError('${type.dbCode} fuori range');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(on.year, on.month, on.day);
    if (day.isAfter(today) || day.isBefore(ClinicalParameterType.earliestDate)) {
      throw ArgumentError('data esame non valida');
    }
  }

  // ----------------------------------------------------------------- Lettura

  /// Tutti i valori clinici dell'utente, dal più recente. Sono pochi (qualche
  /// misura all'anno): niente finestra temporale, solo un tetto di sicurezza.
  Future<List<ClinicalReading>> fetchAll() async {
    final rows = await _db
        .from(_table)
        .select('id, metric_type, metric_value, measured_at')
        .inFilter('metric_type', _codes)
        .order('measured_at', ascending: false)
        .limit(1000);

    final out = <ClinicalReading>[];
    for (final r in rows) {
      final id = _id(r['id']);
      final type = ClinicalParameterType.fromDb(r['metric_type']?.toString());
      final value = double.tryParse(r['metric_value']?.toString() ?? '');
      final on = _dayOf(r['measured_at']);
      if (id == null || type == null || value == null || on == null) continue;
      out.add(ClinicalReading(id: id, type: type, value: value, measuredOn: on));
    }
    return out;
  }

  // --------------------------------------------------------------- Scrittura

  Future<void> insert(ClinicalParameterType type, double value, DateTime on) async {
    _check(type, value, on);
    await _db.from(_table).insert({
      'metric_type': type.dbCode,
      'metric_value': _fmt(type, value),
      'measured_at': _isoForDay(on),
    });
  }

  Future<void> update(String id, ClinicalParameterType type, double value, DateTime on) async {
    _check(type, value, on);
    final rows = await _db
        .from(_table)
        .update({'metric_value': _fmt(type, value), 'measured_at': _isoForDay(on)})
        .eq('id', id)
        .eq('metric_type', type.dbCode)
        .select('id');
    _requireAffected(rows);
  }

  Future<void> delete(String id) async {
    final rows = await _db
        .from(_table)
        .delete()
        .eq('id', id)
        .inFilter('metric_type', _codes)
        .select('id');
    _requireAffected(rows);
  }
}