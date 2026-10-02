import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointments_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_card.dart';
import '../../utils/date_format.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appointments = context.watch<AppointmentsProvider>();
    final next = appointments.next;
    final upcoming = appointments.sorted.where((a) => a != next).take(4).toList();

    return AppScaffold(
      navIndex: 3,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text('Visite Mediche', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/appointments/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi Visita'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
                    Text(AppDateFormat.monthYear(_visibleMonth), style: theme.textTheme.titleMedium),
                    IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                _CalendarGrid(
                  visibleMonth: _visibleMonth,
                  markedDays: appointments.appointments.map((a) => a.date).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Prossimo Appuntamento', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (next == null)
            SectionCard(child: Text('Nessuna visita in programma.', style: theme.textTheme.bodyMedium))
          else
            Container(
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_isToday(next.date) ? 'OGGI' : AppDateFormat.dayMonth(next.date).toUpperCase()}, '
                    '${next.time.hour.toString().padLeft(2, '0')}:${next.time.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.labelLarge?.copyWith(color: cs.onPrimary.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 4),
                  Text(next.type, style: theme.textTheme.headlineSmall?.copyWith(color: cs.onPrimary)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/reports/add'),
                    icon: Icon(Icons.upload_file_rounded, color: cs.onPrimary),
                    label: Text('Carica Referto per Visita', style: TextStyle(color: cs.onPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.onPrimary.withValues(alpha: 0.6)),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text('Prossime Visite', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Text('Nessun\'altra visita in programma.', style: theme.textTheme.bodyMedium)
          else
            for (final appt in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Text(AppDateFormat.daySmall(appt.date), style: theme.textTheme.titleMedium),
                            Text(AppDateFormat.monthShort(appt.date), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appt.type, style: theme.textTheme.titleSmall),
                            Text(
                              '${appt.time.hour.toString().padLeft(2, '0')}:${appt.time.minute.toString().padLeft(2, '0')} · ${appt.location}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final List<DateTime> markedDays;

  const _CalendarGrid({required this.visibleMonth, required this.markedDays});

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final firstDayOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingEmpty = (firstDayOfMonth.weekday - 1) % 7;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();
    const weekdayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
    final now = DateTime.now();

    return Column(
      children: [
        Row(
          children: weekdayLabels
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        for (int row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNumber = cellIndex - leadingEmpty + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final date = DateTime(visibleMonth.year, visibleMonth.month, dayNumber);
              final isToday = _isSameDay(date, now);
              final hasAppointment = markedDays.any((m) => _isSameDay(m, date));

              return Expanded(
                child: SizedBox(
                  height: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: isToday ? BoxDecoration(color: cs.primary, shape: BoxShape.circle) : null,
                        child: Text(
                          '$dayNumber',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isToday ? cs.onPrimary : cs.onSurface,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      hasAppointment && !isToday
                          ? Container(width: 4, height: 4, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle))
                          : const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
