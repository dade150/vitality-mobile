import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clinical_parameter.dart';
import '../models/meal_entry.dart';
import '../models/proposed_entry.dart';
import 'clinical_service.dart';
import 'error_handler.dart';
import 'health_service.dart';
import 'profile_service.dart';
import 'supabase_client.dart';

class ProposalService {
  ProposalService([SupabaseClient? client]) : _db = client ?? supabase;

  final SupabaseClient _db;

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  static DateTime _parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw != null) {
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.now();
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim());
  }

  static double? _parseDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().trim().replaceAll(',', '.'));
  }

  /// Salva su Supabase una proposta confermata o modificata dall'utente
  Future<void> saveProposal(TargetTable table, Map<String, dynamic> data) async {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw const AppFailure('Sessione non valida. Accedi di nuovo.', cause: 'ProposalService.save');
    }

    switch (table) {
      case TargetTable.diabetesData:
        await _saveDiabetesData(data);
        break;
      case TargetTable.meals:
        await _saveMeal(data);
        break;
      case TargetTable.physicalActivities:
        await _saveActivity(data);
        break;
      case TargetTable.appointments:
        await _saveAppointment(data);
        break;
      case TargetTable.therapyLogs:
        await _saveTherapyLog(data);
        break;
      case TargetTable.therapies:
        await _saveTherapy(data);
        break;
      case TargetTable.profile:
        await _saveProfile(user.id, data);
        break;
    }
  }

  // ------------------------------------------------------------- Diabetes Data
  Future<void> _saveDiabetesData(Map<String, dynamic> data) async {
    final rawType = (data['metric_type'] ?? data['type'] ?? 'GLICEMIA').toString().toUpperCase().trim();
    final rawVal = data['metric_value'] ?? data['value'];
    final when = _parseDate(data['measured_at'] ?? data['date']);

    if (rawVal == null || rawVal.toString().trim().isEmpty) {
      throw ArgumentError('Valore misurazione obbligatorio');
    }

    if (rawType == 'GLICEMIA') {
      final numVal = _parseDouble(rawVal);
      if (numVal == null) throw ArgumentError('Valore glicemia non valido');
      final healthService = HealthService(_db);
      await healthService.insertGlucose(numVal, when);
      return;
    }

    if (rawType == 'PRESSIONE') {
      final strVal = rawVal.toString().trim();
      int? sys;
      int? dia;

      if (strVal.contains('/')) {
        final parts = strVal.split('/');
        sys = _parseInt(parts[0]);
        dia = parts.length > 1 ? _parseInt(parts[1]) : null;
      } else {
        sys = _parseInt(data['systolic'] ?? rawVal);
        dia = _parseInt(data['diastolic']);
      }

      if (sys == null || dia == null) {
        throw ArgumentError('Valori di pressione sistolica e diastolica non validi (es. 120/80)');
      }

      final healthService = HealthService(_db);
      await healthService.insertPressure(sys, dia, when);
      return;
    }

    // Parametro clinico (HbA1c, eGFR, UACR, Colesterolo, Trigliceridi...)
    final clinicalType = ClinicalParameterType.fromDb(rawType);
    if (clinicalType != null) {
      final numVal = _parseDouble(rawVal);
      if (numVal == null) throw ArgumentError('Valore clinico non valido');
      final clinicalService = ClinicalService(_db);
      await clinicalService.insert(clinicalType, numVal, when);
      return;
    }

    // Inserimento diretto generico in diabetes_data
    await _db.from('diabetes_data').insert({
      'metric_type': rawType,
      'metric_value': rawVal.toString().trim(),
      'measured_at': _iso(when),
    });
  }

  // --------------------------------------------------------------------- Meals
  Future<void> _saveMeal(Map<String, dynamic> data) async {
    final desc = (data['description'] ?? '').toString().trim();
    if (desc.isEmpty) throw ArgumentError('La descrizione del pasto è obbligatoria');

    final calories = _parseInt(data['calories']) ?? 0;
    final carbsGrams = _parseInt(data['carbs_grams']);
    final isEstimated = data['is_estimated'] != false;
    final when = _parseDate(data['meal_at'] ?? data['date']);

    final rawMealType = (data['meal_type'] ?? '').toString().trim();
    final MealType mealType;
    if (rawMealType.isEmpty) {
      if (when.hour >= 5 && when.hour < 11) {
        mealType = MealType.colazione;
      } else if (when.hour >= 11 && when.hour < 15) {
        mealType = MealType.pranzo;
      } else if (when.hour >= 15 && when.hour < 19) {
        mealType = MealType.spuntinoPomeriggio;
      } else if (when.hour >= 19 && when.hour < 23) {
        mealType = MealType.cena;
      } else {
        mealType = MealType.fuoriPasto;
      }
    } else {
      mealType = MealTypeLabel.fromDb(rawMealType, when);
    }

    await _db.from('meals').insert({
      'meal_type': mealType.dbValue,
      'description': desc,
      'calories': calories,
      if (carbsGrams != null) 'carbs_grams': carbsGrams,
      'is_estimated': isEstimated,
      'meal_at': _iso(when),
    });
  }

  // ------------------------------------------------------- Physical Activities
  Future<void> _saveActivity(Map<String, dynamic> data) async {
    final rawType = (data['activity_type'] ?? data['type'] ?? 'CAMMINATA')
        .toString()
        .trim()
        .toUpperCase();
    final duration = _parseInt(data['duration_minutes'] ?? data['minutes']) ?? 0;
    if (duration <= 0) throw ArgumentError('La durata deve essere di almeno 1 minuto');

    final steps = _parseInt(data['steps']);
    final intensity = (data['intensity'] ?? 'MODERATA').toString().trim().toUpperCase();
    final notes = data['notes']?.toString().trim();
    final when = _parseDate(data['activity_at'] ?? data['date']);

    await _db.from('physical_activities').insert({
      'activity_type': rawType,
      'duration_minutes': duration,
      'intensity': intensity.isEmpty ? 'MODERATA' : intensity,
      if (steps != null && steps > 0) 'steps': steps,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'activity_at': _iso(when),
    });
  }

  // -------------------------------------------------------------- Appointments
  Future<void> _saveAppointment(Map<String, dynamic> data) async {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw const AppFailure('Sessione non valida. Accedi di nuovo.', cause: 'ProposalService.save');
    }
    final title = (data['title'] ?? data['visit_type'] ?? '').toString().trim();
    if (title.isEmpty) throw ArgumentError('Il tipo o titolo della visita è obbligatorio');

    final doctor = (data['doctor_name'] ?? '').toString().trim();
    final location = (data['location'] ?? '').toString().trim();
    final notes = (data['notes'] ?? '').toString().trim();
    final when = _parseDate(data['appointment_at'] ?? data['date']);

    final payload = <String, dynamic>{
      'user_id': user.id,
      'title': title,
      if (doctor.isNotEmpty) 'doctor_name': doctor,
      'appointment_at': _iso(when),
      if (notes.isNotEmpty) 'notes': notes,
    };
    if (location.isNotEmpty) payload['location'] = location;

    try {
      await _db.from('appointments').insert(payload);
    } on PostgrestException catch (e) {
      if (e.message.contains('location') || e.code == 'PGRST204' || e.code == '42703') {
        payload.remove('location');
        if (!payload.containsKey('doctor_name') && location.isNotEmpty) {
          payload['doctor_name'] = location;
        }
        await _db.from('appointments').insert(payload);
      } else {
        rethrow;
      }
    }
  }

  // -------------------------------------------------------------- Therapy Logs
  Future<void> _saveTherapyLog(Map<String, dynamic> data) async {
    final therapyId = (data['therapy_id'] ?? '').toString().trim();
    if (therapyId.isEmpty || therapyId == 'null') {
      throw ArgumentError('Identificativo terapia mancante');
    }

    final when = _parseDate(data['taken_at'] ?? data['date']);
    final healthService = HealthService(_db);
    await healthService.insertTherapyLog(therapyId, when);
  }

  // ----------------------------------------------------------------- Therapies
  Future<void> _saveTherapy(Map<String, dynamic> data) async {
    final drugName = (data['drug_name'] ?? data['name'] ?? '').toString().trim();
    if (drugName.isEmpty) throw ArgumentError('Il nome del farmaco è obbligatorio');

    final therapyType = (data['therapy_type'] ?? 'ALTRO').toString().trim().toUpperCase();
    final dosage = (data['dosage'] ?? '-').toString().trim();
    final frequency = (data['frequency'] ?? 'Giornaliera').toString().trim();
    final scheduledTime = HealthService.normalizeTime((data['scheduled_time'] ?? data['time'] ?? '08:00').toString()) ?? '08:00';
    final notes = data['notes']?.toString().trim();

    await _db.from('therapies').insert({
      'therapy_type': therapyType.isEmpty ? 'ALTRO' : therapyType,
      'drug_name': drugName,
      'dosage': dosage.isEmpty ? '-' : dosage,
      'frequency': frequency.isEmpty ? 'Giornaliera' : frequency,
      'scheduled_time': scheduledTime,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'is_active': true,
    });
  }

  // ------------------------------------------------------------------- Profile
  Future<void> _saveProfile(String userId, Map<String, dynamic> data) async {
    final peso = _parseDouble(data['peso']);
    final altezza = _parseInt(data['altezza']);
    final sesso = data['sesso']?.toString().trim().toLowerCase();
    final noteAnamnestiche = data['note_anamnestiche']?.toString().trim();

    if (peso == null && altezza == null && (sesso == null || sesso.isEmpty) && (noteAnamnestiche == null || noteAnamnestiche.isEmpty)) {
      throw ArgumentError('Nessun dato del profilo specificato');
    }

    final profileService = ProfileService(_db);
    await profileService.updateDatiFisici(
      userId,
      peso: peso,
      altezza: altezza,
      sesso: sesso,
      noteAnamnestiche: noteAnamnestiche,
    );
  }
}
