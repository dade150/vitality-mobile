class RecognizedFoodItem {
  final String? foodCode;
  final String name;
  final double quantityG;
  final int calories;
  final double carbsGrams;
  final String source;

  const RecognizedFoodItem({
    this.foodCode,
    required this.name,
    required this.quantityG,
    required this.calories,
    required this.carbsGrams,
    required this.source,
  });

  bool get isCrea => source == 'CREA';

  factory RecognizedFoodItem.fromJson(Map<String, dynamic> json) {
    return RecognizedFoodItem(
      foodCode: json['food_code'] as String?,
      name: (json['name'] as String?)?.trim() ?? '',
      quantityG: (json['quantity_g'] as num?)?.toDouble() ?? 0.0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      carbsGrams: (json['carbs_grams'] as num?)?.toDouble() ?? 0.0,
      source: (json['source'] as String?) ?? 'CREA',
    );
  }
}

class MealEstimateResponse {
  final int totalCalories;
  final int totalCarbsGrams;
  final String confidence;
  final List<RecognizedFoodItem> items;
  final String? notes;

  const MealEstimateResponse({
    required this.totalCalories,
    required this.totalCarbsGrams,
    required this.confidence,
    required this.items,
    this.notes,
  });

  bool get hasCreaItems => items.any((i) => i.isCrea);

  factory MealEstimateResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return MealEstimateResponse(
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      totalCarbsGrams: (json['total_carbs_grams'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as String?) ?? 'MEDIUM',
      items: rawItems
          .map((item) => RecognizedFoodItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );
  }
}
