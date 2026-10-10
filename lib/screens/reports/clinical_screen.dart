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
/// (glicemico, renale, lipidico). Ogni valore ha Aggiungi / Modifica; un unico tasto Storico vale per tutti.
/// Nessun dato fisso: tutto arriva da [ClinicalProvider].
///
/// In testa c'è anche la sezione Referti (storica della tab), con il tasto
/// "Aggiungi Referto" che apre la route `/reports/add`.
class ClinicalParametersScreen extends StatefulWidget {
  const ClinicalParametersScreen({super.key});

  @override
  State<ClinicalParametersScreen> createState() => _ClinicalParametersScreenState();
}

class _ClinicalParametersScreenState extends State<ClinicalParametersScreen> {
  @override
  void initState() {
    super.initState();
    // Rete di sicurezza (stessa del Diario): se i dati non sono ancora stati
    // caricati, li carica ora.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final clinical = context.read<ClinicalProvider>();
      if (!clinical.hasLoaded && !clinical.isLoading) clinical.refresh();
    });
  }

  /// TODO(storico): tasto UNICO per tutti i parametri. Aprire la schermata
  /// dello storico (es. `Navigator.pushNamed(context, '/reports/parameters/history')`):
  /// lì si leggerà `context.read<ClinicalProvider>().history(type)` per ogni
  /// [ClinicalParameterType] (raggruppabile per `type.profile`), e ogni riga
  /// potrà riusare `showClinicalEntrySheet(existing: ...)` per modificare
  /// o eliminare i valori più vecchi. Per ora è solo il tasto predisposto.
  void _openHistory(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lo storico sarà disponibile a breve.')),
    );
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
                child: Text('Parametri Clinici',
                    style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
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
              label: const Text('Storico'),
            ),
          ),
          const SizedBox(height: 24),
          const _ReportsSection(),
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
              child: _ParameterCard(type: type, latest: clinical.latest(type)),
            ),
        ],
      ),
    );
  }
}

class _ParameterCard extends StatelessWidget {
  final ClinicalParameterType type;
  final ClinicalReading? latest;

  const _ParameterCard({required this.type, required this.latest});

  void _add(BuildContext context) {
    final provider = context.read<ClinicalProvider>();
    showClinicalEntrySheet(
      context: context,
      type: type,
      onSave: (value, date) => provider.addReading(type, value, date),
      errorMessage: () => provider.errorMessage,
    );
  }

  void _edit(BuildContext context, ClinicalReading reading) {
    final provider = context.read<ClinicalProvider>();
    showClinicalEntrySheet(
      context: context,
      type: type,
      existing: reading,
      onSave: (value, date) => provider.updateReading(reading.id, type, value, date),
      onDelete: () => provider.deleteReading(reading.id),
      errorMessage: () => provider.errorMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reading = latest;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(type.format(reading.value),
                    style: theme.textTheme.displaySmall?.copyWith(color: cs.primary)),
                const SizedBox(width: 8),
                Flexible(child: Text(type.unit, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Misurato il ${AppDateFormat.dayMonthYear(reading.measuredOn)}',
                style: theme.textTheme.bodyMedium),
          ] else
            Text('Nessun valore inserito',
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
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
}

/// Sezione Referti della tab: elenca i referti caricati (stessa lista che
/// mostrava la vecchia ReportsScreen) e non contiene dati clinici grezzi.
class _ReportsSection extends StatelessWidget {
  const _ReportsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reports = context.watch<ReportsProvider>().reports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I Miei Referti',
            style: theme.textTheme.titleLarge?.copyWith(color: AppColors.accent)),
        const SizedBox(height: 12),
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
                          Text(AppDateFormat.dayMonth(report.date),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle_rounded, color: cs.secondary),
                  ],
                ),
              ),
            ),
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
                child: Text('Non riesco a caricare i tuoi dati. Controlla la connessione.',
                    style: theme.textTheme.bodyMedium),
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