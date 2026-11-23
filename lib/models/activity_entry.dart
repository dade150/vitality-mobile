class ActivityEntry {
  /// Id della riga su Supabase (physical_activities.id).
  final String? id;
  final DateTime date;
  final String type;
  final int minutes;
  final String intensity;
  final int steps;

  bool get isWalking => type == 'Camminata';

  ActivityEntry({
    this.id,
    required this.date,
    required this.type,
    required this.minutes,
    this.intensity = 'Moderata',
    this.steps = 0,
  });
}