/// Anagrafica (tabella `user`) + dati fisici (tabella `profile`) dell'utente,
/// ottenute con un unico join `user -> profile` (FK `profile.user_id`).
///
/// Il modello è "piatto": non espone i due record separati, perché tutta
/// l'app consuma un solo oggetto (schermata profilo, BMI, ecc.).
class Profile {
  final String id;
  final String name;
  final String surname;

  /// Può essere assente (colonna `date` nullable): l'età in tal caso è null.
  final DateTime? birth;

  final String email;
  final String phone;
  final double peso;
  final int altezza;

  /// Valore normalizzato in minuscolo di `profile.sesso` (enum Postgres):
  /// `'maschio' | 'femmina' | ''`. Deve coincidere con le etichette inviate
  /// in registrazione da `RegistrationData.toMetadata()` (RegisterStep1).
  final String sesso;

  final String? noteAnamnestiche;

  const Profile({
    required this.id,
    required this.name,
    required this.surname,
    required this.birth,
    required this.email,
    required this.phone,
    required this.peso,
    required this.altezza,
    required this.sesso,
    this.noteAnamnestiche,
  });

  /// Valori di `sesso` che l'app scrive nel database: devono essere presenti
  /// nell'enum Postgres (quelli non inclusi vengono mostri ma non proposti).
  static const List<String> sessoValues = <String>['maschio', 'femmina'];

  /// Costruisce il profilo dalle due righe del join.
  ///
  /// I parsing sono difensivi: una colonna assente o di tipo inatteso non deve
  /// mai far fallire il caricamento della schermata.
  factory Profile.fromRows(Map<String, dynamic> user, Map<String, dynamic> physical) {
    return Profile(
      id: '${user['id'] ?? ''}',
      name: '${user['name'] ?? ''}',
      surname: '${user['surname'] ?? ''}',
      birth: DateTime.tryParse('${user['birth']}'),
      email: '${user['email'] ?? ''}',
      phone: '${user['phone'] ?? ''}',
      peso: num.tryParse('${physical['peso']}')?.toDouble() ?? 0,
      altezza: num.tryParse('${physical['altezza']}')?.toInt() ?? 0,
      sesso: '${physical['sesso'] ?? ''}'.trim().toLowerCase(),
      noteAnamnestiche: '${physical['note_anamnestiche'] ?? ''}'.isEmpty
          ? null
          : physical['note_anamnestiche'] as String?,
    );
  }

  /// Etichetta leggibile di un valore di `sesso` (qualsiasi casing).
  static String labelForSesso(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'maschio':
        return 'Maschio';
      case 'femmina':
        return 'Femmina';
      case 'altro':
        return 'Altro';
      case '':
        return 'Non specificato';
      default:
        return raw; // valore presente nel DB ma non gestito dall'app
    }
  }

  String get sessoLabel => labelForSesso(sesso);

  /// Età in anni compiuti, null se la data di nascita manca.
  int? get age {
    final b = birth;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years < 0 ? null : years;
  }

  double get bmi {
    final heightM = altezza / 100;
    if (heightM <= 0) return 0;
    return peso / (heightM * heightM);
  }

  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Sottopeso';
    if (b < 25) return 'Normale';
    if (b < 30) return 'Sovrappeso';
    return 'Obesità';
  }
}
