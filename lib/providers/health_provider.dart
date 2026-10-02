import 'package:flutter/material.dart';
import '../models/therapy_item.dart';
import '../models/vital_readings.dart';
import '../models/activity_entry.dart';
import '../models/meal_entry.dart';

/// Stato "salute" dell'app preparato per l'integrazione con Supabase.
class HealthProvider extends ChangeNotifier {
  // Liste vuote, pronte per essere popolate dal DB
  final List<TherapyItem> therapyItems = [];
  final List<GlucoseReading> glucoseReadings = [];
  final List<BloodPressureReading> pressureReadings = [];
  final List<ActivityEntry> activityEntries = [];
  final List<MealEntry> mealEntries = [];

  GlucoseReading? get lastGlucose => 
      glucoseReadings.isNotEmpty ? glucoseReadings.last : null;

  BloodPressureReading? get lastPressure => 
      pressureReadings.isNotEmpty ? pressureReadings.last : null;

  int get todaySteps {
    final now = DateTime.now();
    return activityEntries
        .where((a) =>
            a.date.year == now.year && a.date.month == now.month && a.date.day == now.day)
        .fold<int>(0, (sum, a) => sum + a.steps);
  }

  int get todayCalories {
    final now = DateTime.now();
    return mealEntries
        .where((m) =>
            m.date.year == now.year && m.date.month == now.month && m.date.day == now.day)
        .fold<int>(0, (sum, m) => sum + m.calories);
  }

  void toggleTherapyTaken(String id) {
    final index = therapyItems.indexWhere((t) => t.id == id);
    if (index == -1) return;
    therapyItems[index].taken = !therapyItems[index].taken;
    notifyListeners();
  }

  void addTherapyItem(TherapyItem item) {
    therapyItems.add(item);
    notifyListeners();
  }

  void updateTherapyItem(String id, {String? name, String? time}) {
    final index = therapyItems.indexWhere((t) => t.id == id);
    if (index == -1) return;
    if (name != null && name.trim().isNotEmpty) therapyItems[index].name = name;
    if (time != null && time.trim().isNotEmpty) therapyItems[index].time = time;
    notifyListeners();
  }

  void removeTherapyItem(String id) {
    therapyItems.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void addGlucoseReading(double value) {
    glucoseReadings.add(GlucoseReading(time: DateTime.now(), value: value));
    notifyListeners();
  }

  void removeLastGlucose() {
    if (glucoseReadings.isNotEmpty) {
      glucoseReadings.removeLast();
      notifyListeners();
    }
  }

  void addPressureReading(int systolic, int diastolic) {
    pressureReadings.add(
      BloodPressureReading(time: DateTime.now(), systolic: systolic, diastolic: diastolic),
    );
    notifyListeners();
  }

  void removeLastPressure() {
    if (pressureReadings.isNotEmpty) {
      pressureReadings.removeLast();
      notifyListeners();
    }
  }

  void addActivity(ActivityEntry entry) {
    activityEntries.add(entry);
    notifyListeners();
  }

  void addMeal(MealEntry entry) {
    mealEntries.add(entry);
    notifyListeners();
  }
}