import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/meal_entry.dart';
import '../../models/therapy_item.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/entry_edit_sheet.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_card.dart';
import '../../utils/date_format.dart';
import '../../theme/app_colors.dart';

/// Converte il testo di un campo numerico in `double`, tollerando la virgola
/// decimale tipica della tastiera italiana.
double? _parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Rete di sicurezza: se per qualunque motivo i dati non sono ancora
    // stati caricati, li carica ora.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final health = context.read<HealthProvider>();
      if (!health.hasLoaded && !health.isLoading) health.refresh();
    });
  }

  // ------------------------------------------------------------ Utilità

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday => _sameDay(_selectedDate, DateTime.now());

  DateTime get _dayEnd => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1);

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatWhen(DateTime t) {
    final now = DateTime.now();
    if (_sameDay(t, now)) return _hhmm(t);
    if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Ieri ${_hhmm(t)}';
    return '${AppDateFormat.weekdayShort(t)} ${_hhmm(t)}';
  }

  String _fmtNum(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _changeDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    context.read<HealthProvider>().ensureLoaded(_selectedDate);
  }

  /// Ultimo elemento registrato fino alla fine del giorno selezionato.
  T? _lastUpTo<T>(List<T> items, DateTime Function(T) timeOf) {
    for (var i = items.length - 1; i >= 0; i--) {
      if (timeOf(items[i]).isBefore(_dayEnd)) return items[i];
    }
    return null;
  }

  /// Data/ora con cui salvare un nuovo dato: adesso se il giorno è oggi,
  /// altrimenti il giorno selezionato con l'ora corrente. Null se futuro.
  DateTime? _addTimestamp() {
    final now = DateTime.now();
    if (_isToday) return now;
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (dayStart.isAfter(now)) return null;
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute);
  }

  DateTime? _timestampOrWarn() {
    final when = _addTimestamp();
    if (when == null) _showMessage('Non puoi aggiungere dati in una data futura.');
    return when;
  }

  // ------------------------------------------------- Dialog di inserimento

  Future<void> _showAddDialog({
    required String title,
    required List<String> labels,
    required bool decimal,
    required String? Function(List<double?> values) validate,
    required Future<bool> Function(List<double> values) onSave,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddEntryDialog(
        title: title,
        labels: labels,
        decimal: decimal,
        validate: validate,
        onSave: onSave,
      ),
    );
  }

  void _addGlucose() {
    final when = _timestampOrWarn();
    if (when == null) return;
    final health = context.read<HealthProvider>();
    _showAddDialog(
      title: 'Aggiungi Glicemia',
      labels: const ['mg/dL'],
      decimal: true,
      validate: (v) => (v[0] == null || v[0]! < 20 || v[0]! > 600)
          ? 'Inserisci un valore tra 20 e 600 mg/dL'
          : null,
      onSave: (v) => health.addGlucoseReading(v[0], at: when),
    );
  }

  void _addPressure() {
    final when = _timestampOrWarn();
    if (when == null) return;
    final health = context.read<HealthProvider>();
    _showAddDialog(
      title: 'Aggiungi Pressione',
      labels: const ['Sistolica', 'Diastolica'],
      decimal: false,
      validate: (v) {
        final sys = v[0], dia = v[1];
        if (sys == null || dia == null) return 'Compila entrambi i valori';
        if (sys < 50 || sys > 260) return 'Sistolica: valore tra 50 e 260';
        if (dia < 30 || dia > 150) return 'Diastolica: valore tra 30 e 150';
        if (sys <= dia) return 'La sistolica deve essere maggiore della diastolica';
        return null;
      },
      onSave: (v) => health.addPressureReading(v[0].round(), v[1].round(), at: when),
    );
  }

  void _addMeal() {
    final when = _timestampOrWarn();
    if (when == null) return;
    Navigator.of(context).pushNamed('/diary/add-meal', arguments: when);
  }

  void _addActivity() {
    final when = _timestampOrWarn();
    if (when == null) return;
    Navigator.of(context).pushNamed('/diary/add-activity', arguments: when);
  }

  // ------------------------------------------------- Fogli di modifica

  void _editGlucose() {
    final health = context.read<HealthProvider>();
    final items = health.glucoseReadings
        .where((r) => r.id != null && _sameDay(r.time, _selectedDate))
        .toList()
        .reversed
        .toList();
    if (items.isEmpty) {
      _showMessage('Nessuna misurazione da modificare in questa giornata.');
      return;
    }
    showEditEntriesSheet(
      context: context,
      title: 'Modifica glicemia',
      deleteLabel: 'Elimina questa misurazione',
      entries: [
        for (final r in items)
          EditableEntry(
            id: r.id!,
            title: '${_fmtNum(r.value)} mg/dL',
            subtitle: 'Ore ${_hhmm(r.time)}',
            fields: [
              EntryField(
                label: 'mg/dL',
                initialValue: _fmtNum(r.value),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
      ],
      validate: (e, v) {
        final x = _parseNumber(v[0]);
        return (x == null || x < 20 || x > 600) ? 'Inserisci un valore tra 20 e 600 mg/dL' : null;
      },
      onSave: (e, v) => health.updateGlucose(e.id, _parseNumber(v[0])!),
      onDelete: (e) => health.deleteGlucose(e.id),
    );
  }

  void _editPressure() {
    final health = context.read<HealthProvider>();
    final items = health.pressureReadings
        .where((r) => r.id != null && _sameDay(r.time, _selectedDate))
        .toList()
        .reversed
        .toList();
    if (items.isEmpty) {
      _showMessage('Nessuna misurazione da modificare in questa giornata.');
      return;
    }
    showEditEntriesSheet(
      context: context,
      title: 'Modifica pressione',
      deleteLabel: 'Elimina questa misurazione',
      entries: [
        for (final r in items)
          EditableEntry(
            id: r.id!,
            title: '${r.systolic} / ${r.diastolic} mmHg',
            subtitle: 'Ore ${_hhmm(r.time)}',
            fields: [
              EntryField(label: 'Sistolica', initialValue: '${r.systolic}'),
              EntryField(label: 'Diastolica', initialValue: '${r.diastolic}'),
            ],
          ),
      ],
      validate: (e, v) {
        final sys = int.tryParse(v[0]);
        final dia = int.tryParse(v[1]);
        if (sys == null || dia == null) return 'Compila entrambi i valori';
        if (sys < 50 || sys > 260) return 'Sistolica: valore tra 50 e 260';
        if (dia < 30 || dia > 150) return 'Diastolica: valore tra 30 e 150';
        if (sys <= dia) return 'La sistolica deve essere maggiore della diastolica';
        return null;
      },
      onSave: (e, v) => health.updatePressure(e.id, int.parse(v[0]), int.parse(v[1])),
      onDelete: (e) => health.deletePressure(e.id),
    );
  }

  void _editMeals() {
    final health = context.read<HealthProvider>();
    final items = health.mealEntries
        .where((m) => m.id != null && _sameDay(m.date, _selectedDate))
        .toList();
    if (items.isEmpty) {
      _showMessage('Nessun pasto da modificare in questa giornata.');
      return;
    }
    showEditEntriesSheet(
      context: context,
      title: 'Modifica pasti',
      deleteLabel: 'Elimina questo pasto',
      entries: [
        for (final m in items)
          EditableEntry(
            id: m.id!,
            title: m.type.label,
            subtitle: '${m.description} · ${m.isEstimated ? '~' : ''}${m.calories} kcal',
            fields: [
              EntryField(
                label: 'Cosa hai mangiato?',
                initialValue: m.description,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),
              EntryField(label: 'Calorie (kcal)', initialValue: '${m.calories}'),
            ],
          ),
      ],
      validate: (e, v) {
        if (v[0].isEmpty) return 'Inserisci una descrizione';
        if (v[0].length > 500) return 'Descrizione troppo lunga (massimo 500 caratteri)';
        final kcal = int.tryParse(v[1]);
        if (kcal == null || kcal < 0 || kcal > 10000) return 'Calorie: valore tra 0 e 10000';
        return null;
      },
      onSave: (e, v) => health.updateMeal(e.id, description: v[0], calories: int.parse(v[1])),
      onDelete: (e) => health.deleteMeal(e.id),
    );
  }

  void _editActivities() {
    final health = context.read<HealthProvider>();
    final items = health.activityEntries
        .where((a) => a.id != null && _sameDay(a.date, _selectedDate))
        .toList();
    if (items.isEmpty) {
      _showMessage('Nessuna attività da modificare in questa giornata.');
      return;
    }
    showEditEntriesSheet(
      context: context,
      title: 'Modifica attività',
      deleteLabel: 'Elimina questa attività',
      entries: [
        for (final a in items)
          EditableEntry(
            id: a.id!,
            title: '${a.type} · ${a.minutes} min',
            subtitle: a.steps > 0 ? '${a.steps} passi' : 'Ore ${_hhmm(a.date)}',
            fields: [
              EntryField(label: 'Durata (minuti)', initialValue: '${a.minutes}'),
              EntryField(label: 'Passi (opzionale)', initialValue: a.steps > 0 ? '${a.steps}' : ''),
            ],
          ),
      ],
      validate: (e, v) {
        final min = int.tryParse(v[0]);
        if (min == null || min < 1 || min > 1440) return 'Durata: valore tra 1 e 1440 minuti';
        if (v[1].isNotEmpty) {
          final steps = int.tryParse(v[1]);
          if (steps == null || steps < 0 || steps > 200000) return 'Passi: valore tra 0 e 200000';
        }
        return null;
      },
      onSave: (e, v) => health.updateActivity(
        e.id,
        minutes: int.parse(v[0]),
        steps: v[1].isEmpty ? 0 : int.parse(v[1]),
      ),
      onDelete: (e) => health.deleteActivity(e.id),
    );
  }

  // ---------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final health = context.watch<HealthProvider>();

    return AppScaffold(
      navIndex: 1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Il mio Diario',
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Storico',
                  icon: Icons.history_rounded,
                  onTap: () => Navigator.of(context).pushNamed('/history'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  label: 'Profilo',
                  icon: Icons.person_outline_rounded,
                  onTap: () => Navigator.of(context).pushNamed('/profile'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeDay(-1),
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.accent),
                ),
                Column(
                  children: [
                    Text(
                      _isToday ? 'Oggi' : AppDateFormat.weekdayShort(_selectedDate),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(AppDateFormat.dayMonth(_selectedDate), style: theme.textTheme.bodyMedium),
                  ],
                ),
                IconButton(
                  onPressed: () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
                ),
              ],
            ),
          ),
          if (health.isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (health.loadFailed) ...[
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Impossibile caricare i dati.', style: theme.textTheme.bodyMedium),
                  ),
                  TextButton(onPressed: health.refresh, child: const Text('Riprova')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (settings.isSectionVisible('terapia')) ...[
            _buildTerapiaSection(context, health),
            const SizedBox(height: 20),
          ],
          if (settings.isSectionVisible('glicemia')) ...[
            _buildGlicemiaSection(context, health),
            const SizedBox(height: 20),
          ],
          if (settings.isSectionVisible('pressione')) ...[
            _buildPressioneSection(context, health),
            const SizedBox(height: 20),
          ],
          if (settings.isSectionVisible('pasti')) ...[
            _buildPastiSection(context, health),
            const SizedBox(height: 20),
          ],
          if (settings.isSectionVisible('attivita')) ...[
            _buildAttivitaSection(context, health),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Terapia

  Widget _buildTerapiaSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPast = _dayEnd.isBefore(DateTime.now()) || _dayEnd.isAtSameMomentAs(DateTime.now());

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.medication_outlined,
            iconColor: cs.tertiary,
            iconBg: cs.tertiaryContainer,
            title: 'Terapia',
            onEdit: () => Navigator.of(context).pushNamed('/settings/therapy'),
          ),
          const SizedBox(height: 16),
          if (health.therapyItems.isEmpty)
            Text('Nessuna terapia registrata.',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
          else
            for (final item in health.therapyItems)
              _buildTherapyRow(context, health, item, isPast),
        ],
      ),
    );
  }

  Widget _buildTherapyRow(BuildContext context, HealthProvider health, TherapyItem item, bool isPast) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final taken = health.isTherapyTaken(item.id, _selectedDate);

    String statusText;
    if (taken) {
      statusText = '${item.time} - Presa';
    } else if (isPast) {
      statusText = '${item.time} - Non registrata';
    } else {
      statusText = item.time;
    }

    Widget? trailing;
    if (_isToday && !taken) {
      final busy = health.isTherapyToggling(item.id);
      trailing = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: const StadiumBorder(),
          ),
          onPressed: busy
              ? null
              : () async {
                  final provider = context.read<HealthProvider>();
                  final ok = await provider.toggleTherapyTaken(item.id);
                  if (!ok && mounted && !provider.isTherapyToggling(item.id)) {
                    _showMessage('Salvataggio non riuscito. Riprova.');
                  }
                },
          child: const Text('Segna come presa', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        ),
      );
    } else if (_isToday && taken) {
      final busy = health.isTherapyToggling(item.id);
      trailing = TextButton(
        onPressed: busy
            ? null
            : () async {
                final provider = context.read<HealthProvider>();
                final ok = await provider.toggleTherapyTaken(item.id);
                if (!ok && mounted && !provider.isTherapyToggling(item.id)) {
                  _showMessage('Operazione non riuscita. Riprova.');
                }
              },
        child: const Text('Annulla'),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: taken || isPast ? cs.surfaceContainerHigh : cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: taken || isPast ? cs.outlineVariant : cs.primary.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              taken ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 32,
              color: taken ? cs.secondary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleSmall),
                  Text(
                    statusText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: (taken || isPast) ? cs.onSurfaceVariant : AppColors.accent,
                      fontWeight: (taken || isPast) ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Glicemia

  Widget _buildGlicemiaSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reading = _lastUpTo(health.glucoseReadings, (r) => r.time);

    return SectionCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.water_drop_outlined,
            iconColor: cs.primary,
            iconBg: cs.primaryContainer,
            title: 'Glicemia',
            onEdit: _editGlucose,
            onAdd: _addGlucose,
          ),
          const SizedBox(height: 12),
          if (reading == null)
            Text('Non è presente alcuna misurazione', style: theme.textTheme.bodyMedium)
          else ...[
            _ValueLine(value: _fmtNum(reading.value), unit: 'mg/dL', color: AppColors.accent),
            const SizedBox(height: 4),
            Text('Ultima misurazione: ${_formatWhen(reading.time)}', style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Pressione

  Widget _buildPressioneSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reading = _lastUpTo(health.pressureReadings, (r) => r.time);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.favorite_outline_rounded,
            iconColor: cs.secondary,
            iconBg: cs.secondaryContainer,
            title: 'Pressione Arteriosa',
            onEdit: _editPressure,
            onAdd: _addPressure,
          ),
          const SizedBox(height: 12),
          if (reading == null)
            Text('Non è presente alcuna misurazione', style: theme.textTheme.bodyMedium)
          else ...[
            _ValueLine(
              value: '${reading.systolic} / ${reading.diastolic}',
              unit: 'mmHg',
              color: cs.onSurface,
            ),
            const SizedBox(height: 4),
            Text('Ultima misurazione: ${_formatWhen(reading.time)}', style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Pasti

  Widget _buildPastiSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final meals = health.mealEntries.where((m) => _sameDay(m.date, _selectedDate)).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.restaurant_outlined,
            iconColor: cs.secondary,
            iconBg: cs.secondaryContainer,
            title: 'Pasti',
            onEdit: _editMeals,
            onAdd: _addMeal,
          ),
          const SizedBox(height: 12),
          if (meals.isEmpty)
            Text('Nessun pasto registrato', style: theme.textTheme.bodyMedium)
          else
            for (final m in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: m.type.label,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' · ${m.description}'),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${m.isEstimated ? '~' : ''}${m.calories} kcal',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Attività

  Widget _buildAttivitaSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = health.activityEntries.where((a) => _sameDay(a.date, _selectedDate)).toList();
    final steps = entries.fold<int>(0, (s, a) => s + a.steps);
    final minutes = entries.fold<int>(0, (s, a) => s + a.minutes);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.directions_walk_rounded,
            iconColor: cs.tertiary,
            iconBg: cs.tertiaryContainer,
            title: 'Attività',
            onEdit: _editActivities,
            onAdd: _addActivity,
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text('Nessuna attività registrata', style: theme.textTheme.bodyMedium)
          else ...[
            if (steps > 0) _ValueLine(value: '$steps', unit: 'passi', color: cs.tertiary),
            Text('$minutes minuti di attività', style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Dialog modale di inserimento per glicemia e pressione.
///
/// Possiede i propri [TextEditingController] e li smonta nel proprio
/// [dispose], cioè quando il dialogo viene davvero smontato dall'albero e non
/// immediatamente dopo il pop (durante l'animazione di uscita).
///
/// Mentre il salvataggio è in corso la [PopScope] blocca back e barriera, così
/// l'utente non può chiudere il dialogo durante l'await e la chiusura avviene
/// solo ed esclusivamente su questa route: un pop incondizionato dopo
/// `await onSave` chiuderebbe invece la schermata sottostante.
class _AddEntryDialog extends StatefulWidget {
  const _AddEntryDialog({
    required this.title,
    required this.labels,
    required this.decimal,
    required this.validate,
    required this.onSave,
  });

  final String title;
  final List<String> labels;
  final bool decimal;
  final String? Function(List<double?> values) validate;
  final Future<bool> Function(List<double> values) onSave;

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  late final List<TextEditingController> _controllers;
  bool _busy = false;
  String? _error;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _controllers = [for (final _ in widget.labels) TextEditingController()];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = _controllers.map((c) => _parseNumber(c.text)).toList();
    final msg = widget.validate(values);
    if (msg != null) {
      setState(() => _error = msg);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onSave(values.cast<double>());
    if (!mounted) return;
    if (ok) {
      // Chiude solo questo dialogo: se è già stato chiuso nel frattempo, un
      // pop incondizionato chiuderebbe la schermata sottostante.
      if (_route?.isCurrent ?? false) Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = 'Salvataggio non riuscito. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controllers[i],
                      autofocus: i == 0,
                      enabled: !_busy,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: widget.decimal),
                      decoration: InputDecoration(labelText: widget.labels[i]),
                    ),
                  ),
                ],
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}

/// Intestazione di card: icona, titolo, link "Modifica" e pill "Aggiungi".
class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final VoidCallback? onEdit;
  final VoidCallback? onAdd;

  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.onEdit,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: iconBg,
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifica'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 17),
                  ),
                ),
            ],
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: const StadiumBorder(),
              textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 17),
            ),
            child: const Text('Aggiungi'),
          ),
        ],
      ],
    );
  }
}

/// Valore grande con unità di misura più piccola sulla stessa linea di base.
class _ValueLine extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;

  const _ValueLine({required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value,
            style: theme.textTheme.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Text(unit,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}