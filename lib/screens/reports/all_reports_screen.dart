import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/reports_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/section_card.dart';

/// Schermata con l'archivio completo di tutti i referti medici caricati.
class AllReportsScreen extends StatelessWidget {
  const AllReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reportsProvider = context.watch<ReportsProvider>();
    final reports = reportsProvider.reports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutti i Referti'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Aggiungi referto',
            onPressed: () => Navigator.of(context).pushNamed('/reports/add'),
          ),
        ],
      ),
      body: reportsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun referto presente',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Carica un nuovo referto PDF o immagine tramite il tasto + in alto.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final report = reports[index];
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
                            child: const Icon(Icons.description_outlined, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppDateFormat.dayMonthYear(report.date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.check_circle_rounded, color: cs.secondary, size: 20),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
