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

  // Step 2 - Credenziali e Consensi Legali (GDPR Art. 6.1.b, Art. 7, Art. 9.2.a)
  static const String currentTermsVersion = '1.0';
  static const String currentPrivacyVersion = '1.0';

  String email = '';
  String password = '';
  bool termsAccepted = false;
  bool consensoPrivacy = false;

  // Step 3 - Preferenze e notifiche
  bool showActivities = true;
  bool showMeals = true;
  bool showAppointments = true;
  bool showReports = true;
  String fontSize = 'GRANDE'; // 'PICCOLO' | 'MEDIO' | 'GRANDE'
  bool darkMode = false;
  bool notifyTherapy = true;
  bool notifyAppointments = true;

  /// Converte i dati nel formato atteso da `raw_user_meta_data` in Supabase,
  /// da cui il trigger `handle_new_user` popola `user`, `profile` e
  /// `user_settings` nella stessa transazione.
  Map<String, dynamic> toMetadata() {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return {
      'name': name,
      'surname': surname,
      'birth': birth?.toIso8601String(),
      'sesso': sesso,
      'altezza': altezza,
      'peso': peso,
      'note_anamnestiche': noteAnamnestiche.isEmpty ? null : noteAnamnestiche,
      'terms_accepted': termsAccepted,
      'terms_accepted_at': termsAccepted ? nowIso : null,
      'terms_version': currentTermsVersion,
      'consenso_privacy': consensoPrivacy,
      'consenso_privacy_at': consensoPrivacy ? nowIso : null,
      'privacy_version': currentPrivacyVersion,
      'ai_health_consent': consensoPrivacy,
      'ai_health_consent_at': consensoPrivacy ? nowIso : null,
      'show_meals': showMeals,
      'show_activities': showActivities,
      'show_reports': showReports,
      'show_appointments': showAppointments,
      'font_size': fontSize.toUpperCase(),
      'dark_mode': darkMode,
      'notify_therapy': notifyTherapy,
      'notify_appointments': notifyAppointments,
    };
  }
}
