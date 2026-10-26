import 'package:flutter/material.dart';

/// Grafico a barre semplice, senza dipendenze esterne: usato per aderenza
/// terapia, andamento glicemia, calorie pasti e minuti attività nella vista
/// settimanale del Diario e nello Storico Salute.
///
/// Mostra sopra ogni barra (`Lun`..`Dom`) l'etichetta numerica ad alto contrasto
/// (o `-` se per quel giorno non sono presenti rilevazioni), evitando di
/// disegnare barre colorate ingannevoli nei giorni privi di dati.
class SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double?> values;
  final double maxValue;
  final Color color;
  final List<Color?>? barColors;
  final double height;
  final String valueSuffix;
  final bool showZeroAsDash;

  const SimpleBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.maxValue,
    required this.color,
    this.barColors,
    this.height = 120,
    this.valueSuffix = '',
    this.showZeroAsDash = true,
  });

  String _formatValue(double v) {
    final numStr = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    return '$numStr$valueSuffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return SizedBox(
      height: height + 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) {
          final raw = i < values.length ? values[i] : null;
          final hasData = raw != null && (!showZeroAsDash || raw > 0);
          final value = raw ?? 0.0;
          final barColor = (barColors != null && i < barColors!.length && barColors![i] != null)
              ? barColors![i]!
              : color;

          final barHeight = !hasData
              ? 4.0
              : (value <= 0 ? 6.0 : (value / safeMax * height).clamp(8.0, height));

          final valueLabel = hasData ? _formatValue(value) : '-';

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valueLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasData ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: barHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasData ? barColor : cs.outlineVariant.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Grafico a barre impilate (sistolica/diastolica) per la pressione arteriosa.
///
/// Mostra sopra ogni colonna il valore `sys/dia` (o `-` nei giorni senza
/// misurazioni) e usa un indicatore piatto neutro quando il giorno non ha dati.
class BloodPressureChart extends StatelessWidget {
  final List<String> labels;
  final List<int> systolic;
  final List<int> diastolic;
  final double height;
  final double maxValue;

  const BloodPressureChart({
    super.key,
    required this.labels,
    required this.systolic,
    required this.diastolic,
    this.height = 120,
    this.maxValue = 180,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final safeMax = maxValue <= 0 ? 180.0 : maxValue;

    return SizedBox(
      height: height + 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) {
          final sys = i < systolic.length ? systolic[i] : 0;
          final dia = i < diastolic.length ? diastolic[i] : 0;
          final hasData = sys > 0 && dia > 0;

          final totalHeight =
              hasData ? (sys / safeMax * height).clamp(12.0, height) : 4.0;
          final diaHeight =
              hasData ? (dia / safeMax * height).clamp(6.0, totalHeight - 4.0) : 4.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hasData ? '$sys/$dia' : '-',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasData ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!hasData)
                    SizedBox(
                      height: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: totalHeight,
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: diaHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.tertiary,
                                borderRadius:
                                    const BorderRadius.vertical(bottom: Radius.circular(6)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
