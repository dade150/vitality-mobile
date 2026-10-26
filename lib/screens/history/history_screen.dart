import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_entry.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_card.dart';
import '../../widgets/simple_charts.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();

  static const _weekLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final health = context.read<HealthProvider>();
      if (!health.hasLoaded && !health.isLoading) {
        health.refresh();
      } else {
        health.ensureLoaded(_periodStart);
      }
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtNum(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  DateTime get _periodStart {
    final d = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime get _periodEnd => _periodStart.add(const Duration(days: 7));

  bool _inPeriod(DateTime t) => !t.isBefore(_periodStart) && t.isBefore(_periodEnd);

  bool get _canGoForward {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return !_periodEnd.isAfter(todayStart);
  }

  void _changeWeek(int delta) {
    if (delta > 0 && !_canGoForward) return;
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 7 * delta));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (_selectedDate.isAfter(today)) {
        _selectedDate = today;
      }
    });
    context.read<HealthProvider>().ensureLoaded(_periodStart);
  }

  String get _periodTitle {
    final start = _periodStart;
    final end = _periodEnd.subtract(const Duration(days: 1));
    final sy = AppDateFormat.daySmall(start);
    final sm = AppDateFormat.monthShort(start);
    final ey = AppDateFormat.daySmall(end);
    final em = AppDateFormat.monthShort(end);
    final year = end.year != start.year ? ' ${end.year}' : '';
    return start.month == end.month ? '$sy - $ey $em$year' : '$sy $sm - $ey $em$year';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();
    final health = context.watch<HealthProvider>();

    return AppScaffold(
      navIndex: 1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Text(
                'Storico Settimanale',
                style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            highlight: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.accent),
                ),
                Text(_periodTitle, style: theme.textTheme.titleSmall),
                IconButton(
                  onPressed: _canGoForward ? () => _changeWeek(1) : null,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _canGoForward
                        ? AppColors.accent
                        : cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          if (health.isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 24),
          if (settings.isSectionVisible('terapia')) ...[
            _buildTerapiaCard(context, health),
            const SizedBox(height: 16),
          ],
          if (settings.isSectionVisible('glicemia')) ...[
            _buildGlicemiaCard(context, health),
            const SizedBox(height: 16),
          ],
          if (settings.isSectionVisible('pressione')) ...[
            _buildPressioneCard(context, health),
            const SizedBox(height: 16),
          ],
          if (settings.isSectionVisible('pasti')) ...[
            _buildPastiCard(context, health),
            const SizedBox(height: 16),
          ],
          if (settings.isSectionVisible('attivita')) ...[
            _buildAttivitaCard(context, health),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTerapiaCard(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final therapyCount = health.therapyItems.length;
    final expected = therapyCount * 7;
    int taken = 0;
    final dailyValues = List<double?>.filled(7, null);

    if (therapyCount > 0) {
      for (int i = 0; i < 7; i++) {
        final day = _periodStart.add(Duration(days: i));
        int dayTaken = 0;
        for (final item in health.therapyItems) {
          if (health.isTherapyTaken(item.id, day)) {
            dayTaken++;
            taken++;
          }
        }
        dailyValues[i] = dayTaken == 0 ? null : ((dayTaken / therapyCount) * 100).roundToDouble();
      }
    }
    final pct = expected == 0 ? 0 : ((taken / expected) * 100).round();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            icon: Icons.medication_outlined,
            title: 'Terapia',
            value: therapyCount == 0 ? '-' : '$pct%',
            unit: 'Aderenza Sett.',
            color: cs.tertiary,
          ),
          const SizedBox(height: 8),
          if (therapyCount == 0)
            Text('Nessuna terapia registrata.', style: theme.textTheme.bodyMedium)
          else ...[
            Text('$taken di $expected assunzioni registrate', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SimpleBarChart(
              labels: _weekLabels,
              values: dailyValues,
              maxValue: 100,
              color: cs.tertiary,
              valueSuffix: '%',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlicemiaCard(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final readings = health.glucoseReadings.where((r) => _inPeriod(r.time)).toList();

    final dailyValues = List<double?>.filled(7, null);
    final dailyColors = List<Color?>.filled(7, null);
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayReadings = readings.where((r) => _sameDay(r.time, day)).toList();
      if (dayReadings.isNotEmpty) {
        final avg = dayReadings.map((r) => r.value).reduce((a, b) => a + b) / dayReadings.length;
        final hasOutOfRange =
            avg < 70 || avg > 180 || dayReadings.any((r) => r.value < 70 || r.value > 180);
        dailyValues[i] = avg.roundToDouble();
        dailyColors[i] = hasOutOfRange ? cs.error : AppColors.accent;
      }
    }

    final hypoCount = readings.where((r) => r.value < 70).length;
    final hyperCount = readings.where((r) => r.value > 180).length;
    final maxDaily = dailyValues.whereType<double>().fold<double>(180.0, math.max);
    final avgWeek = readings.isEmpty
        ? '-'
        : _fmtNum(readings.map((r) => r.value).reduce((a, b) => a + b) / readings.length);

    return SectionCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            icon: Icons.water_drop_outlined,
            title: 'Glicemia',
            value: avgWeek,
            unit: 'mg/dL · Media Sett.',
            color: AppColors.accent,
          ),
          const SizedBox(height: 8),
          if (readings.isEmpty)
            Text('Nessuna misurazione nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            Text(
              'Min ${_fmtNum(readings.map((r) => r.value).reduce(math.min))} · '
              'Max ${_fmtNum(readings.map((r) => r.value).reduce(math.max))} · '
              '${readings.length} misurazioni',
              style: theme.textTheme.bodyMedium,
            ),
            if (hypoCount > 0 || hyperCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          if (hypoCount > 0) '$hypoCount ipoglicemia (<70 mg/dL)',
                          if (hyperCount > 0) '$hyperCount iperglicemia (>180 mg/dL)',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SimpleBarChart(
              labels: _weekLabels,
              values: dailyValues,
              maxValue: maxDaily,
              color: AppColors.accent,
              barColors: dailyColors,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPressioneCard(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final readings = health.pressureReadings.where((r) => _inPeriod(r.time)).toList();

    final dailySys = List<int>.filled(7, 0);
    final dailyDia = List<int>.filled(7, 0);
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayReadings = readings.where((r) => _sameDay(r.time, day)).toList();
      if (dayReadings.isNotEmpty) {
        dailySys[i] =
            (dayReadings.map((r) => r.systolic).reduce((a, b) => a + b) / dayReadings.length).round();
        dailyDia[i] =
            (dayReadings.map((r) => r.diastolic).reduce((a, b) => a + b) / dayReadings.length).round();
      }
    }
    final maxSys = dailySys.fold<int>(180, math.max).toDouble();
    final avgLabel = readings.isEmpty
        ? '-'
        : '${(readings.map((r) => r.systolic).reduce((a, b) => a + b) / readings.length).round()}/'
            '${(readings.map((r) => r.diastolic).reduce((a, b) => a + b) / readings.length).round()}';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            icon: Icons.favorite_outline_rounded,
            title: 'Pressione Arteriosa',
            value: avgLabel,
            unit: 'mmHg · Media Sett.',
            color: cs.secondary,
          ),
          const SizedBox(height: 8),
          if (readings.isEmpty)
            Text('Nessuna misurazione nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            Text('${readings.length} misurazioni', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            BloodPressureChart(
              labels: _weekLabels,
              systolic: dailySys,
              diastolic: dailyDia,
              maxValue: maxSys,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _legendDot(context, cs.tertiaryContainer, 'Sistolica (Massima)'),
                _legendDot(context, cs.tertiary, 'Diastolica (Minima)'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPastiCard(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final meals = health.mealEntries.where((m) => _inPeriod(m.date)).toList();
    final totalKcal = meals.fold<int>(0, (s, m) => s + m.calories);

    final dailyKcal = List<double?>.filled(7, null);
    int daysWithMeals = 0;
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayMeals = meals.where((m) => _sameDay(m.date, day)).toList();
      if (dayMeals.isNotEmpty) {
        daysWithMeals++;
        dailyKcal[i] = dayMeals.fold<int>(0, (s, m) => s + m.calories).toDouble();
      }
    }
    final avgKcal = daysWithMeals == 0 ? 0 : (totalKcal / daysWithMeals).round();
    final maxDailyKcal = dailyKcal.whereType<double>().fold<double>(2000.0, math.max);
    final recentMeals = meals.reversed.take(5).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            icon: Icons.restaurant_outlined,
            title: 'Pasti',
            value: meals.isEmpty ? '-' : '$totalKcal',
            unit: 'kcal totali',
            color: cs.secondary,
          ),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            Text('Nessun pasto registrato nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            Text(
              '~$avgKcal kcal/giorno ($daysWithMeals ${daysWithMeals == 1 ? 'giorno' : 'giorni'}) · ${meals.length} pasti',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SimpleBarChart(
              labels: _weekLabels,
              values: dailyKcal,
              maxValue: maxDailyKcal,
              color: cs.secondary,
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            for (final meal in recentMeals)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: cs.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${AppDateFormat.weekdayShort(meal.date)} · ${meal.type.label}: ${meal.description}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${meal.isEstimated ? '~' : ''}${meal.calories} kcal',
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttivitaCard(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = health.activityEntries.where((a) => _inPeriod(a.date)).toList();
    final steps = entries.fold<int>(0, (s, a) => s + a.steps);
    final minutes = entries.fold<int>(0, (s, a) => s + a.minutes);

    const targetMinutes = 150;
    final progress = (minutes / targetMinutes).clamp(0.0, 1.0);
    final pctGoal = ((minutes / targetMinutes) * 100).round();

    final dailyMinutes = List<double?>.filled(7, null);
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayMin = entries
          .where((a) => _sameDay(a.date, day))
          .fold<int>(0, (s, a) => s + a.minutes);
      if (dayMin > 0) {
        dailyMinutes[i] = dayMin.toDouble();
      }
    }
    final maxDailyMin = dailyMinutes.whereType<double>().fold<double>(60.0, math.max);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            icon: Icons.directions_walk_rounded,
            title: 'Attività',
            value: entries.isEmpty ? '-' : '$minutes',
            unit: 'minuti totali',
            color: cs.tertiary,
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text('Nessuna attività registrata nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            if (steps > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('$steps passi totali nella settimana', style: theme.textTheme.bodyMedium),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: cs.surfaceContainerHigh,
                color: cs.tertiary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pctGoal% obiettivo settimanale ($minutes / $targetMinutes min ADA/SID-AMD)',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SimpleBarChart(
              labels: _weekLabels,
              values: dailyMinutes,
              maxValue: maxDailyMin,
              color: cs.tertiary,
              valueSuffix: 'm',
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
            Text(unit, style: theme.textTheme.bodySmall, textAlign: TextAlign.end),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
