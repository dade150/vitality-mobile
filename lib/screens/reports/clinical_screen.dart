import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/clinical_parameter.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/reports_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/clinical_entry_sheet.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_card.dart';

/// Parametri clinici "poco frequenti", divisi in tre profili
/// (glicemico, renale, lipidico). Ogni valore ha Aggiungi / Modifica,
/// navigazione `<` `>` tra le rilevazioni del singolo parametro e
/// un tasto Storico per il confronto visivo degli ultimi 3 esami e l'archivio referti.
/// Nessun dato fisso: tutto arriva da [ClinicalProvider] e [ReportsProvider].
class ClinicalParametersScreen extends StatefulWidget {
  const ClinicalParametersScreen({super.key});

  @override
  State<ClinicalParametersScreen> createState() => _ClinicalParametersScreenState();
}

class _ClinicalParametersScreenState extends State<ClinicalParametersScreen> {
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

  void _openHistory(BuildContext context) {
    Navigator.of(context).pushNamed('/reports/history');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clinical = context.watch<ClinicalProvider>();

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
                  'Parametri Clinici',
                  style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/reports/add'),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Aggiungi Referto'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openHistory(context),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Storico e Confronto Esami'),
            ),
          ),
          const SizedBox(height: 24),
          _ReportsSection(onOpenAll: () => _openHistory(context)),
          const SizedBox(height: 24),
          if (clinical.loadFailed) ...[
            _LoadErrorBanner(onRetry: clinical.refresh),
            const SizedBox(height: 16),
          ],
          if (!clinical.hasLoaded)
            if (clinical.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              const SizedBox.shrink()
          else
            for (final profile in ClinicalProfile.values)
              _ProfileSection(profile: profile, clinical: clinical),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final ClinicalProfile profile;
  final ClinicalProvider clinical;

  const _ProfileSection({required this.profile, required this.clinical});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final types = ClinicalParameterType.values.where((t) => t.profile == profile);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Icon(profile.icon, size: 32, color: cs.primary),
                const SizedBox(width: 12),
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
          ),
          const SizedBox(height: 12),
          for (final type in types)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ParameterCard(type: type, readings: clinical.history(type)),
            ),
        ],
      ),
    );
  }
}

class _ParameterCard extends StatefulWidget {
  final ClinicalParameterType type;
  final List<ClinicalReading> readings;

  const _ParameterCard({required this.type, required this.readings});

  @override
  State<_ParameterCard> createState() => _ParameterCardState();
}

class _ParameterCardState extends State<_ParameterCard> {
  /// Indice nella lista `readings` (0 = esame più recente, 1 = precedente, ecc.).
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant _ParameterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.readings.length) {
      _selectedIndex = widget.readings.isEmpty ? 0 : widget.readings.length - 1;
    }
  }

  void _add(BuildContext context) {
    final provider = context.read<ClinicalProvider>();
    showClinicalEntrySheet(
      context: context,
      type: widget.type,
      onSave: (value, date) async {
        final ok = await provider.addReading(widget.type, value, date);
        if (ok && mounted) setState(() => _selectedIndex = 0);
        return ok;
      },
      errorMessage: () => provider.errorMessage,
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final type = widget.type;
    final readings = widget.readings;
    final safeIndex = readings.isEmpty ? 0 : _selectedIndex.clamp(0, readings.length - 1);
    final reading = readings.isEmpty ? null : readings[safeIndex];
    final olderReading = (readings.length > safeIndex + 1) ? readings[safeIndex + 1] : null;

    // `<` va indietro nel tempo (indice più alto), `>` torna verso il più recente (indice più basso)
    final canGoOlder = safeIndex < readings.length - 1;
    final canGoNewer = safeIndex > 0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                child: Icon(type.icon, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: theme.textTheme.titleMedium),
                    Text(type.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (reading != null) ...[
            if (readings.length > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Esame precedente',
                      onPressed: canGoOlder ? () => setState(() => _selectedIndex = safeIndex + 1) : null,
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: canGoOlder
                            ? AppColors.accent
                            : cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        safeIndex == 0
                            ? 'Ultimo esame (1 di ${readings.length})'
                            : 'Esame precedente (${safeIndex + 1} di ${readings.length})',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: safeIndex == 0 ? AppColors.accent : cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Esame successivo',
                      onPressed: canGoNewer ? () => setState(() => _selectedIndex = safeIndex - 1) : null,
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: canGoNewer
                            ? AppColors.accent
                            : cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  type.format(reading.value),
                  style: theme.textTheme.displaySmall?.copyWith(color: cs.primary),
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(type.unit, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Misurato il ${AppDateFormat.dayMonthYear(reading.measuredOn)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (olderReading != null) ...[
              const SizedBox(height: 6),
              _buildInlineDelta(context, type, reading, olderReading),
            ],
          ] else
            Text(
              'Nessun valore inserito',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PillButton(
                label: 'Aggiungi',
                icon: Icons.add_rounded,
                filled: true,
                onTap: () => _add(context),
              ),
              if (reading != null)
                PillButton(
                  label: 'Modifica',
                  icon: Icons.edit_outlined,
                  onTap: () => _edit(context, reading),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineDelta(
    BuildContext context,
    ClinicalParameterType type,
    ClinicalReading current,
    ClinicalReading previous,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final diff = type.round(current.value - previous.value);
    final sign = diff > 0 ? '+' : '';
    final label = diff == 0
        ? 'Invariato rispetto al ${AppDateFormat.dayMonthYear(previous.measuredOn)} (${type.format(previous.value)} ${type.unit})'
        : 'Rispetto al ${AppDateFormat.dayMonthYear(previous.measuredOn)}: $sign${type.format(diff)} ${type.unit} (era ${type.format(previous.value)} ${type.unit})';

    return Row(
      children: [
        Icon(
          diff == 0
              ? Icons.trending_flat_rounded
              : (diff > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded),
          size: 18,
          color: AppColors.accent,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sezione Referti della tab: mostra in anteprima gli ultimi 3 referti caricati
/// e permette di aprire l'archivio completo.
class _ReportsSection extends StatelessWidget {
  final VoidCallback onOpenAll;
  const _ReportsSection({required this.onOpenAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reports = context.watch<ReportsProvider>().reports;
    final recentReports = reports.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'I Miei Referti',
              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.accent),
            ),
            if (reports.length > 3)
              TextButton.icon(
                onPressed: onOpenAll,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: Text('Vedi tutti (${reports.length})'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          Text('Nessun referto caricato.', style: theme.textTheme.bodyMedium)
        else ...[
          for (final report in recentReports)
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
              ),
            ),
          if (reports.length > 3)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenAll,
                icon: const Icon(Icons.list_alt_rounded),
                label: Text('Mostra tutti i ${reports.length} referti'),
              ),
            ),
        ],
      ],
    );
  }
}

class _LoadErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Non riesco a caricare i tuoi dati. Controlla la connessione.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PillButton(label: 'Riprova', icon: Icons.refresh_rounded, filled: true, onTap: onRetry),
        ],
      ),
    );
  }
}
