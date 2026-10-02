enum MealType { colazione, pranzo, cena, spuntino }

extension MealTypeLabel on MealType {
  String get label {
    switch (this) {
      case MealType.colazione:
        return 'Colazione';
      case MealType.pranzo:
        return 'Pranzo';
      case MealType.cena:
        return 'Cena';
      case MealType.spuntino:
        return 'Spuntino';
    }
  }
}

class MealEntry {
  final DateTime date;
  final MealType type;
  final String description;
  final int calories;
  final bool isEstimated;

  MealEntry({
    required this.date,
    required this.type,
    required this.description,
    required this.calories,
    this.isEstimated = false,
  });
}
