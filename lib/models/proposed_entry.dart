import 'package:flutter/material.dart';

enum TargetTable {
  diabetesData('diabetes_data', 'Misurazione / Esame', Icons.monitor_heart_outlined),
  meals('meals', 'Pasto', Icons.restaurant_outlined),
  physicalActivities('physical_activities', 'Attività fisica', Icons.directions_walk_rounded),
  appointments('appointments', 'Visita / Appuntamento', Icons.event_available_outlined),
  therapyLogs('therapy_logs', 'Assunzione farmaco', Icons.medication_liquid_outlined),
  therapies('therapies', 'Piano terapeutico', Icons.medication_outlined),
  profile('profile', 'Profilo fisico', Icons.person_outline_rounded);

  const TargetTable(this.dbName, this.displayLabel, this.icon);
  final String dbName;
  final String displayLabel;
  final IconData icon;

  static TargetTable? fromString(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    for (final table in TargetTable.values) {
      if (table.dbName.toLowerCase() == normalized) return table;
    }
    return null;
  }
}

enum ProposalStatus {
  pending,
  saving,
  saved,
  dismissed,
}

class ProposedEntry {
  final String proposalId;
  final TargetTable targetTable;
  final String summaryTitle;
  final bool isComplete;
  final List<String> missingFields;
  final String? assistantNote;
  final Map<String, dynamic> data;
  ProposalStatus status;
  String? saveError;

  ProposedEntry({
    required this.proposalId,
    required this.targetTable,
    required this.summaryTitle,
    required this.isComplete,
    this.missingFields = const [],
    this.assistantNote,
    required this.data,
    this.status = ProposalStatus.pending,
    this.saveError,
  });

  static ProposedEntry? fromJson(Map<String, dynamic> json) {
    final rawTable = json['target_table']?.toString();
    final target = TargetTable.fromString(rawTable);
    if (target == null) return null;

    final proposalId = json['proposal_id']?.toString() ??
        'prop_${DateTime.now().microsecondsSinceEpoch}';
    final summaryTitle = json['summary_title']?.toString() ?? target.displayLabel;
    final isComplete = json['is_complete'] == true;
    final assistantNote = json['assistant_note']?.toString();

    final missing = <String>[];
    if (json['missing_fields'] is List) {
      for (final f in json['missing_fields'] as List) {
        if (f != null && f.toString().trim().isNotEmpty) {
          missing.add(f.toString().trim());
        }
      }
    }

    final rawData = json['data'];
    final data = <String, dynamic>{};
    if (rawData is Map) {
      rawData.forEach((key, value) {
        data[key.toString()] = value;
      });
    }

    return ProposedEntry(
      proposalId: proposalId,
      targetTable: target,
      summaryTitle: summaryTitle,
      isComplete: isComplete,
      missingFields: missing,
      assistantNote: assistantNote,
      data: data,
    );
  }

  ProposedEntry copyWith({
    String? proposalId,
    TargetTable? targetTable,
    String? summaryTitle,
    bool? isComplete,
    List<String>? missingFields,
    String? assistantNote,
    Map<String, dynamic>? data,
    ProposalStatus? status,
    String? saveError,
  }) {
    return ProposedEntry(
      proposalId: proposalId ?? this.proposalId,
      targetTable: targetTable ?? this.targetTable,
      summaryTitle: summaryTitle ?? this.summaryTitle,
      isComplete: isComplete ?? this.isComplete,
      missingFields: missingFields ?? this.missingFields,
      assistantNote: assistantNote ?? this.assistantNote,
      data: data ?? Map<String, dynamic>.from(this.data),
      status: status ?? this.status,
      saveError: saveError ?? this.saveError,
    );
  }

  /// Restituisce un'etichetta amichevole in italiano per i campi mancanti
  static String formatFieldName(String field) {
    switch (field.trim().toLowerCase()) {
      case 'metric_value':
      case 'value':
        return 'Valore';
      case 'metric_type':
        return 'Tipo misurazione';
      case 'measured_at':
      case 'activity_at':
      case 'meal_at':
      case 'taken_at':
        return 'Data e ora';
      case 'appointment_at':
        return 'Data e ora visita';
      case 'description':
        return 'Descrizione';
      case 'meal_type':
        return 'Tipo pasto';
      case 'calories':
        return 'Calorie';
      case 'carbs_grams':
        return 'Carboidrati (g)';
      case 'activity_type':
        return 'Tipo attività';
      case 'duration_minutes':
        return 'Durata (minuti)';
      case 'intensity':
        return 'Intensità';
      case 'steps':
        return 'Passi';
      case 'title':
        return 'Tipo visita / Titolo';
      case 'doctor_name':
        return 'Medico / Specialista';
      case 'drug_name':
        return 'Nome farmaco';
      case 'dosage':
        return 'Dosaggio';
      case 'frequency':
        return 'Frequenza';
      case 'scheduled_time':
        return 'Orario';
      case 'peso':
        return 'Peso (kg)';
      case 'altezza':
        return 'Altezza (cm)';
      case 'sesso':
        return 'Sesso';
      default:
        return field.replaceAll('_', ' ');
    }
  }
}
