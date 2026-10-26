import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/clinical_parameter.dart';
import '../../models/medical_report.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/reports_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/clinical_entry_sheet.dart';
import '../../widgets/section_card.dart';
import '../../widgets/simple_charts.dart';

/// Schermata dedicata allo Storico dei Referti e al Confronto nel tempo
/// dei Parametri Clinici (HbA1c, funzionalità renale, profilo lipidico).
///
/// Poiché questi esami vengono svolti a distanza di mesi, il confronto
/// mostra gli ultimi 2-3 esami registrati affiancati in ordine cronologico,
/// oltre all'elenco completo modificabile di tutte le rilevazioni.
class ClinicalHistoryScreen extends StatefulWidget {
  const ClinicalHistoryScreen({super.key});

  @override
  State<ClinicalHistoryScreen> createState() => _ClinicalHistoryScreenState();
}

class _ClinicalHistoryScreenState extends State<ClinicalHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final clinical = context.read<ClinicalProvider>();
      if (!clinical.hasLoaded && !clinical.isLoading) clinical.refresh();
      final reports = context.read<ReportsProvider>();
      if (!reports.hasLoaded && !reports.isLoading) reports.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clinical = context.watch<ClinicalProvider>();
    final reports = context.watch<ReportsProvider>();

    return AppScaffold(
      navIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Indietro',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  'Storico Esami e Referti',
                  style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Confronta gli ultimi esami del sangue e consulta l\'archivio completo dei tuoi referti.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _AllReportsSection(reports: reports.reports),
          const SizedBox(height: 24),
          if (clinical.isLoading && !clinical.hasLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final profile in ClinicalProfile.values)
              _ProfileHistorySection(profile: profile, clinical: clinical),
        ],
      ),
    );
  }
}

class _AllReportsSection extends StatefulWidget {
  final List<MedicalReport> reports;
  const _AllReportsSection({required this.reports});

  @override
  State<_AllReportsSection> createState() => _AllReportsSectionState();
}

class _AllReportsSectionState extends State<_AllReportsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reports = widget.reports;
    final visible = _expanded ? reports : reports.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Archivio Referti (${reports.length})',
              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.accent),
            ),
            if (reports.length > 4)
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                label: Text(_expanded ? 'Mostra meno' : 'Vedi tutti (${reports.length})'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          SectionCard(
            child: Text(
              'Nessun referto caricato nello storico.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final report in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
                          child: Icon(Icons.description_outlined, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(report.title, style: theme.textTheme.titleSmall),
                              Text(
                                AppDateFormat.dayMonthYear(report.date),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.check_circle_rounded, color: cs.secondary),
                      ],
                    ),
                    if (report.extractedParams.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final e in report.extractedParams.entries)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${e.key}: ${e.value}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _ProfileHistorySection extends StatelessWidget {
  final ClinicalProfile profile;
  final ClinicalProvider clinical;

  const _ProfileHistorySection({required this.profile, required this.clinical});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final types = ClinicalParameterType.values.where((t) => t.profile == profile);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(profile.icon, size: 30, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.title, style: theme.textTheme.titleLarge),
                    Text(profile.subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final type in types)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ParameterHistoryCard(
                type: type,
                readings: clinical.history(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _ParameterHistoryCard extends StatefulWidget {
  final ClinicalParameterType type;
  final List<ClinicalReading> readings;

  const _ParameterHistoryCard({
    required this.type,
    required this.readings,
  });

  @override
  State<_ParameterHistoryCard> createState() => _ParameterHistoryCardState();
}

class _ParameterHistoryCardState extends State<_ParameterHistoryCard> {
  bool _showAll = false;

  void _edit(BuildContext context, ClinicalReading reading) {
    final provider = context.read<ClinicalProvider>();
    showClinicalEntrySheet(
      context: context,
      type: widget.type,
      existing: reading,
      onSave: (value, date) => provider.updateReading(reading.id, widget.type, value, date),
      onDelete: () => provider.deleteReading(reading.id),
      errorMessage: () => provider.errorMessage,
    );
  }

  String _shortExamDate(DateTime d) =>
      '${AppDateFormat.daySmall(d)} ${AppDateFormat.monthShort(d)} \'${(d.year % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final type = widget.type;
    final readings = widget.readings;

    // Ultimi 3 esami in ordine cronologico (dal meno recente al più recente) per il grafico di confronto
    final lastThreeChrono = readings.take(3).toList().reversed.toList();
    final chartLabels = lastThreeChrono.map((r) => _shortExamDate(r.measuredOn)).toList();
    final chartValues = lastThreeChrono.map<double?>((r) => type.round(r.value)).toList();
    final maxVal = lastThreeChrono.isEmpty
        ? type.max
        : lastThreeChrono.map((r) => r.value).reduce(math.max) * 1.15;

    final visibleList = _showAll ? readings : readings.take(3).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                child: Icon(type.icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: theme.textTheme.titleMedium),
                    Text(
                      readings.isEmpty
                          ? 'Nessun esame registrato'
                          : '${readings.length} ${readings.length == 1 ? 'esame registrato' : 'esami registrati'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (readings.isEmpty)
            Text(
              'Nessun valore nello storico per ${type.label}.',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            )
          else ...[
            if (readings.length >= 2) ...[
              Text(
                'Confronto ultimi ${lastThreeChrono.length} esami (${type.unit})',
                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              SimpleBarChart(
                labels: chartLabels,
                values: chartValues,
                maxValue: maxVal,
                color: cs.primary,
                height: 100,
                valueSuffix: type.unit == '%' ? '%' : '',
                showZeroAsDash: false,
              ),
              const SizedBox(height: 8),
              _DeltaComparisonBanner(
                type: type,
                latest: readings[0],
                previous: readings[1],
              ),
              const SizedBox(height: 12),
              const Divider(),
            ],
            for (int i = 0; i < visibleList.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${type.format(visibleList[i].value)} ${type.unit}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: i == 0 ? cs.primary : cs.onSurface,
                                ),
                              ),
                              if (i == 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Ultimo',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Esame del ${AppDateFormat.dayMonthYear(visibleList[i].measuredOn)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _edit(context, visibleList[i]),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifica'),
                    ),
                  ],
                ),
              ),
            if (readings.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  icon: Icon(_showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                  label: Text(
                    _showAll
                        ? 'Mostra solo gli ultimi 3'
                        : 'Mostra tutti gli esami (${readings.length})',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DeltaComparisonBanner extends StatelessWidget {
  final ClinicalParameterType type;
  final ClinicalReading latest;
  final ClinicalReading previous;

  const _DeltaComparisonBanner({
    required this.type,
    required this.latest,
    required this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final diff = type.round(latest.value - previous.value);
    final sign = diff > 0 ? '+' : '';
    final diffText = diff == 0
        ? 'Invariato rispetto al ${AppDateFormat.dayMonthYear(previous.measuredOn)}'
        : 'Variazione: $sign${type.format(diff)} ${type.unit} rispetto al ${AppDateFormat.dayMonthYear(previous.measuredOn)} (${type.format(previous.value)} ${type.unit})';

    final IconData trendIcon;
    if (diff == 0) {
      trendIcon = Icons.trending_flat_rounded;
    } else if (diff > 0) {
      trendIcon = Icons.trending_up_rounded;
    } else {
      trendIcon = Icons.trending_down_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(trendIcon, size: 20, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              diffText,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
