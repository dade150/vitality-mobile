class TherapyItem {
  final String id;
  String name;
  String time; // es. "08:00"
  bool taken;

  TherapyItem({
    required this.id,
    required this.name,
    required this.time,
    this.taken = false,
  });
}
