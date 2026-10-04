class ActivityEntry {
  /// Id della riga su Supabase (physical_activities.id).
  final String? id;
  final DateTime date;
  final String type;
  final int minutes;
  final int steps;

  ActivityEntry({
    this.id,
    required this.date,
    required this.type,
    required this.minutes,
    this.steps = 0,
  });
}