import 'package:intl/intl.dart';

/// Helper di formattazione data in italiano.
/// Richiede che `initializeDateFormatting('it_IT', null)` sia stato chiamato
/// in main() prima di utilizzare questi metodi (vedi lib/main.dart).
class AppDateFormat {
  AppDateFormat._();

  static final DateFormat _dayMonth = DateFormat('d MMMM', 'it_IT');
  static final DateFormat _dayMonthYear = DateFormat('d MMMM yyyy', 'it_IT');
  static final DateFormat _weekdayShort = DateFormat('E', 'it_IT');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'it_IT');
  static final DateFormat _daySmall = DateFormat('d', 'it_IT');
  static final DateFormat _monthShort = DateFormat('MMM', 'it_IT');

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String dayMonth(DateTime date) => _dayMonth.format(date);

  /// "12 maggio 2025"
  static String dayMonthYear(DateTime date) => _dayMonthYear.format(date);

  static String weekdayShort(DateTime date) =>
      _capitalize(_weekdayShort.format(date));

  static String monthYear(DateTime date) =>
      _capitalize(_monthYear.format(date));

  static String daySmall(DateTime date) => _daySmall.format(date);

  static String monthShort(DateTime date) =>
      _capitalize(_monthShort.format(date).replaceAll('.', ''));
}