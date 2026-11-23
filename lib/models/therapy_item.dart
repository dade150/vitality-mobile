class TherapyItem {
  /// Anticipo massimo consentito rispetto all'orario previsto per segnare una dose come assunta.
  static const Duration earlyWindow = Duration(minutes: 30);

  static const String defaultFrequency = 'Giornaliera';

  static const Map<int, String> weekdayShortLabels = {
    DateTime.monday: 'Lun',
    DateTime.tuesday: 'Mar',
    DateTime.wednesday: 'Mer',
    DateTime.thursday: 'Gio',
    DateTime.friday: 'Ven',
    DateTime.saturday: 'Sab',
    DateTime.sunday: 'Dom',
  };

  static const Map<int, String> weekdayFullLabels = {
    DateTime.monday: 'Lunedì',
    DateTime.tuesday: 'Martedì',
    DateTime.wednesday: 'Mercoledì',
    DateTime.thursday: 'Giovedì',
    DateTime.friday: 'Venerdì',
    DateTime.saturday: 'Sabato',
    DateTime.sunday: 'Domenica',
  };

  static const Set<int> allWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };

  final String id;
  String name;
  String time; // es. "08:00"
  String frequency; // es. "Giornaliera", "Settimanale (Domenica)", "Giorni specifici (Lun, Mer, Ven)"
  bool taken;

  TherapyItem({
    required this.id,
    required this.name,
    required this.time,
    this.frequency = defaultFrequency,
    this.taken = false,
  });

  /// Estrae i giorni della settimana (`DateTime.monday..sunday`) da una stringa `frequency`.
  /// Se è giornaliera o non contiene giorni specifici, restituisce tutti e 7 i giorni.
  static Set<int> parseWeekdays(String? rawFrequency) {
    // Normalizza gli accenti (`ì` -> `i`) perché in Dart RegExp `\b` considera i caratteri
    // non-ASCII come `\W` e non farebbe match dopo `lunedì`/`martedì`/`mercoledì`/`giovedì`/`venerdì`.
    final norm = (rawFrequency ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i');
    if (norm.isEmpty ||
        norm.contains('giornalier') ||
        norm.contains('ogni giorno') ||
        norm.contains('tutti i giorni')) {
      return Set<int>.from(allWeekdays);
    }

    final found = <int>{};
    if (RegExp(r'\blun(?:edi)?\b').hasMatch(norm)) found.add(DateTime.monday);
    if (RegExp(r'\bmar(?:tedi)?\b').hasMatch(norm)) found.add(DateTime.tuesday);
    if (RegExp(r'\bmer(?:coledi)?\b').hasMatch(norm)) found.add(DateTime.wednesday);
    if (RegExp(r'\bgio(?:vedi)?\b').hasMatch(norm)) found.add(DateTime.thursday);
    if (RegExp(r'\bven(?:erdi)?\b').hasMatch(norm)) found.add(DateTime.friday);
    if (RegExp(r'\bsab(?:ato)?\b').hasMatch(norm)) found.add(DateTime.saturday);
    if (RegExp(r'\bdom(?:enica)?\b').hasMatch(norm)) found.add(DateTime.sunday);

    return found.isEmpty ? Set<int>.from(allWeekdays) : found;
  }

  /// Converte un insieme di giorni della settimana nella stringa leggibile salvata in `therapies.frequency`.
  static String formatFrequency(Set<int> weekdays) {
    final valid = weekdays.where((d) => d >= DateTime.monday && d <= DateTime.sunday).toList()
      ..sort();
    if (valid.isEmpty || valid.length == 7) {
      return defaultFrequency;
    }
    if (valid.length == 1) {
      return 'Settimanale (${weekdayFullLabels[valid.first]})';
    }
    final shortList = valid.map((d) => weekdayShortLabels[d]!).join(', ');
    return 'Giorni specifici ($shortList)';
  }

  /// Giorni della settimana in cui è prevista l'assunzione (`1=Lun .. 7=Dom`).
  Set<int> get scheduledWeekdays => parseWeekdays(frequency);

  /// True se la terapia è prevista tutti i giorni.
  bool get isDaily => scheduledWeekdays.length == 7;

  /// True se la terapia è prevista nel giorno [day].
  bool isScheduledForDate(DateTime day) => scheduledWeekdays.contains(day.weekday);

  /// Etichetta compatta leggibile per liste e card (es. `"Tutti i giorni"`, `"Ogni Domenica"`, `"Lun, Mer, Ven"`).
  String get frequencySummary {
    final days = scheduledWeekdays.toList()..sort();
    if (days.length == 7) return 'Tutti i giorni';
    if (days.length == 1) return 'Ogni ${weekdayFullLabels[days.first]}';
    return days.map((d) => weekdayShortLabels[d]!).join(', ');
  }

  /// Orario programmato nel giorno di [day], oppure `null` se `time` non è valido (`--:--`).
  DateTime? scheduledDateTimeFor(DateTime day) {
    final parts = time.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  /// Orario di apertura della finestra di registrazione per il giorno [day]
  /// (`scheduled - 30 min`, clampato alle `00:00` dello stesso giorno).
  DateTime? earliestIntakeFor(DateTime day) {
    final scheduled = scheduledDateTimeFor(day);
    if (scheduled == null) return null;
    final dayStart = DateTime(day.year, day.month, day.day);
    final earliest = scheduled.subtract(earlyWindow);
    return earliest.isBefore(dayStart) ? dayStart : earliest;
  }

  /// Stringa `HH:MM` dell'orario di apertura finestra per il giorno [day] (es. `"19:30"`).
  String? earliestIntakeLabel(DateTime day) {
    final earliest = earliestIntakeFor(day);
    if (earliest == null) return null;
    final hh = earliest.hour.toString().padLeft(2, '0');
    final mm = earliest.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// True se la dose può essere registrata come assunta all'istante [at] rispetto a [now].
  /// - Giorni passati: registrazione retroattiva sempre consentita.
  /// - Giorni futuri: sempre bloccata.
  /// - Oggi: consentita solo da 30 minuti prima dell'orario previsto (`scheduled - 30 min`) in poi
  ///   (sia rispetto all'ora attuale reale sia rispetto all'ora selezionata).
  bool canMarkTakenAt(DateTime at, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final todayStart = DateTime(refNow.year, refNow.month, refNow.day);
    final atDay = DateTime(at.year, at.month, at.day);
    if (atDay.isBefore(todayStart)) return true;
    if (atDay.isAfter(todayStart)) return false;

    final earliest = earliestIntakeFor(refNow);
    if (earliest == null) return true;
    return !refNow.isBefore(earliest) && !at.isBefore(earliest);
  }

  /// Messaggio chiaro per l'utente se [canMarkTakenAt] è `false`, altrimenti `null`.
  String? earlyIntakeBlockReason(DateTime at, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    if (canMarkTakenAt(at, now: refNow)) return null;

    final todayStart = DateTime(refNow.year, refNow.month, refNow.day);
    final atDay = DateTime(at.year, at.month, at.day);
    if (atDay.isAfter(todayStart)) {
      return 'Non puoi registrare come già assunta una terapia di una data futura.';
    }
    final openLabel = earliestIntakeLabel(refNow) ?? time;
    return 'Potrai registrare $name dalle $openLabel (30 minuti prima delle $time).';
  }
}
