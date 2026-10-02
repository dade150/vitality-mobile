import 'package:flutter/material.dart';

/// Grafico a barre semplice, senza dipendenze esterne: usato per aderenza
/// terapia e andamento glicemia nello Storico Salute.
class SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double maxValue;
  final Color color;
  final double height;

  const SimpleBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.maxValue,
    required this.color,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) {
          final value = i < values.length ? values[i] : 0.0;
          final barHeight = maxValue <= 0 ? 4.0 : (value / maxValue * height).clamp(4.0, height);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: barHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i], style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Grafico a barre impilate (sistolica/diastolica) per la pressione.
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
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) {
          final sys = i < systolic.length ? systolic[i].toDouble() : 0.0;
          final dia = i < diastolic.length ? diastolic[i].toDouble() : 0.0;
          final totalHeight = (sys / maxValue * height).clamp(6.0, height);
          final diaHeight = (dia / maxValue * height).clamp(3.0, totalHeight);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: totalHeight,
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: diaHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.tertiary,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i], style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
