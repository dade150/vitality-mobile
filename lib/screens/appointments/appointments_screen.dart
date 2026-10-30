import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime? _selectedDate;
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appointments = context.watch<AppointmentsProvider>();
    final next = appointments.next;
    final allUpcoming = [
      if (next != null) next,
      ...appointments.upcoming,
    ];
    final visibleUpcoming = _showAllUpcoming ? allUpcoming : allUpcoming.take(3).toList();
    final allPast = appointments.past;
    final visiblePast = _showAllPast ? allPast : allPast.take(3).toList();
    final selectedAppointments = _selectedDate == null
        ? <Appointment>[]
        : appointments.appointments.where((a) => _isSameDay(a.date, _selectedDate!)).toList();

    return AppScaffold(
      navIndex: 3,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (appointments.isLoading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],
          if (appointments.loadFailed) ...[
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
            const SizedBox(height: 16),
          ],
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
                  selectedDate: _selectedDate,
                  onSelectDate: (d) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_selectedDate != null && _isSameDay(_selectedDate!, d)) {
                        _selectedDate = null;
                      } else {
                        _selectedDate = d;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (selectedAppointments.isNotEmpty) ...[
            _buildSelectedDayCard(context, theme, cs, selectedAppointments),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/appointments/add'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Aggiungi Visita'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Prossime Visite',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (allUpcoming.length > 3)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllUpcoming = !_showAllUpcoming),
                  icon: Icon(
                    _showAllUpcoming ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _showAllUpcoming ? 'Meno' : 'Tutte (${allUpcoming.length})',
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (allUpcoming.isEmpty)
            SectionCard(
              child: Text('Nessuna visita in programma.', style: theme.textTheme.bodyMedium),
            )
          else
            for (final appt in visibleUpcoming)
              _AppointmentCard(
                appt: appt,
                isPast: false,
                onEdit: () => _editVisit(appt),
              ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Storico Visite',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (allPast.length > 3)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllPast = !_showAllPast),
                  icon: Icon(
                    _showAllPast ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _showAllPast ? 'Meno' : 'Tutte (${allPast.length})',
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (allPast.isEmpty)
            Text('Nessuna visita passata registrata.', style: theme.textTheme.bodyMedium)
          else
            for (final appt in visiblePast)
              _AppointmentCard(
                appt: appt,
                isPast: true,
                onEdit: () => _editVisit(appt),
              ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<Appointment> appts,
  ) {
    final date = _selectedDate!;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.lightPeach,
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Visita del ${AppDateFormat.dayMonth(date)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.accent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Chiudi',
                  onPressed: () => setState(() => _selectedDate = null),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < appts.length; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appts[i].type,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTime(appts[i].time),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                            if (appts[i].doctorName.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 16, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      appts[i].doctorName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (appts[i].location.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      appts[i].location,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (appts[i].notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                appts[i].notes,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Modifica visita',
                        onPressed: () => _editVisit(appts[i]),
                        icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appt;
  final bool isPast;
  final VoidCallback onEdit;

  const _AppointmentCard({
    required this.appt,
    required this.isPast,
    required this.onEdit,
  });

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateBadge(DateTime date, TimeOfDay time) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final timeStr = _formatTime(time);
    if (isToday) return 'OGGI · $timeStr';
    return '${AppDateFormat.dayMonth(date).toUpperCase()} · $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        highlight: !isPast,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPast ? cs.surfaceContainerHighest : AppColors.lightPeach,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPast
                          ? cs.outlineVariant
                          : AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: isPast ? cs.onSurfaceVariant : AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateBadge(appt.date, appt.time),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isPast ? cs.onSurfaceVariant : AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: isPast ? cs.surfaceContainerHighest : cs.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isPast
                          ? cs.outlineVariant
                          : AppColors.accent.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: isPast ? cs.onSurfaceVariant : AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Modifica',
                            style: TextStyle(
                              color: isPast ? cs.onSurfaceVariant : AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              appt.type,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            if (appt.doctorName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appt.doctorName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (appt.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appt.location,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (appt.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appt.notes,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final List<DateTime> markedDays;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onSelectDate;

  const _CalendarGrid({
    required this.visibleMonth,
    required this.markedDays,
    this.selectedDate,
    this.onSelectDate,
  });

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
              final isSelected = selectedDate != null && _isSameDay(date, selectedDate!);
              final hasAppointment = markedDays.any((m) => _isSameDay(m, date));

              BoxDecoration? decoration;
              Color textColor = cs.onSurface;
              FontWeight fontWeight = FontWeight.normal;

              if (isSelected) {
                if (isToday) {
                  decoration = BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  );
                  textColor = cs.onPrimary;
                  fontWeight = FontWeight.bold;
                } else {
                  decoration = BoxDecoration(
                    color: AppColors.lightPeach,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary, width: 2),
                  );
                  textColor = cs.primary;
                  fontWeight = FontWeight.bold;
                }
              } else if (isToday) {
                decoration = BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                );
                textColor = cs.onPrimary;
                fontWeight = FontWeight.bold;
              }

              return Expanded(
                child: InkWell(
                  onTap: onSelectDate != null ? () => onSelectDate!(date) : null,
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    height: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: decoration,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Text(
                                '$dayNumber',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.1,
                                  color: textColor,
                                  fontWeight: fontWeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        hasAppointment
                            ? Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : const SizedBox(height: 5),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
