import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../providers/appointments_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_card.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _showAllUpcoming = false;
  bool _showAllPast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppointmentsProvider>();
      if (!provider.hasLoaded && !provider.isLoading) provider.refresh();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _editVisit(Appointment appt) {
    Navigator.of(context).pushNamed('/appointments/add', arguments: appt);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appointments = context.watch<AppointmentsProvider>();
    final next = appointments.next;
    final allUpcoming = appointments.upcoming;
    final visibleUpcoming = _showAllUpcoming ? allUpcoming : allUpcoming.take(3).toList();
    final allPast = appointments.past;
    final visiblePast = _showAllPast ? allPast : allPast.take(3).toList();

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
              Text(
                'Visite Mediche',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/appointments/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi Visita'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ),
          if (appointments.isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (appointments.loadFailed) ...[
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Impossibile caricare le visite.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(onPressed: appointments.refresh, child: const Text('Riprova')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(AppDateFormat.monthYear(_visibleMonth), style: theme.textTheme.titleMedium),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
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
            SectionCard(
              child: Text('Nessuna visita in programma.', style: theme.textTheme.bodyMedium),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_isToday(next.date) ? 'OGGI' : AppDateFormat.dayMonthYear(next.date).toUpperCase()} · ${_formatTime(next.time)}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editVisit(next),
                        icon: Icon(Icons.edit_outlined, size: 18, color: cs.onPrimary),
                        label: Text('Modifica', style: TextStyle(color: cs.onPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next.type,
                    style: theme.textTheme.headlineSmall?.copyWith(color: cs.onPrimary),
                  ),
                  if (next.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: cs.onPrimary.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            next.location,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (next.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      next.notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.85),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/reports/add'),
                    icon: Icon(Icons.upload_file_rounded, color: cs.onPrimary),
                    label: Text(
                      'Carica Referto per Visita',
                      style: TextStyle(color: cs.onPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.onPrimary.withValues(alpha: 0.6)),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Prossime Visite', style: theme.textTheme.titleLarge),
              if (allUpcoming.length > 3)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllUpcoming = !_showAllUpcoming),
                  icon: Icon(
                    _showAllUpcoming ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  ),
                  label: Text(
                    _showAllUpcoming ? 'Mostra meno' : 'Vedi tutte (${allUpcoming.length})',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (allUpcoming.isEmpty)
            Text('Nessun\'altra visita in programma.', style: theme.textTheme.bodyMedium)
          else
            for (final appt in visibleUpcoming)
              _AppointmentRowCard(
                appt: appt,
                isPast: false,
                onEdit: () => _editVisit(appt),
              ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storico Visite Effettuate',
                style: theme.textTheme.titleLarge?.copyWith(color: AppColors.accent),
              ),
              if (allPast.length > 3)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllPast = !_showAllPast),
                  icon: Icon(_showAllPast ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                  label: Text(_showAllPast ? 'Mostra meno' : 'Vedi tutte (${allPast.length})'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (allPast.isEmpty)
            Text('Nessuna visita passata registrata.', style: theme.textTheme.bodyMedium)
          else
            for (final appt in visiblePast)
              _AppointmentRowCard(
                appt: appt,
                isPast: true,
                onEdit: () => _editVisit(appt),
              ),
        ],
      ),
    );
  }
}

class _AppointmentRowCard extends StatelessWidget {
  final Appointment appt;
  final bool isPast;
  final VoidCallback onEdit;

  const _AppointmentRowCard({
    required this.appt,
    required this.isPast,
    required this.onEdit,
  });

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitleParts = <String>[
      'Ore ${_formatTime(appt.time)}',
      if (appt.location.isNotEmpty) appt.location,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isPast ? cs.surfaceContainerHighest : cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    AppDateFormat.daySmall(appt.date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isPast ? cs.onSurfaceVariant : cs.primary,
                    ),
                  ),
                  Text(
                    AppDateFormat.monthShort(appt.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                    subtitleParts.join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (appt.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      appt.notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Modifica visita',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final List<DateTime> markedDays;

  const _CalendarGrid({required this.visibleMonth, required this.markedDays});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
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
                        decoration: isToday
                            ? BoxDecoration(color: cs.primary, shape: BoxShape.circle)
                            : null,
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
                          ? Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                            )
                          : const SizedBox(height: 5),
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
