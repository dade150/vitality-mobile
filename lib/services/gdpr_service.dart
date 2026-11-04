import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'api_services.dart';
import 'supabase_client.dart';

/// Servizio per l'esercizio dei diritti GDPR dell'interessato:
/// - Art. 20 GDPR: Diritto alla portabilità dei dati (esportazione archivio JSON strutturato).
/// - Art. 17 GDPR: Diritto all'oblio / cancellazione definitiva di account e dati sanitari.
class GdprService {
  static const _exportTimeout = Duration(seconds: 30);

  /// Scarica l'archivio JSON completo dei dati personali e sanitari da `GET /api/me/export`.
  /// In caso di fallback (es. backend non raggiungibile), costruisce il pacchetto direttamente
  /// dalle tabelle Supabase isolate tramite RLS (`auth.uid()`).
  static Future<Uint8List> downloadPersonalDataJson() async {
    try {
      final response = await ApiService.get('/api/me/export', timeout: _exportTimeout);
      if (response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Fallback diretto tramite Supabase PostgREST sotto RLS auth.uid()
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sessione non valida. Effettua nuovamente l\'accesso.');
    }

    Future<List<dynamic>> safeTable(String table, [String cols = '*']) async {
      try {
        final rows = await supabase.from(table).select(cols);
        return List<dynamic>.from(rows);
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([
      safeTable('user'),
      safeTable('profile', 'id, peso, altezza, sesso, note_anamnestiche, created_at'),
      safeTable('user_settings'),
      safeTable('diabetes_data', 'id, metric_type, metric_value, measured_at, source_report_id, created_at'),
      safeTable('meals', 'id, meal_type, description, carbs_grams, calories, is_estimated, meal_at, created_at'),
      safeTable('physical_activities', 'id, activity_type, duration_minutes, intensity, steps, notes, activity_at, created_at'),
      safeTable('therapies', 'id, therapy_type, drug_name, dosage, frequency, scheduled_time, notes, is_active, created_at'),
      safeTable('therapy_logs', 'id, therapy_id, taken_at, status, created_at'),
      safeTable('appointments', 'id, title, doctor_name, appointment_at, notes, created_at'),
      safeTable('patient_reports', 'id, source_name, source_path, report_type, clean_summary, content, extracted_params, report_at, created_at'),
      safeTable('chat_session', 'id, title, created_at'),
      safeTable('chat_message', 'id, session_id, role, content, created_at'),
      safeTable('app_logs', 'id, level, message, route, created_at'),
    ]);

    final bundle = {
      'metadata': {
        'application': 'diaLog2',
        'gdpr_reference': 'Art. 20 Regolamento (UE) 2016/679 (Diritto alla portabilità dei dati)',
        'schema_version': '1.1',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user_id': user.id,
        'email': user.email,
      },
      'account_and_consents': results[0].isNotEmpty ? results[0].first : {'id': user.id, 'email': user.email},
      'clinical_profile': results[1].isNotEmpty ? results[1].first : null,
      'preferences': results[2].isNotEmpty ? results[2].first : null,
      'health_diary': {
        'diabetes_and_clinical_measurements': results[3],
        'meals': results[4],
        'physical_activities': results[5],
        'therapies': results[6],
        'therapy_adherence_logs': results[7],
        'medical_appointments': results[8],
        'medical_reports': results[9],
      },
      'conversational_history': {
        'sessions': results[10],
        'messages': results[11],
      },
      'application_logs': results[12],
    };

    final prettyJson = const JsonEncoder.withIndent('  ').convert(bundle);
    return Uint8List.fromList(utf8.encode(prettyJson));
  }

  /// Scarica l'archivio JSON e apre il selettore di salvataggio file sul dispositivo.
  /// Restituisce `true` se il file è stato salvato con successo.
  static Future<bool> exportAndSaveJson(BuildContext context) async {
    final jsonBytes = await downloadPersonalDataJson();
    if (!context.mounted) return false;
    return saveJsonBytesToFile(context, jsonBytes);
  }

  /// Salva i byte JSON già scaricati aprendo il selettore di salvataggio del sistema operativo.
  static Future<bool> saveJsonBytesToFile(BuildContext context, Uint8List jsonBytes) async {
    final now = DateTime.now();
    final dateTag =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final defaultFileName = 'diaLog2_Dati_GDPR_$dateTag.json';

    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salva Archivio Dati Sanitari (JSON - GDPR Art. 20)',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: jsonBytes,
    );

    if (outputPath == null) {
      return false;
    }

    if (outputPath.isNotEmpty) {
      try {
        final file = File(outputPath);
        await file.writeAsBytes(jsonBytes);
      } catch (_) {
        // Su Android/iOS saveFile con bytes scrive già direttamente il contenuto
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Archivio dati JSON (GDPR Art. 20) salvato con successo.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 4),
        ),
      );
    }
    return true;
  }

  /// Elimina definitivamente l'account e tutti i dati sanitari (GDPR Art. 17).
  static Future<void> deleteAccountAndAllData() async {
    // 1. Pulizia preventiva dei file nello Storage privato dell'utente (B1)
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final files = await supabase.storage.from('patient-reports').list(path: userId);
        if (files.isNotEmpty) {
          final paths = files.map((f) => '$userId/${f.name}').toList();
          await supabase.storage.from('patient-reports').remove(paths);
        }
      }
    } catch (e) {
      debugPrint('[GdprService] pulizia storage pre-eliminazione ignorata: $e');
    }

    bool backendDeleted = false;
    try {
      await ApiService.delete('/api/me', timeout: _exportTimeout);
      backendDeleted = true;
    } catch (_) {
      backendDeleted = false;
    }

    // 2. Se il backend non è raggiungibile o ha restituito errore (es. fallback senza cancellazione auth),
    // invoca la RPC Supabase `delete_own_account` direttamente con il token autenticato
    if (!backendDeleted) {
      await supabase.rpc('delete_own_account');
    }
  }
}
