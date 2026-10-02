import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_card.dart';
import '../../widgets/simple_charts.dart';
import '../../models/meal_entry.dart';

enum HistoryRange { settimana, mese }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryRange _range = HistoryRange.settimana;

  static const _weekLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
              Text('Storico Salute', style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(child: _rangeButton(context, 'Settimana', HistoryRange.settimana)),
                Expanded(child: _rangeButton(context, 'Mese', HistoryRange.mese)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left_rounded)),
                Text(
                  _range == HistoryRange.settimana ? '1 - 7 Ottobre 2023' : 'Ottobre 2023',
                  style: theme.textTheme.titleSmall,
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. Terapia (in evidenza, come richiesto, all'inizio dello storico)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(context,
                    icon: Icons.medication_outlined, title: 'Storico Terapie', value: '95%', unit: 'Aderenza Sett.', color: cs.secondary),
                const SizedBox(height: 16),
                SimpleBarChart(
                  labels: _weekLabels,
                  values: const [100, 100, 50, 100, 100, 100, 90],
                  maxValue: 100,
                  color: cs.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Glicemia
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(context,
                    icon: Icons.opacity_rounded, title: 'Glicemia', value: '105', unit: 'mg/dL · Media Sett.', color: cs.primary),
                const SizedBox(height: 16),
                SimpleBarChart(
                  labels: _weekLabels,
                  values: const [98, 105, 110, 102, 108, 100, 106],
                  maxValue: 160,
                  color: cs.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Pressione
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(context,
                    icon: Icons.favorite_outline_rounded, title: 'Pressione', value: '120/80', unit: 'mmHg · Media Sett.', color: cs.tertiary),
                const SizedBox(height: 16),
                const BloodPressureChart(
                  labels: _weekLabels,
                  systolic: [122, 118, 128, 121, 119, 123, 120],
                  diastolic: [80, 78, 82, 79, 77, 81, 80],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _legendDot(cs.tertiaryContainer, 'Sistolica'),
                    const SizedBox(width: 16),
                    _legendDot(cs.tertiary, 'Diastolica'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Pasti - versione semplificata (diario + stima calorica), come richiesto
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(context,
                    icon: Icons.restaurant_outlined,
                    title: 'Storico Pasti',
                    value: '${_averageCalories(health)}',
                    unit: 'kcal · Media Giornaliera',
                    color: cs.tertiary),
                const SizedBox(height: 12),
                if (health.mealEntries.isEmpty)
                  Text('Nessun pasto registrato in questo periodo.', style: theme.textTheme.bodyMedium)
                else
                  for (final meal in health.mealEntries.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: cs.tertiary),
                          const SizedBox(width: 10),
                          Expanded(child: Text('${switch (meal.type) { MealType.colazione => 'Colazione', MealType.pranzo => 'Pranzo', MealType.cena => 'Cena', MealType.spuntino => 'Spuntino' }}: ${meal.description}', style: theme.textTheme.bodyMedium)),
                          Text('${meal.calories} kcal', style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ),
                const Divider(),
                Text('Apporto calorico bilanciato questa settimana.', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Attività
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(context,
                    icon: Icons.directions_walk_rounded,
                    title: 'Attività',
                    value: '${health.todaySteps == 0 ? 4500 : health.todaySteps}',
                    unit: 'passi · Media Giornaliera',
                    color: cs.secondary),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0.65,
                    minHeight: 14,
                    backgroundColor: cs.surfaceContainerHigh,
                    color: cs.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text('65% Obiettivo', style: theme.textTheme.labelMedium),
                const SizedBox(height: 8),
                Text('Ottimo lavoro! Sei in movimento costante.', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  int _averageCalories(HealthProvider health) {
    if (health.mealEntries.isEmpty) return 1850;
    final total = health.mealEntries.fold<int>(0, (sum, m) => sum + m.calories);
    return (total / health.mealEntries.length).round();
  }

  Widget _rangeButton(BuildContext context, String label, HistoryRange value) {
    final cs = Theme.of(context).colorScheme;
    final selected = _range == value;
    return GestureDetector(
      onTap: () => setState(() => _range = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _cardHeader(BuildContext context,
      {required IconData icon, required String title, required String value, required String unit, required Color color}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
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

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
