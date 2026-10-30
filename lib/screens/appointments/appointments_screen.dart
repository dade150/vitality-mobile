import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../providers/appointments_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/section_card.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

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
    final visibleUpcoming = allUpcoming.take(3).toList();
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
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.accent),
                    ),
                    Text(
                      AppDateFormat.monthYear(_visibleMonth),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
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
          _buildSectionHeader(
            context: context,
            title: 'Prossime visite',
            onViewAll: () => Navigator.of(context).pushNamed(
              '/appointments/all',
              arguments: 'upcoming',
            ),
          ),
          const SizedBox(height: 12),
          if (allUpcoming.isEmpty)
            SectionCard(
              child: Text('Nessuna visita in programma.', style: theme.textTheme.bodyMedium),
            )
          else ...[
            for (final appt in visibleUpcoming)
              AppointmentCard(
                appt: appt,
                isPast: false,
                onEdit: () => _editVisit(appt),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required VoidCallback onViewAll,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onViewAll,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: AppColors.accent.withValues(alpha: 0.45),
              width: 1.2,
            ),
            backgroundColor: AppColors.lightPeach.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Visualizza tutto',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<Appointment> appts,
  ) {
    final date = _selectedDate!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Visite del ${AppDateFormat.dayMonth(date)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Chiudi selezione',
              onPressed: () => setState(() => _selectedDate = null),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final appt in appts)
          AppointmentCard(
            appt: appt,
            isPast: appt.date.isBefore(today),
            onEdit: () => _editVisit(appt),
          ),
      ],
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
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  );
                  textColor = Colors.white;
                  fontWeight = FontWeight.bold;
                } else if (hasAppointment) {
                  decoration = BoxDecoration(
                    color: AppColors.lightPeach,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.onSurface, width: 2),
                  );
                  textColor = cs.onSurface;
                  fontWeight = FontWeight.w800;
                } else {
                  decoration = BoxDecoration(
                    color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outlineVariant, width: 1.5),
                  );
                  textColor = cs.onSurface;
                  fontWeight = FontWeight.bold;
                }
              } else if (isToday) {
                // Giorno corrente: cerchio arancione vivo solido con testo bianco
                decoration = const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                );
                textColor = Colors.white;
                fontWeight = FontWeight.bold;
              } else if (hasAppointment) {
                // Giorno con visita: dischetto pesca chiaro morbido con numero scuro bold
                // nettamente distinto dal cerchio arancione pieno di Oggi
                decoration = const BoxDecoration(
                  color: AppColors.lightPeach,
                  shape: BoxShape.circle,
                );
                textColor = cs.onSurface;
                fontWeight = FontWeight.w800;
              }

              return Expanded(
                child: InkWell(
                  onTap: onSelectDate != null ? () => onSelectDate!(date) : null,
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
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
