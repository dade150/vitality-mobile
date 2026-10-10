import 'package:flutter/material.dart';

/// I tre profili in cui sono raggruppati i parametri nella schermata.
enum ClinicalProfile {
  glycemic('Controllo glicemico', 'Come è andata la glicemia negli ultimi mesi',
      Icons.bloodtype_outlined),
  renal('Funzionalità renale', 'Come stanno lavorando i reni', Icons.water_drop_outlined),
  lipid('Profilo lipidico', 'Colesterolo e grassi nel sangue', Icons.monitor_heart_outlined);

  const ClinicalProfile(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Unica fonte di verità per ogni parametro: etichetta, unità, limiti di
/// validazione, decimali, profilo e codice nel database. UI, validazione
/// e service leggono tutti da qui, così non possono divergere.
///
/// I limiti (min/max) servono solo a intercettare errori di battitura:
/// NON sono intervalli clinici di riferimento. Vanno tenuti allineati
/// al CHECK `diabetes_data_clinical_check` (supabase/clinical_parameters.sql).
/// `dbCode` = etichetta del valore in `metric_enum`.
enum ClinicalParameterType {
  hba1c(
    dbCode: 'HBA1C',
    label: 'HbA1c',
    description: 'Emoglobina glicata: media della glicemia degli ultimi 2-3 mesi',
    unit: '%',
    min: 3,
    max: 20,
    decimals: 1,
    icon: Icons.bloodtype_outlined,
    profile: ClinicalProfile.glycemic,
  ),
  egfr(
    dbCode: 'EGFR',
    label: 'eGFR',
    description: 'Quanto bene i reni filtrano il sangue',
    unit: 'mL/min',
    min: 1,
    max: 200,
    decimals: 0,
    icon: Icons.filter_alt_outlined,
    profile: ClinicalProfile.renal,
  ),
  uacr(
    dbCode: 'UACR',
    label: 'UACR',
    description: 'Quantità di albumina (una proteina) persa con le urine',
    unit: 'mg/g',
    min: 0,
    max: 10000,
    decimals: 1,
    icon: Icons.science_outlined,
    profile: ClinicalProfile.renal,
  ),
  totalCholesterol(
    dbCode: 'COLESTEROLO_TOTALE',
    label: 'Colesterolo totale',
    description: 'Tutto il colesterolo presente nel sangue',
    unit: 'mg/dL',
    min: 50,
    max: 600,
    decimals: 0,
    icon: Icons.opacity_outlined,
    profile: ClinicalProfile.lipid,
  ),
  hdl(
    dbCode: 'HDL',
    label: 'Colesterolo HDL',
    description: 'Il colesterolo "buono"',
    unit: 'mg/dL',
    min: 5,
    max: 200,
    decimals: 0,
    icon: Icons.thumb_up_alt_outlined,
    profile: ClinicalProfile.lipid,
  ),
  ldl(
    dbCode: 'LDL',
    label: 'Colesterolo LDL',
    description: 'Il colesterolo "cattivo"',
    unit: 'mg/dL',
    min: 10,
    max: 500,
    decimals: 0,
    icon: Icons.thumb_down_alt_outlined,
    profile: ClinicalProfile.lipid,
  ),
  triglycerides(
    dbCode: 'TRIGLICERIDI',
    label: 'Trigliceridi',
    description: 'I grassi presenti nel sangue',
    unit: 'mg/dL',
    min: 10,
    max: 5000,
    decimals: 0,
    icon: Icons.water_outlined,
    profile: ClinicalProfile.lipid,
  );

  const ClinicalParameterType({
    required this.dbCode,
    required this.label,
    required this.description,
    required this.unit,
    required this.min,
    required this.max,
    required this.decimals,
    required this.icon,
    required this.profile,
  });

  final String dbCode;
  final String label;
  final String description;
  final String unit;
  final double min;
  final double max;
  final int decimals;
  final IconData icon;
  final ClinicalProfile profile;

  /// Data più lontana accettata per un esame.
  static final DateTime earliestDate = DateTime(1990);

  bool get allowsDecimals => decimals > 0;

  bool isInRange(double v) => !v.isNaN && v >= min && v <= max;

  /// Arrotonda ai decimali previsti (evita 6.800000000001).
  double round(double v) => double.parse(v.toStringAsFixed(decimals));

  /// Formato italiano: "6,8".
  String format(double v) => v.toStringAsFixed(decimals).replaceAll('.', ',');

  /// Accetta sia la virgola sia il punto; null se non è un numero.
  double? tryParse(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    return (v == null || v.isNaN || v.isInfinite) ? null : v;
  }

  static ClinicalParameterType? fromDb(String? code) {
    for (final t in values) {
      if (t.dbCode == code) return t;
    }
    return null;
  }
}

/// Un valore misurato (riga di `diabetes_data`). [measuredOn] è la data
/// dell'esame scelta dall'utente (solo giorno, da `measured_at`): NON il
/// momento in cui viene inserito (quello è `created_at`).
class ClinicalReading {
  final String id;
  final ClinicalParameterType type;
  final double value;
  final DateTime measuredOn;

  const ClinicalReading({
    required this.id,
    required this.type,
    required this.value,
    required this.measuredOn,
  });
}