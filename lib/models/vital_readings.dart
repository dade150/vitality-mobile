class GlucoseReading {
  final DateTime time;
  final double value; // mg/dL

  GlucoseReading({required this.time, required this.value});
}

class BloodPressureReading {
  final DateTime time;
  final int systolic;
  final int diastolic;

  BloodPressureReading({
    required this.time,
    required this.systolic,
    required this.diastolic,
  });
}
