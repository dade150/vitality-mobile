/// Contenitore mutabile dei dati raccolti nei tre step della registrazione.
///
/// Un'unica istanza viene creata da [RegisterScreen] e passata per
/// riferimento a ciascuno step: ogni step scrive direttamente sui suoi campi,
/// così i valori sopravvivono al passaggio avanti/indietro tra le pagine
/// della PageView senza bisogno di un provider dedicato.
class RegistrationData {
  // Step 1 - Profilo base
  String name = '';
  String surname = '';
  DateTime? birth;
  String? sesso; // 'maschio' | 'femmina'
  int? altezza; // cm
  double? peso; // kg
  String noteAnamnestiche = '';

  // Step 2 - Credenziali
  String email = '';
  String password = '';
  bool consensoPrivacy = false;

  // Step 3 - Preferenze diario e notifiche
  bool showActivities = true;
  bool showMeals = true;
  bool showAppointments = true;
  bool showReports = true;
  String fontSize = 'grande'; // 'piccolo' | 'medio' | 'grande'
  bool darkMode = false;
  bool notifyTherapy = true;
  bool notifyAppointments = true;

  /// Converte i dati nel formato atteso da `raw_user_meta_data` in Supabase,
  /// da cui il trigger `handle_new_user` popola `user`, `profile` e
  /// `user_settings` nella stessa transazione.
  Map<String, dynamic> toMetadata() {
    return {
      'name': name,
      'surname': surname,
      'birth': birth?.toIso8601String(),
      'sesso': sesso,
      'altezza': altezza,
      'peso': peso,
      'note_anamnestiche': noteAnamnestiche.isEmpty ? null : noteAnamnestiche,
      'consenso_privacy': consensoPrivacy,
      'show_meals': showMeals,
      'show_activities': showActivities,
      'show_reports': showReports,
      'show_appointments': showAppointments,
      'font_size': fontSize,
      'dark_mode': darkMode,
      'notify_therapy': notifyTherapy,
      'notify_appointments': notifyAppointments,
    };
  }
}