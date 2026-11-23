import 'package:flutter_test/flutter_test.dart';
import 'package:vitality_assist/models/therapy_item.dart';

void main() {
  group('TherapyItem frequency parsing & formatting', () {
    test('parses all 7 Italian weekly frequencies including accented weekdays', () {
      for (final entry in TherapyItem.weekdayFullLabels.entries) {
        final formatted = TherapyItem.formatFrequency({entry.key});
        expect(formatted, 'Settimanale (${entry.value})');

        final item = TherapyItem(
          id: '1',
          name: 'Semaglutide',
          time: '09:00',
          frequency: formatted,
        );
        expect(item.isDaily, isFalse, reason: 'Failed for $formatted');
        expect(item.scheduledWeekdays, {entry.key}, reason: 'Failed for $formatted');
        expect(item.frequencySummary, 'Ogni ${entry.value}');
      }
    });

    test('parses custom multi-day frequencies and normalizes 7 days to Giornaliera', () {
      final customStr = TherapyItem.formatFrequency({
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      });
      expect(customStr, 'Giorni specifici (Lun, Mer, Ven)');

      final item = TherapyItem(
        id: '2',
        name: 'Vitamina D',
        time: '13:00',
        frequency: customStr,
      );
      expect(item.isDaily, isFalse);
      expect(item.scheduledWeekdays, {DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(item.isScheduledForDate(DateTime(2026, 11, 23)), isTrue); // Lunedì
      expect(item.isScheduledForDate(DateTime(2026, 11, 24)), isFalse); // Martedì
      expect(item.isScheduledForDate(DateTime(2026, 11, 25)), isTrue); // Mercoledì

      expect(TherapyItem.formatFrequency(TherapyItem.allWeekdays), 'Giornaliera');
      expect(TherapyItem.parseWeekdays('Giornaliera'), TherapyItem.allWeekdays);
    });
  });

  group('TherapyItem 30-minute early intake window', () {
    final item = TherapyItem(id: '10', name: 'Metformina', time: '20:00');
    final midnightItem = TherapyItem(id: '11', name: 'Farmaco Notte', time: '00:15');
    final noTimeItem = TherapyItem(id: '12', name: 'Senza Ora', time: '--:--');

    test('blocks intake more than 30 minutes before scheduled time today', () {
      final now = DateTime(2026, 11, 20, 19, 29);
      expect(item.canMarkTakenAt(now, now: now), isFalse);
      expect(item.earliestIntakeLabel(now), '19:30');
      expect(item.earlyIntakeBlockReason(now, now: now), contains('19:30'));
    });

    test('allows intake exactly 30 minutes before scheduled time and after', () {
      final atOpen = DateTime(2026, 11, 20, 19, 30);
      expect(item.canMarkTakenAt(atOpen, now: atOpen), isTrue);
      expect(item.earlyIntakeBlockReason(atOpen, now: atOpen), isNull);

      final after = DateTime(2026, 11, 20, 20, 45);
      expect(item.canMarkTakenAt(after, now: after), isTrue);
    });

    test('allows retroactive past-day intake, blocks future-day intake, clamps midnight', () {
      final now = DateTime(2026, 11, 20, 10, 0);
      final yesterdayEvening = DateTime(2026, 11, 19, 20, 0);
      final tomorrow = DateTime(2026, 11, 21, 20, 0);
      expect(item.canMarkTakenAt(yesterdayEvening, now: now), isTrue);
      expect(item.canMarkTakenAt(tomorrow, now: now), isFalse);

      final justAfterMidnight = DateTime(2026, 11, 20, 0, 1);
      expect(midnightItem.earliestIntakeLabel(justAfterMidnight), '00:00');
      expect(midnightItem.canMarkTakenAt(justAfterMidnight, now: justAfterMidnight), isTrue);
      expect(noTimeItem.canMarkTakenAt(now, now: now), isTrue);
    });
  });
}
