class MedicalReport {
  final String id;
  final String title;
  final DateTime date;
  final String status;
  final Map<String, String> extractedParams;

  MedicalReport({
    required this.id,
    required this.title,
    required this.date,
    this.status = 'Completato',
    this.extractedParams = const {},
  });
}
