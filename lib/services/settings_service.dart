import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_settings.dart';

/// Accesso a Supabase per le preferenze utente nella tabella `public.user_settings`.
///
/// La tabella è protetta da RLS: ogni utente può leggere e modificare solo la
/// propria riga (`user_id = auth.uid()`).
class SettingsService {
  SettingsService([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;
  static const _table = 'user_settings';

  /// Carica le preferenze dell'utente dal database.
  ///
  /// Se per qualsiasi motivo la riga non esiste ancora (es. account legacy o
  /// inserimento fallito in registrazione), tenta di crearne una con i valori di
  /// default o restituisce un'istanza con le impostazioni standard.
  Future<UserSettings> fetch(String userId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) {
      try {
        final inserted = await _db
            .from(_table)
            .insert({
              'user_id': userId,
              'font_size': 'GRANDE',
              'dark_mode': false,
              'notify_therapy': true,
              'notify_appointments': true,
              'show_meals': true,
              'show_activities': true,
              'show_reports': true,
              'show_appointments': true,
            })
            .select()
            .maybeSingle();

        if (inserted != null) {
          return UserSettings.fromMap(inserted);
        }
      } catch (_) {
        // Se l'insert fallisce (es. vincoli o permessi), ritorna i default in memoria.
      }
      return UserSettings.defaults(userId);
    }

    return UserSettings.fromMap(data);
  }

  /// Aggiorna le preferenze dell'utente nella tabella `user_settings`.
  Future<void> update(
    String userId, {
    AppFontSize? fontSize,
    bool? darkMode,
    bool? autoTts,
    bool? notifyTherapy,
    bool? notifyAppointments,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (fontSize != null) 'font_size': fontSize.dbCode,
      if (darkMode != null) 'dark_mode': darkMode,
      if (autoTts != null) 'auto_tts': autoTts,
      if (notifyTherapy != null) 'notify_therapy': notifyTherapy,
      if (notifyAppointments != null) 'notify_appointments': notifyAppointments,
    };

    try {
      final rows = await _db
          .from(_table)
          .update(payload)
          .eq('user_id', userId)
          .select('id');

      if (rows.isEmpty) {
        // Se non c'era ancora una riga associata, inseriscila.
        final insertPayload = <String, dynamic>{
          'user_id': userId,
          'font_size': fontSize?.dbCode ?? 'GRANDE',
          'dark_mode': darkMode ?? false,
          if (autoTts != null) 'auto_tts': autoTts,
          'notify_therapy': notifyTherapy ?? true,
          'notify_appointments': notifyAppointments ?? true,
          'show_meals': true,
          'show_activities': true,
          'show_reports': true,
          'show_appointments': true,
          ...payload,
        };
        try {
          await _db.from(_table).insert(insertPayload);
        } on PostgrestException catch (e) {
          final isMissingCol = e.code == 'PGRST204' ||
              e.code == '42703' ||
              e.message.toLowerCase().contains('auto_tts');
          if (isMissingCol && autoTts != null) {
            insertPayload.remove('auto_tts');
            await _db.from(_table).insert(insertPayload);
            return;
          }
          rethrow;
        }
      }
    } on PostgrestException catch (e) {
      final isMissingCol = e.code == 'PGRST204' ||
          e.code == '42703' ||
          e.message.toLowerCase().contains('auto_tts');
      if (isMissingCol && autoTts != null) {
        payload.remove('auto_tts');
        // Se restavano solo updated_at o altri campi, aggiorna senza auto_tts
        if (payload.keys.any((k) => k != 'updated_at')) {
          await _db.from(_table).update(payload).eq('user_id', userId);
        }
        return;
      }
      rethrow;
    }
  }
}
