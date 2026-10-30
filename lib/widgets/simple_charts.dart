import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Grafico a barre semplice, senza dipendenze esterne: usato per calorie pasti
/// e minuti attività nella vista settimanale del Diario e nello Storico Salute.
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
    this.height = 110,
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
      height: height + 46,
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
                        color: hasData ? barColor : cs.outlineVariant.withValues(alpha: 0.4),
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

/// Tracker compatto a 7 giorni per la terapia:
/// mostra una fila di indicatori a cerchio per ciascun giorno della settimana,
/// con spunta verde se completata (100%), icona orologio/parziale se incompleta,
/// icona rossa se saltata, o trattino neutro se senza prescrizioni/futuro.
class WeeklyTherapyTracker extends StatelessWidget {
  final List<String> labels;
  final List<double?> completionRatios; // 0.0 .. 1.0, null se nessun dato previsto

  const WeeklyTherapyTracker({
    super.key,
    required this.labels,
    required this.completionRatios,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: List.generate(labels.length, (i) {
        final ratio = i < completionRatios.length ? completionRatios[i] : null;

        Color bgColor;
        Color fgColor;
        Widget iconWidget;
        String statusLabel = '-';

        if (ratio == null) {
          bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.4);
          fgColor = cs.onSurfaceVariant;
          iconWidget = Text('-', style: theme.textTheme.titleMedium?.copyWith(color: fgColor));
        } else if (ratio >= 0.99) {
          // Completo (100%)
          bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.15);
          fgColor = const Color(0xFF2E7D32);
          iconWidget = Icon(Icons.check_rounded, color: fgColor, size: 20);
          statusLabel = '100%';
        } else if (ratio > 0) {
          // Parziale
          bgColor = const Color(0xFFED6C02).withValues(alpha: 0.15);
          fgColor = const Color(0xFFED6C02);
          iconWidget = Icon(Icons.timelapse_rounded, color: fgColor, size: 20);
          statusLabel = '${(ratio * 100).round()}%';
        } else {
          // 0% (saltato)
          bgColor = cs.error.withValues(alpha: 0.12);
          fgColor = cs.error;
          iconWidget = Icon(Icons.close_rounded, color: fgColor, size: 20);
          statusLabel = '0%';
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[i],
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ratio != null && ratio > 0 ? fgColor.withValues(alpha: 0.35) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: iconWidget,
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Grafico dell'andamento glicemico settimanale con fascia target (70-180 mg/dL).
/// Mostra una linea continua con punti per i giorni registrati: i punti dentro
/// la fascia sono verdi/accent, quelli fuori sono evidenziati in rosso.
class GlucoseTrendChart extends StatelessWidget {
  final List<String> labels;
  final List<double?> values;
  final double targetMin;
  final double targetMax;
  final double height;

  const GlucoseTrendChart({
    super.key,
    required this.labels,
    required this.values,
    this.targetMin = 70.0,
    this.targetMax = 180.0,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Calcolo range scala Y
    double dataMin = targetMin;
    double dataMax = targetMax;
    for (final v in values) {
      if (v != null) {
        if (v < dataMin) dataMin = v;
        if (v > dataMax) dataMax = v;
      }
    }
    final minY = math.max(40.0, (dataMin - 15).floorToDouble());
    final maxY = math.min(350.0, (dataMax + 20).ceilToDouble());

    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _GlucoseChartPainter(
              values: values,
              targetMin: targetMin,
              targetMax: targetMax,
              minY: minY,
              maxY: maxY,
              cs: cs,
              theme: theme,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _GlucoseChartPainter extends CustomPainter {
  final List<double?> values;
  final double targetMin;
  final double targetMax;
  final double minY;
  final double maxY;
  final ColorScheme cs;
  final ThemeData theme;

  _GlucoseChartPainter({
    required this.values,
    required this.targetMin,
    required this.targetMax,
    required this.minY,
    required this.maxY,
    required this.cs,
    required this.theme,
  });

  double _getY(double val, double height) {
    final clamped = val.clamp(minY, maxY);
    final fraction = (clamped - minY) / (maxY - minY);
    return height - (fraction * height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = values.length;
    if (count == 0) return;

    final stepX = size.width / count;
    final halfStep = stepX / 2;

    // 1. Disegna fascia target (70-180)
    final yTargetMax = _getY(targetMax, size.height);
    final yTargetMin = _getY(targetMin, size.height);

    final targetPaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final targetRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, yTargetMax, size.width, yTargetMin),
      const Radius.circular(6),
    );
    canvas.drawRRect(targetRect, targetPaint);

    // Linee guida orizzontali del target (tratteggiate)
    final linePaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    _drawDashedLine(canvas, Offset(0, yTargetMax), Offset(size.width, yTargetMax), linePaint);
    _drawDashedLine(canvas, Offset(0, yTargetMin), Offset(size.width, yTargetMin), linePaint);

    // Etichette target a destra
    final labelStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF2E7D32).withValues(alpha: 0.6),
    );
    _drawText(canvas, '180', Offset(size.width - 24, yTargetMax - 11), labelStyle);
    _drawText(canvas, '70', Offset(size.width - 18, yTargetMin + 2), labelStyle);

    // 2. Disegna linea trend tra i punti validi
    final List<Offset> points = [];
    final List<int> pointIndices = [];
    for (int i = 0; i < count; i++) {
      final v = values[i];
      if (v != null) {
        final x = (i * stepX) + halfStep;
        final y = _getY(v, size.height);
        points.add(Offset(x, y));
        pointIndices.add(i);
      }
    }

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final trendPaint = Paint()
        ..color = cs.primary.withValues(alpha: 0.6)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, trendPaint);
    }

    // 3. Disegna i punti e i valori numerici
    for (int idx = 0; idx < points.length; idx++) {
      final p = points[idx];
      final val = values[pointIndices[idx]]!;
      final isOutOfRange = val < targetMin || val > targetMax;
      final pointColor = isOutOfRange ? cs.error : const Color(0xFF2E7D32);

      // Cerchietto punto
      final circlePaint = Paint()
        ..color = pointColor
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = cs.surface
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(p, 5.5, circlePaint);
      canvas.drawCircle(p, 5.5, borderPaint);

      // Testo valore sopra il punto
      final valStr = val.round().toString();
      final valStyle = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isOutOfRange ? cs.error : cs.onSurface,
      );
      final textSpan = TextSpan(text: valStr, style: valStyle);
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Posizionamento del testo (sopra il punto o sotto se troppo vicino al tetto)
      double textY = p.dy - tp.height - 4;
      if (textY < 0) {
        textY = p.dy + 8;
      }
      tp.paint(canvas, Offset(p.dx - (tp.width / 2), textY));
    }

    // Per i giorni senza dato, disegna un trattino neutro
    for (int i = 0; i < count; i++) {
      if (values[i] == null) {
        final x = (i * stepX) + halfStep;
        final centerY = (yTargetMax + yTargetMin) / 2;
        final dashPaint = Paint()
          ..color = cs.outlineVariant.withValues(alpha: 0.4)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - 4, centerY), Offset(x + 4, centerY), dashPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset(math.min(startX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GlucoseChartPainter old) => true;
}

/// Grafico a doppia barra affiancata per la pressione arteriosa (Massima e Minima).
/// Per ciascun giorno mostra due colonne affiancate ben distinte:
/// - Sistolica (Massima): colonna a sinistra
/// - Diastolica (Minima): colonna a destra
class BloodPressureGroupedBarChart extends StatelessWidget {
  final List<String> labels;
  final List<int> systolic;
  final List<int> diastolic;
  final double height;
  final double maxValue;
  final Color systolicColor;
  final Color diastolicColor;

  const BloodPressureGroupedBarChart({
    super.key,
    required this.labels,
    required this.systolic,
    required this.diastolic,
    this.height = 110,
    this.maxValue = 190,
    this.systolicColor = const Color(0xFFE53935), // Rosso/Corallo chiaro per la Massima
    this.diastolicColor = const Color(0xFF1E88E5), // Blu per la Minima
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final safeMax = maxValue <= 0 ? 190.0 : maxValue;

    return SizedBox(
      height: height + 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) {
          final sys = i < systolic.length ? systolic[i] : 0;
          final dia = i < diastolic.length ? diastolic[i] : 0;
          final hasData = sys > 0 && dia > 0;

          final sysHeight = hasData ? (sys / safeMax * height).clamp(10.0, height) : 4.0;
          final diaHeight = hasData ? (dia / safeMax * height).clamp(8.0, height) : 4.0;

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
                        fontSize: 10.5,
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
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: height,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Colonna Sistolica (Massima)
                          Container(
                            width: 8,
                            height: sysHeight,
                            decoration: BoxDecoration(
                              color: systolicColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 3),
                          // Colonna Diastolica (Minima)
                          Container(
                            width: 8,
                            height: diaHeight,
                            decoration: BoxDecoration(
                              color: diastolicColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

/// Grafico a barre per la pressione arteriosa (alias retrocompatibile).
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
    this.height = 110,
    this.maxValue = 190,
  });

  @override
  Widget build(BuildContext context) {
    return BloodPressureGroupedBarChart(
      labels: labels,
      systolic: systolic,
      diastolic: diastolic,
      height: height,
      maxValue: maxValue,
    );
  }
}

class BloodPressureRangeChart extends StatelessWidget {
  final List<String> labels;
  final List<int> systolic;
  final List<int> diastolic;
  final double height;
  final double maxValue;

  const BloodPressureRangeChart({
    super.key,
    required this.labels,
    required this.systolic,
    required this.diastolic,
    this.height = 110,
    this.maxValue = 190,
  });

  @override
  Widget build(BuildContext context) {
    return BloodPressureGroupedBarChart(
      labels: labels,
      systolic: systolic,
      diastolic: diastolic,
      height: height,
      maxValue: maxValue,
    );
  }
}
