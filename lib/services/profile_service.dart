import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'error_handler.dart';

/// Accesso a Supabase per l'utente: anagrafica in `user` e dati fisici in
/// `profile` (FK `profile.user_id`).
///
/// Regole come [HealthService]/[ClinicalService]:
/// - `user_id` NON viene mai inviato in update: è il filtro di riga, il
///   valore della colonna lo decide già il database (`handle_new_user`).
/// - le scritture controllano quante righe hanno toccato: con la RLS un'
///   operazione negata non dà errore ma 0 righe, e dati salvati che non
///   arrivano mai in database sono il bug peggiore che un form "Salva" possa fare.
/// - le date `date` vengono inviate come sola data (yyyy-MM-dd), senza orario.
class ProfileService {
  ProfileService([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const _userTable = 'user';
  static const _profileTable = 'profile';

  // ------------------------------------------------------------ Conversioni

  /// Colonna `date`: solo la data, così non scivola di giorno col fuso.
  static String _dateOnly(DateTime d) => d.toIso8601String().split('T')[0];

  static void _requireAffected(List<Map<String, dynamic>> rows, {required String what}) {
    if (rows.isEmpty) {
      throw AppFailure(
        'Non è stato possibile salvare i tuoi dati: record assente o non autorizzato.',
        cause: 'nessuna riga aggiornata in $what (record assente o bloccato da RLS)',
      );
    }
  }

  // ----------------------------------------------------------------- Lettura

  /// Anagrafica + dati fisici in un colpo solo (join su `profile.user_id`).
  Future<Profile> fetch(String userId) async {
    // PostgREST restituisce la parte "molti" della relazione come lista.
    final data = await _db.from(_userTable).select('*, profile(*)').eq('id', userId).maybeSingle();

    if (data == null) {
      throw const AppFailure(
        'Non è stato possibile caricare il tuo profilo.',
        unexpected: true,
        cause: 'riga assente nella tabella `user`',
      );
    }

    final rel = data['profile'];
    final physical = switch (rel) {
      List rows when rows.isNotEmpty && rows.first is Map =>
        Map<String, dynamic>.from(rows.first as Map),
      Map<String, dynamic> row => row,
      _ => const <String, dynamic>{},
    };

    return Profile.fromRows(data, physical);
  }

  // --------------------------------------------------------------- Scrittura

  /// Aggiorna l'anagrafica (tabella `user`). I campi null vengono ignorati.
  Future<void> updateAnagrafica(
    String userId, {
    String? name,
    String? surname,
    DateTime? birth,
    String? phone,
  }) async {
    if (name == null && surname == null && birth == null && phone == null) return;

    final rows = await _db.from(_userTable).update({
      if (name != null) 'name': name.trim(),
      if (surname != null) 'surname': surname.trim(),
      if (birth != null) 'birth': _dateOnly(birth),
      if (phone != null) 'phone': phone.trim(),
    }).eq('id', userId).select('id');

    _requireAffected(rows, what: _userTable);
  }

  /// Aggiorna i dati fisici (tabella `profile`).
  ///
  /// La riga `profile` la crea in registrazione il trigger `handle_new_user`:
  /// se manca (account migrati o RLS), l'update tocca 0 righe e i dati
  /// sparirebbero in silenzio — in quel caso si inserisce la riga.
  Future<void> updateDatiFisici(
    String userId, {
    double? peso,
    int? altezza,
    String? sesso,
    String? noteAnamnestiche,
  }) async {
    if (peso == null && altezza == null && sesso == null && noteAnamnestiche == null) return;

    // Sesso vuoto == "non specificato": non si scrive '' in un enum.
    final values = <String, dynamic>{
      if (peso != null) 'peso': peso,
      if (altezza != null) 'altezza': altezza,
      if (sesso != null && sesso.trim().isNotEmpty) 'sesso': sesso.trim().toLowerCase(),
      if (noteAnamnestiche != null) 'note_anamnestiche': noteAnamnestiche,
    };
    if (values.isEmpty) return;

    final rows =
        await _db.from(_profileTable).update(values).eq('user_id', userId).select('id');

    if (rows.isEmpty) {
      await _db.from(_profileTable).insert({'user_id': userId, ...values});
    }
  }
}
