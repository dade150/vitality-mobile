import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/section_card.dart';

/// Storico completo delle misurazioni della pressione sanguigna.
class BloodPressureHistoryScreen extends StatelessWidget {
  const BloodPressureHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final health = context.watch<HealthProvider>();
    final readings = List.of(health.pressureReadings)
      ..sort((a, b) => b.time.compareTo(a.time));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico Pressione'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: readings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_outline_rounded, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'Nessuna misurazione registrata',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registra i tuoi valori di pressione sistolica e diastolica dal Diario.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: readings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final reading = readings[index];
                final sys = reading.systolic.round();
                final dia = reading.diastolic.round();

                return SectionCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.lightPeach,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.favorite_outline_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$sys / $dia mmHg',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppDateFormat.dayMonthYearTime(reading.time),
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
