import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
      height: height + 54,
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: cs.onSurface,
                      ),
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
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 38,
                  height: 38,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

/// Grafico dell'andamento glicemico settimanale con linee guida target (70-180 mg/dL).
/// Mostra una linea continua ben visibile con punti e pill-badge per i giorni registrati:
/// i punti dentro il target sono in colore primario, quelli fuori sono evidenziati in rosso errore.
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
    this.height = 168,
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
        const SizedBox(height: 8),
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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

  static const double _topPadding = 26.0;
  static const double _bottomPadding = 14.0;

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
    final usableHeight = height - _topPadding - _bottomPadding;
    final clamped = val.clamp(minY, maxY);
    final fraction = (clamped - minY) / (maxY - minY);
    return _topPadding + (usableHeight - (fraction * usableHeight));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = values.length;
    if (count == 0) return;

    final stepX = size.width / count;
    final halfStep = stepX / 2;

    // 1. Fascia verde delicata per il Target Clinico (70-180 mg/dL raccomandato ADA/EASD)
    final isDark = theme.brightness == Brightness.dark;
    final yTargetMax = _getY(targetMax, size.height);
    final yTargetMin = _getY(targetMin, size.height);

    final targetRect = Rect.fromLTRB(0, yTargetMax, size.width, yTargetMin);
    final targetBandPaint = Paint()
      ..color = (isDark ? const Color(0xFF1B4D24) : const Color(0xFFDDF3DB)).withValues(alpha: isDark ? 0.3 : 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(8)),
      targetBandPaint,
    );

    final guidePaint = Paint()
      ..color = (isDark ? const Color(0xFF58D68D) : const Color(0xFF1B6D24)).withValues(alpha: 0.45)
      ..strokeWidth = 1.2;

    _drawDashedLine(canvas, Offset(0, yTargetMax), Offset(size.width, yTargetMax), guidePaint);
    _drawDashedLine(canvas, Offset(0, yTargetMin), Offset(size.width, yTargetMin), guidePaint);

    // Etichette target a destra con contrasto nitido
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF7DCE94) : const Color(0xFF196F3D),
    );
    _drawText(canvas, '180 max (target)', Offset(size.width - 100, yTargetMax - 15), labelStyle);
    _drawText(canvas, '70 min', Offset(size.width - 50, yTargetMin + 4), labelStyle);

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

      // Riempimento a gradiente sotto la curva glicemica
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, size.height - _bottomPadding)
        ..lineTo(points.first.dx, size.height - _bottomPadding)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primary.withValues(alpha: isDark ? 0.35 : 0.22),
            cs.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(0, _topPadding, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);

      final trendPaint = Paint()
        ..color = cs.primary
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, trendPaint);
    }

    // 3. Disegna i punti e i pill-badge con i valori numerici
    for (int idx = 0; idx < points.length; idx++) {
      final p = points[idx];
      final val = values[pointIndices[idx]]!;
      final isOutOfRange = val < targetMin || val > targetMax;
      final pointColor = isOutOfRange ? cs.error : cs.primary;

      // Cerchietto punto ingrandito per alta visibilità
      final circlePaint = Paint()
        ..color = pointColor
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = cs.surface
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(p, 7.5, circlePaint);
      canvas.drawCircle(p, 7.5, borderPaint);

      // Pill-Badge con valore numerico
      final valStr = val.round().toString();
      final valStyle = TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: isOutOfRange ? cs.onErrorContainer : cs.onSurface,
      );
      final textSpan = TextSpan(text: valStr, style: valStyle);
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      const padH = 6.0;
      const padV = 2.0;
      final badgeW = tp.width + (padH * 2);
      final badgeH = tp.height + (padV * 2);

      double badgeY = p.dy - badgeH - 10.0;
      if (badgeY < 2) {
        badgeY = p.dy + 11.0;
      }
      final badgeX = p.dx - (badgeW / 2);

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
        const Radius.circular(6),
      );

      final badgeBgPaint = Paint()
        ..color = isOutOfRange
            ? cs.errorContainer.withValues(alpha: 0.95)
            : cs.surfaceContainerHighest.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;

      final badgeBorderPaint = Paint()
        ..color = isOutOfRange
            ? cs.error.withValues(alpha: 0.6)
            : cs.outlineVariant.withValues(alpha: 0.8)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(badgeRect, badgeBgPaint);
      canvas.drawRRect(badgeRect, badgeBorderPaint);

      tp.paint(canvas, Offset(badgeX + padH, badgeY + padV));
    }

    // Per i giorni senza dato, disegna un trattino neutro
    for (int i = 0; i < count; i++) {
      if (values[i] == null) {
        final x = (i * stepX) + halfStep;
        final centerY = (yTargetMax + yTargetMin) / 2;
        final dashPaint = Paint()
          ..color = cs.outlineVariant.withValues(alpha: 0.5)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - 5, centerY), Offset(x + 5, centerY), dashPaint);
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
/// - Sistolica (Massima): colonna a sinistra (rosso/corallo)
/// - Diastolica (Minima): colonna a destra (blu)
/// Include numeri verticali separati ad alta leggibilità e ispezione interattiva del giorno al tocco.
class BloodPressureGroupedBarChart extends StatefulWidget {
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
  State<BloodPressureGroupedBarChart> createState() => _BloodPressureGroupedBarChartState();
}

class _BloodPressureGroupedBarChartState extends State<BloodPressureGroupedBarChart> {
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    // Seleziona di default l'ultimo giorno con misurazioni valide
    for (int i = widget.systolic.length - 1; i >= 0; i--) {
      if (widget.systolic[i] > 0 && (i < widget.diastolic.length && widget.diastolic[i] > 0)) {
        _selectedDayIndex = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final safeMax = widget.maxValue <= 0 ? 190.0 : widget.maxValue;
    final labels = widget.labels;
    final systolic = widget.systolic;
    final diastolic = widget.diastolic;
    final height = widget.height;

    final selIdx = _selectedDayIndex;
    final hasSelectedData = selIdx != null &&
        selIdx < systolic.length &&
        selIdx < diastolic.length &&
        systolic[selIdx] > 0 &&
        diastolic[selIdx] > 0;
    final selSys = hasSelectedData ? systolic[selIdx] : 0;
    final selDia = hasSelectedData ? diastolic[selIdx] : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height + 66,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(labels.length, (i) {
              final sys = i < systolic.length ? systolic[i] : 0;
              final dia = i < diastolic.length ? diastolic[i] : 0;
              final hasData = sys > 0 && dia > 0;
              final isSelected = _selectedDayIndex == i;

              final sysHeight = hasData ? (sys / safeMax * height).clamp(12.0, height) : 4.0;
              final diaHeight = hasData ? (dia / safeMax * height).clamp(10.0, height) : 4.0;

              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedDayIndex = i),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 1. Valori numerici separati e impilati verticalmente (leggibilità assoluta)
                        if (hasData) ...[
                          Text(
                            '$sys',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: widget.systolicColor,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$dia',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              color: widget.diastolicColor,
                              height: 1.1,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '-',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 14), // Mantiene la stessa altezza verticale di sys+dia
                        ],
                        const SizedBox(height: 6),

                        // 2. Colonne delle barre sistolica e diastolica
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
                                  width: 9,
                                  height: sysHeight,
                                  decoration: BoxDecoration(
                                    color: widget.systolicColor,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: widget.systolicColor.withValues(alpha: 0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, -1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                // Colonna Diastolica (Minima)
                                Container(
                                  width: 9,
                                  height: diaHeight,
                                  decoration: BoxDecoration(
                                    color: widget.diastolicColor,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: widget.diastolicColor.withValues(alpha: 0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, -1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),

                        // 3. Etichetta del giorno con pillola se selezionato
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? cs.surfaceContainerHigh : AppColors.lightPeach)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? cs.primary : AppColors.accent).withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            labels[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? cs.primary : AppColors.accentText)
                                  : cs.onSurface,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // 4. Banner di dettaglio interattivo del giorno toccato
        if (hasSelectedData)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainerHigh : AppColors.lightPeach.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (isDark ? cs.primary : AppColors.accent).withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: isDark ? cs.primary : AppColors.accentText,
                ),
                const SizedBox(width: 8),
                Text(
                  '${labels[selIdx!]}: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  '$selSys / $selDia mmHg',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? cs.primary : AppColors.accentText,
                    fontSize: 14.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'Max $selSys • Min $selDia',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
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
