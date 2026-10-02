class ActivityEntry {
  final DateTime date;
  final String type;
  final int minutes;
  final int steps;

  ActivityEntry({
    required this.date,
    required this.type,
    required this.minutes,
    this.steps = 0,
  });
}
