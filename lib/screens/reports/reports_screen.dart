import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reports_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_card.dart';
import '../../utils/date_format.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reports = context.watch<ReportsProvider>().reports;

    return AppScaffold(
      navIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('I Miei Referti', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/reports/add'),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Aggiungi Referto'),
            ),
          ),
          const SizedBox(height: 24),
          if (reports.isEmpty)
            Text('Nessun referto caricato.', style: theme.textTheme.bodyMedium)
          else
            for (final report in reports)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
                        child: Icon(Icons.description_outlined, color: cs.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.title, style: theme.textTheme.titleSmall),
                            Text(AppDateFormat.dayMonth(report.date), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle_rounded, color: cs.secondary),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
