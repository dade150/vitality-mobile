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
          _ReportsSection(
            onAdd: () => Navigator.of(context).pushNamed('/reports/add'),
            onOpenAll: () => Navigator.of(context).pushNamed('/reports/all'),
          ),
          const SizedBox(height: 16),
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
    final types = ClinicalParameterType.values.where((t) => t.profile == profile).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.lightPeach,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(profile.icon, color: AppColors.accent, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  profile.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < types.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < types.length - 1 ? 10 : 0),
              child: _ParameterCard(type: types[i], readings: clinical.history(types[i])),
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  type.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (reading != null) ...[
                const SizedBox(width: 8),
                Material(
                  color: cs.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _edit(context, reading),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_outlined, size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          const Text(
                            'Modifica',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (reading != null) ...[
            if (readings.length > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          AppDateFormat.dayMonthYear(reading.measuredOn),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ],
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
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      type.format(reading.value),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type.unit,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (olderReading != null)
                  _buildInlineDelta(context, type, reading, olderReading),
              ],
            ),
            if (readings.length == 1) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    AppDateFormat.dayMonthYear(reading.measuredOn),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ] else
            Text(
              'Nessun valore inserito',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Aggiungi misurazione'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  width: 1.3,
                ),
                backgroundColor: AppColors.lightPeach.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
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

    final IconData icon;
    final Color iconColor;
    final String text;

    if (diff == 0) {
      icon = Icons.trending_flat_rounded;
      iconColor = cs.onSurfaceVariant;
      text = 'Invariato';
    } else if (diff > 0) {
      icon = Icons.trending_up_rounded;
      iconColor = AppColors.accent;
      text = '$sign${type.format(diff)} ${type.unit}';
    } else {
      icon = Icons.trending_down_rounded;
      iconColor = const Color(0xFF2E7D32);
      text = '$sign${type.format(diff)} ${type.unit}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sezione Referti della tab: mostra in anteprima gli ultimi 3 referti caricati
/// con tasto Aggiungi rapido nell'intestazione e link allo storico completo.
class _ReportsSection extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onOpenAll;

  const _ReportsSection({
    required this.onAdd,
    required this.onOpenAll,
  });

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.lightPeach,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.description_outlined, color: AppColors.accent, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ultimi referti',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Material(
              color: cs.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
                      SizedBox(width: 4),
                      Text(
                        'Aggiungi',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          SectionCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Nessun referto caricato.', style: theme.textTheme.bodyMedium),
              ],
            ),
          )
        else ...[
          for (final report in recentReports)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.lightPeach,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.description_outlined, color: AppColors.accent, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
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
              ),
            ),
          if (reports.length > 3)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenAll,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Visualizza tutto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.45),
                    width: 1.3,
                  ),
                  backgroundColor: AppColors.lightPeach.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
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
      padding: const EdgeInsets.all(14),
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
