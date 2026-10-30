import 'dart:convert';

import '../models/meal_entry.dart';
import '../models/nutrition_estimate.dart';
import 'api_services.dart';

class NutritionService {
  static const _estimateTimeout = Duration(seconds: 20);

  /// Invoca POST /api/nutrition/estimate-meal sul backend FastAPI.
  Future<MealEstimateResponse> estimateMeal({
    required String description,
    required MealType mealType,
  }) async {
    final response = await ApiService.post(
      '/api/nutrition/estimate-meal',
      jsonEncode({
        'description': description.trim(),
        'meal_type': mealType.dbValue,
      }),
      timeout: _estimateTimeout,
    );
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return MealEstimateResponse.fromJson(json);
  }
}
