import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/clinical_parameter.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/reports_provider.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/clinical_entry_sheet.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_card.dart';

enum ClinicalScreenView {
  valori,
  referti,
}

/// Schermata Esami: divisa tra "Valori clinici" (parametri di laboratorio)
/// e "Referti caricati" (archivio documenti PDF / immagini).
class ClinicalParametersScreen extends StatefulWidget {
  const ClinicalParametersScreen({super.key});

  @override
  State<ClinicalParametersScreen> createState() => _ClinicalParametersScreenState();
}

class _ClinicalParametersScreenState extends State<ClinicalParametersScreen> {
  ClinicalScreenView _currentView = ClinicalScreenView.valori;

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

  Widget _viewButton(String label, ClinicalScreenView value) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = _currentView == value;
    return GestureDetector(
      onTap: () {
        if (_currentView == value) return;
        setState(() => _currentView = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final clinical = context.watch<ClinicalProvider>();

    return AppScaffold(
      navIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(child: _viewButton('Valori clinici', ClinicalScreenView.valori)),
                Expanded(child: _viewButton('Referti caricati', ClinicalScreenView.referti)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_currentView == ClinicalScreenView.valori) ...[
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
          ] else ...[
            _ReportsTabSection(
              onAdd: () => Navigator.of(context).pushNamed('/reports/add'),
            ),
          ],
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
                minimumSize: const Size.fromHeight(42),
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  width: 1.3,
                ),
                backgroundColor: AppColors.lightPeach.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
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
class _ReportsTabSection extends StatefulWidget {
  final VoidCallback onAdd;

  const _ReportsTabSection({
    required this.onAdd,
  });

  @override
  State<_ReportsTabSection> createState() => _ReportsTabSectionState();
}

class _ReportsTabSectionState extends State<_ReportsTabSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceListening() async {
    final voice = context.read<VoiceService>();
    if (voice.isListening) {
      await voice.stopListening();
      return;
    }

    final started = await voice.startListening(
      onResult: (words) {
        if (!mounted) return;
        final clean = words.trim();
        setState(() {
          _searchController.text = clean;
          _searchQuery = clean.toLowerCase();
        });
      },
    );

    if (!started && mounted && voice.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(voice.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reportsProvider = context.watch<ReportsProvider>();
    final voice = context.watch<VoiceService>();
    final reports = reportsProvider.reports;

    // Filtra per titolo e limita agli ultimi 10
    final filteredReports = reports.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.title.toLowerCase().contains(_searchQuery);
    }).take(10).toList();

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
                'I miei referti',
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
                onTap: widget.onAdd,
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
        const SizedBox(height: 12),
        // Barra di ricerca con microfono vocale
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: voice.isListening
                  ? AppColors.accent
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: voice.isListening ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: voice.isListening ? 'Ascolto in corso...' : 'Cerca referto per titolo...',
                    hintStyle: TextStyle(
                      color: voice.isListening ? AppColors.accent : cs.onSurfaceVariant,
                      fontWeight: voice.isListening ? FontWeight.w600 : FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Cancella ricerca',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              IconButton(
                icon: Icon(
                  voice.isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: voice.isListening ? AppColors.accent : cs.onSurfaceVariant,
                ),
                tooltip: voice.isListening ? 'Ferma ascolto' : 'Cerca con la voce',
                onPressed: _toggleVoiceListening,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (reportsProvider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reports.isEmpty)
          SectionCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nessun referto presente. Puoi caricare un nuovo referto PDF o immagine con il pulsante "Aggiungi".',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else if (filteredReports.isEmpty)
          SectionCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.search_off_rounded, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nessun referto trovato per "$_searchQuery".',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Text('Annulla filtro'),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < filteredReports.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < filteredReports.length - 1 ? 10 : 0),
              child: SectionCard(
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
                      child: const Icon(Icons.description_outlined, color: AppColors.accent, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filteredReports[i].title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppDateFormat.dayMonthYear(filteredReports[i].date),
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
