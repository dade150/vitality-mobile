class TherapyItem {
  /// Anticipo massimo consentito rispetto all'orario previsto per segnare una dose come assunta.
  static const Duration earlyWindow = Duration(minutes: 30);

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
