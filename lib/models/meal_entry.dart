enum MealType {
  colazione,
  spuntinoMattina,
  pranzo,
  spuntinoPomeriggio,
  cena,
  fuoriPasto,
}

extension MealTypeLabel on MealType {
  String get label {
    switch (this) {
      case MealType.colazione:
        return 'Colazione';
      case MealType.spuntinoMattina:
        return 'Spuntino mattina';
      case MealType.pranzo:
        return 'Pranzo';
      case MealType.spuntinoPomeriggio:
        return 'Spuntino pomeriggio';
      case MealType.cena:
        return 'Cena';
      case MealType.fuoriPasto:
        return 'Fuori pasto';
    }
  }

  /// Valore inviato alla colonna `meal_type` (`public.meal_enum` su Supabase).
  String get dbValue {
    switch (this) {
      case MealType.colazione:
        return 'COLAZIONE';
      case MealType.spuntinoMattina:
        return 'SPUNTINO_MATTINA';
      case MealType.pranzo:
        return 'PRANZO';
      case MealType.spuntinoPomeriggio:
        return 'SPUNTINO_POMERIGGIO';
      case MealType.cena:
        return 'CENA';
      case MealType.fuoriPasto:
        return 'FUORI_PASTO';
    }
  }

  /// Orario di riferimento usato per ordinare `meal_at` quando l'utente
  /// non specifica un orario personalizzato.
  ({int hour, int minute}) get defaultTime {
    switch (this) {
      case MealType.colazione:
        return (hour: 8, minute: 0);
      case MealType.spuntinoMattina:
        return (hour: 10, minute: 30);
      case MealType.pranzo:
        return (hour: 13, minute: 0);
      case MealType.spuntinoPomeriggio:
        return (hour: 16, minute: 30);
      case MealType.cena:
        return (hour: 20, minute: 0);
      case MealType.fuoriPasto:
        return (hour: 17, minute: 0);
    }
  }

  /// Converte il valore letto da Supabase (`meal_enum`), gestendo anche
  /// eventuali righe storiche salvate con `'SPUNTINO'`.
  static MealType fromDb(String raw, DateTime date) {
    switch (raw.trim().toUpperCase()) {
      case 'COLAZIONE':
        return MealType.colazione;
      case 'SPUNTINO_MATTINA':
        return MealType.spuntinoMattina;
      case 'PRANZO':
        return MealType.pranzo;
      case 'SPUNTINO_POMERIGGIO':
        return MealType.spuntinoPomeriggio;
      case 'CENA':
        return MealType.cena;
      case 'FUORI_PASTO':
        return MealType.fuoriPasto;
      case 'SPUNTINO':
        return date.hour < 14 ? MealType.spuntinoMattina : MealType.spuntinoPomeriggio;
      default:
        return MealType.fuoriPasto;
    }
  }
}

class MealEntry {
  /// Id della riga su Supabase (meals.id). Null per voci non salvate.
  final String? id;
  final DateTime date;
  final MealType type;
  final String description;
  final int calories;
  final int? carbsGrams;
  final bool isEstimated;

  MealEntry({
    this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.calories,
    this.carbsGrams,
    this.isEstimated = false,
  });

  /// True se per questo pasto l'utente ha specificato un orario esplicito
  /// (convenzione: `second == 1` oppure tipo `fuoriPasto` oppure orario
  /// diverso da quello di default del tipo di pasto).
  bool get hasExplicitTime {
    if (type == MealType.fuoriPasto) return true;
    if (date.second == 1) return true;
    final def = type.defaultTime;
    return date.hour != def.hour || date.minute != def.minute;
  }
}
