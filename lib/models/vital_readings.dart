class GlucoseReading {
  /// Id della riga su Supabase (diabetes_data.id). Null per letture non salvate.
  final String? id;
  final DateTime time;
  final double value; // mg/dL

  GlucoseReading({this.id, required this.time, required this.value});
}

class BloodPressureReading {
  final String? id;
  final DateTime time;
  final int systolic;
  final int diastolic;

  BloodPressureReading({
    this.id,
    required this.time,
    required this.systolic,
    required this.diastolic,
  });
}