import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_entry.dart';
import '../../providers/health_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/section_card.dart';

/// Storico completo dei pasti registrati.
class MealsHistoryScreen extends StatelessWidget {
  const MealsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final health = context.watch<HealthProvider>();
    final meals = List.of(health.mealEntries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico Pasti'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: meals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'Nessun pasto registrato',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registra i tuoi pasti giornalieri dal Diario.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: meals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final meal = meals[index];

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
                        child: const Icon(Icons.restaurant_outlined, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  meal.type.label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                    fontSize: 16,
                                  ),
                                ),
                                if (meal.calories > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${meal.calories} kcal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (meal.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                meal.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              AppDateFormat.dayMonthYearTime(meal.date),
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
