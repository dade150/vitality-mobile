import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/meal_entry.dart';
import '../../models/therapy_item.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/health_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/entry_edit_sheet.dart';
import '../../widgets/section_card.dart';
import '../../widgets/simple_charts.dart';
import '../../widgets/vital_entry_sheet.dart';
import '../../utils/date_format.dart';
import '../../theme/app_colors.dart';

/// Livello di granularità della vista del Diario (giornaliera o settimanale).
enum DiaryView { giorno, settimana }

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
  DiaryView _view = DiaryView.giorno;

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

  Widget _viewButton(String label, DiaryView value) {
    final cs = Theme.of(context).colorScheme;
    final selected = _view == value;
    return GestureDetector(
      onTap: () {
        if (_view == value) return;
        setState(() => _view = value);
        context.read<HealthProvider>().ensureLoaded(_periodStart);
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
          ),
        ),
      ),
    );
  }

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

  /// Inizio del periodo corrente (inclusivo) secondo la vista attiva.
  DateTime get _periodStart {
    switch (_view) {
      case DiaryView.giorno:
        return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      case DiaryView.settimana:
        final d = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        return d.subtract(Duration(days: d.weekday - DateTime.monday));
    }
  }

  /// Fine del periodo corrente (esclusiva).
  DateTime get _periodEnd {
    switch (_view) {
      case DiaryView.giorno:
        return _periodStart.add(const Duration(days: 1));
      case DiaryView.settimana:
        return _periodStart.add(const Duration(days: 7));
    }
  }

  bool _inPeriod(DateTime t) => !t.isBefore(_periodStart) && t.isBefore(_periodEnd);

  int get _periodDays => _periodEnd.difference(_periodStart).inDays;

  /// True se il periodo corrente è precedente a oggi (permette di andare avanti
  /// fino a tornare a oggi / settimana corrente, ma non nel futuro).
  bool get _canGoForward {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return !_periodEnd.isAfter(todayStart);
  }

  /// Navigazione avanti/indietro adattata al livello della vista corrente.
  void _changePeriod(int delta) {
    if (delta > 0 && !_canGoForward) return;
    setState(() {
      switch (_view) {
        case DiaryView.giorno:
          _selectedDate = _selectedDate.add(Duration(days: delta));
        case DiaryView.settimana:
          _selectedDate = _selectedDate.add(Duration(days: 7 * delta));
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (_selectedDate.isAfter(today)) {
        _selectedDate = today;
      }
    });
    context.read<HealthProvider>().ensureLoaded(_periodStart);
  }

  /// Titolo del periodo mostrato nella barra di navigazione data.
  String get _periodTitle {
    switch (_view) {
      case DiaryView.giorno:
        return AppDateFormat.dayMonth(_selectedDate);
      case DiaryView.settimana:
        final start = _periodStart;
        final end = _periodEnd.subtract(const Duration(days: 1));
        final sy = AppDateFormat.daySmall(start);
        final sm = AppDateFormat.monthShort(start);
        final ey = AppDateFormat.daySmall(end);
        final em = AppDateFormat.monthShort(end);
        final year = end.year != start.year ? ' ${end.year}' : '';
        return start.month == end.month ? '$sy - $ey $em$year' : '$sy $sm - $ey $em$year';
    }
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

  // ------------------------------------------- Fogli di inserimento dal basso

  void _addGlucose() {
    final when = _timestampOrWarn();
    if (when == null) return;
    final health = context.read<HealthProvider>();
    showVitalEntrySheet(
      context: context,
      title: 'Aggiungi Glicemia',
      icon: Icons.water_drop_outlined,
      fields: const [
        VitalFieldSpec(
          label: 'Valore glicemia',
          hint: 'es. 115',
          unit: 'mg/dL',
          decimal: true,
        ),
      ],
      initialDateTime: when,
      validate: (v, _) => (v[0] == null || v[0]! < -500 || v[0]! > 1500)
          ? 'Inserisci un valore valido (-500 .. 1500 mg/dL)'
          : null,
      onSave: (v, selectedWhen) => health.addGlucoseReading(v[0], at: selectedWhen),
      errorMessage: () => health.errorMessage,
    );
  }

  void _addPressure() {
    final when = _timestampOrWarn();
    if (when == null) return;
    final health = context.read<HealthProvider>();
    showVitalEntrySheet(
      context: context,
      title: 'Aggiungi Pressione',
      icon: Icons.favorite_outline_rounded,
      fields: const [
        VitalFieldSpec(
          label: 'Massima (Sistolica)',
          hint: 'es. 125',
          unit: 'mmHg',
        ),
        VitalFieldSpec(
          label: 'Minima (Diastolica)',
          hint: 'es. 80',
          unit: 'mmHg',
        ),
      ],
      initialDateTime: when,
      validate: (v, _) {
        final sys = v[0], dia = v[1];
        if (sys == null || dia == null) return 'Compila entrambi i valori';
        if (sys < -500 || sys > 500) return 'Massima (sistolica): valore tra -500 e 500';
        if (dia < -500 || dia > 500) return 'Minima (diastolica): valore tra -500 e 500';
        return null;
      },
      onSave: (v, selectedWhen) =>
          health.addPressureReading(v[0].round(), v[1].round(), at: selectedWhen),
      errorMessage: () => health.errorMessage,
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
            subtitle: '${WhenSelector.formatDayLabel(r.time)} · Ore ${_hhmm(r.time)}',
            initialDateTime: r.time,
            whenLabel: 'Quando hai fatto la misurazione?',
            fields: [
              EntryField(
                label: 'Valore glicemia (mg/dL)',
                initialValue: _fmtNum(r.value),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
      ],
      validate: (e, v) {
        final x = _parseNumber(v[0]);
        return (x == null || x < -500 || x > 1500)
            ? 'Inserisci un valore valido (-500 .. 1500 mg/dL)'
            : null;
      },
      onSave: (e, v, when) => health.updateGlucose(e.id, _parseNumber(v[0])!, at: when),
      onDelete: (e) => health.deleteGlucose(e.id),
      errorMessage: () => health.errorMessage,
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
            subtitle: '${WhenSelector.formatDayLabel(r.time)} · Ore ${_hhmm(r.time)}',
            initialDateTime: r.time,
            whenLabel: 'Quando hai fatto la misurazione?',
            fields: [
              EntryField(label: 'Massima - Sistolica (mmHg)', initialValue: '${r.systolic}'),
              EntryField(label: 'Minima - Diastolica (mmHg)', initialValue: '${r.diastolic}'),
            ],
          ),
      ],
      validate: (e, v) {
        final sys = int.tryParse(v[0]);
        final dia = int.tryParse(v[1]);
        if (sys == null || dia == null) return 'Compila entrambi i valori';
        if (sys < -500 || sys > 500) return 'Sistolica: valore tra -500 e 500';
        if (dia < -500 || dia > 500) return 'Diastolica: valore tra -500 e 500';
        return null;
      },
      onSave: (e, v, when) =>
          health.updatePressure(e.id, int.parse(v[0]), int.parse(v[1]), at: when),
      onDelete: (e) => health.deletePressure(e.id),
      errorMessage: () => health.errorMessage,
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
            subtitle: m.hasExplicitTime
                ? 'Ore ${_hhmm(m.date)} · ${m.description} · ${m.isEstimated ? '~' : ''}${m.calories} kcal${m.carbsGrams != null ? ' · ${m.carbsGrams}g carb' : ''}'
                : '${m.description} · ${m.isEstimated ? '~' : ''}${m.calories} kcal${m.carbsGrams != null ? ' · ${m.carbsGrams}g carb' : ''}',
            initialDateTime: m.date,
            whenLabel: 'Giorno del pasto',
            showTimeInWhen: false,
            fields: [
              EntryField(
                label: 'Cosa hai mangiato?',
                initialValue: m.description,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),
              EntryField(label: 'Calorie (kcal)', initialValue: '${m.calories}'),
              EntryField(
                label: 'Carboidrati (g, opzionale)',
                initialValue: m.carbsGrams != null ? '${m.carbsGrams}' : '',
                keyboardType: TextInputType.number,
              ),
              EntryField(
                label: m.type == MealType.fuoriPasto
                    ? 'Orario fuori pasto (es. 17:30)'
                    : 'Orario (opzionale, es. 13:00)',
                initialValue: m.hasExplicitTime ? _hhmm(m.date) : '',
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
      ],
      validate: (e, v) {
        if (v[0].isEmpty) return 'Inserisci una descrizione';
        if (v[0].length > 500) return 'Descrizione troppo lunga (massimo 500 caratteri)';
        final kcal = int.tryParse(v[1]);
        if (kcal == null || kcal < 0 || kcal > 10000) return 'Calorie: valore tra 0 e 10000';
        if (v[2].isNotEmpty) {
          final carbs = int.tryParse(v[2]);
          if (carbs == null || carbs < 0 || carbs > 2000) return 'Carboidrati: valore tra 0 e 2000 g';
        }
        if (v[3].isNotEmpty && HealthService.normalizeTime(v[3]) == null) {
          return 'Orario non valido: usa il formato HH:MM (es. 13:30)';
        }
        return null;
      },
      onSave: (e, v, when) {
        final meal = items.firstWhere((m) => m.id == e.id);
        final day = when ?? meal.date;
        final rawCarbs = v[2].trim();
        final carbs = rawCarbs.isNotEmpty ? int.tryParse(rawCarbs) : null;
        final rawTime = v[3].trim();
        DateTime finalAt;
        if (rawTime.isNotEmpty) {
          final norm = HealthService.normalizeTime(rawTime)!;
          final parts = norm.split(':');
          finalAt = DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]), 1);
        } else {
          final def = meal.type.defaultTime;
          finalAt = DateTime(day.year, day.month, day.day, def.hour, def.minute, 0);
        }
        return health.updateMeal(
          e.id,
          description: v[0],
          calories: int.parse(v[1]),
          carbsGrams: carbs,
          at: finalAt,
        );
      },
      onDelete: (e) => health.deleteMeal(e.id),
      errorMessage: () => health.errorMessage,
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
            subtitle: a.steps > 0
                ? 'Ore ${_hhmm(a.date)} · ${a.steps} passi'
                : 'Ore ${_hhmm(a.date)}',
            initialDateTime: a.date,
            whenLabel: "Quando hai svolto l'attività?",
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
      onSave: (e, v, when) => health.updateActivity(
        e.id,
        minutes: int.parse(v[0]),
        steps: v[1].isEmpty ? 0 : int.parse(v[1]),
        at: when,
      ),
      onDelete: (e) => health.deleteActivity(e.id),
      errorMessage: () => health.errorMessage,
    );
  }

  // ---------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();
    final health = context.watch<HealthProvider>();

    return AppScaffold(
      navIndex: 1,
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
                Expanded(child: _viewButton('Giorno', DiaryView.giorno)),
                Expanded(child: _viewButton('Settimana', DiaryView.settimana)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            highlight: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changePeriod(-1),
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.accent),
                ),
                if (_view == DiaryView.giorno)
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
                  )
                else
                  Text(_periodTitle, style: theme.textTheme.titleSmall),
                IconButton(
                  onPressed: _canGoForward ? () => _changePeriod(1) : null,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _canGoForward ? AppColors.accent : cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
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
          if (_view == DiaryView.giorno) ...[
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
          ] else ...[
            if (settings.isSectionVisible('terapia')) ...[
              _buildTerapiaPeriod(context, health),
              const SizedBox(height: 20),
            ],
            if (settings.isSectionVisible('glicemia')) ...[
              _buildGlicemiaPeriod(context, health),
              const SizedBox(height: 20),
            ],
            if (settings.isSectionVisible('pressione')) ...[
              _buildPressionePeriod(context, health),
              const SizedBox(height: 20),
            ],
            if (settings.isSectionVisible('pasti')) ...[
              _buildPastiPeriod(context, health),
              const SizedBox(height: 20),
            ],
            if (settings.isSectionVisible('attivita')) ...[
              _buildAttivitaPeriod(context, health),
              const SizedBox(height: 20),
            ],
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------- Viste periodo

  static const _weekLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  Widget _buildViewAllButton({VoidCallback? onPressed}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed ?? () {},
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: const Text('Visualizza tutto'),
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
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTerapiaPeriod(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final therapyCount = health.therapyItems.length;
    final expected = therapyCount * _periodDays;
    int taken = 0;
    final dailyRatios = List<double?>.filled(7, null);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (therapyCount > 0) {
      for (int i = 0; i < 7; i++) {
        final day = _periodStart.add(Duration(days: i));
        final dayDate = DateTime(day.year, day.month, day.day);
        if (dayDate.isAfter(today)) {
          dailyRatios[i] = null;
          continue;
        }
        int dayTaken = 0;
        for (final item in health.therapyItems) {
          if (health.isTherapyTaken(item.id, day)) {
            dayTaken++;
            taken++;
          }
        }
        dailyRatios[i] = dayTaken / therapyCount;
      }
    }

    final pct = expected == 0 ? 0 : ((taken / expected) * 100).round();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.medication_outlined,
            iconColor: cs.tertiary,
            iconBg: cs.tertiaryContainer,
            title: 'Terapia',
          ),
          const SizedBox(height: 12),
          if (health.therapyItems.isEmpty)
            Text('Nessuna terapia registrata.', style: theme.textTheme.bodyMedium)
          else ...[
            _ValueLine(label: 'Aderenza:', value: '$pct%', color: cs.onSurface),
            const SizedBox(height: 14),
            WeeklyTherapyTracker(
              labels: _weekLabels,
              completionRatios: dailyRatios,
            ),
            const SizedBox(height: 12),
            _buildViewAllButton(
              onPressed: () => Navigator.of(context).pushNamed('/diary/history/therapy'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlicemiaPeriod(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final readings = health.glucoseReadings.where((r) => _inPeriod(r.time)).toList();

    final dailyValues = List<double?>.filled(7, null);
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayReadings = readings.where((r) => _sameDay(r.time, day)).toList();
      if (dayReadings.isNotEmpty) {
        final avg = dayReadings.map((r) => r.value).reduce((a, b) => a + b) / dayReadings.length;
        dailyValues[i] = avg.roundToDouble();
      }
    }

    final hypoCount = readings.where((r) => r.value < 70).length;
    final hyperCount = readings.where((r) => r.value > 180).length;

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
          ),
          const SizedBox(height: 12),
          if (readings.isEmpty)
            Text('Nessuna misurazione nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            _ValueLine(
              label: 'Media:',
              value: _fmtNum(readings.map((r) => r.value).reduce((a, b) => a + b) / readings.length),
              unit: 'mg/dL',
              color: cs.onSurface,
            ),
            if (hypoCount > 0 || hyperCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          if (hypoCount > 0) '$hypoCount ipoglicemia (<70 mg/dL)',
                          if (hyperCount > 0) '$hyperCount iperglicemia (>180 mg/dL)',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            GlucoseTrendChart(
              labels: _weekLabels,
              values: dailyValues,
            ),
            const SizedBox(height: 12),
            _buildViewAllButton(
              onPressed: () => Navigator.of(context).pushNamed('/diary/history/glucose'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPressionePeriod(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final readings = health.pressureReadings.where((r) => _inPeriod(r.time)).toList();

    final dailySys = List<int>.filled(7, 0);
    final dailyDia = List<int>.filled(7, 0);
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayReadings = readings.where((r) => _sameDay(r.time, day)).toList();
      if (dayReadings.isNotEmpty) {
        dailySys[i] =
            (dayReadings.map((r) => r.systolic).reduce((a, b) => a + b) / dayReadings.length).round();
        dailyDia[i] =
            (dayReadings.map((r) => r.diastolic).reduce((a, b) => a + b) / dayReadings.length).round();
      }
    }
    final maxSys = dailySys.fold<int>(180, math.max).toDouble();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.favorite_outline_rounded,
            iconColor: cs.secondary,
            iconBg: cs.secondaryContainer,
            title: 'Pressione',
          ),
          const SizedBox(height: 12),
          if (readings.isEmpty)
            Text('Nessuna misurazione nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            _ValueLine(
              label: 'Media:',
              value:
                  '${(readings.map((r) => r.systolic).reduce((a, b) => a + b) / readings.length).round()}'
                  ' / '
                  '${(readings.map((r) => r.diastolic).reduce((a, b) => a + b) / readings.length).round()}',
              unit: 'mmHg',
              color: cs.onSurface,
            ),
            const SizedBox(height: 16),
            BloodPressureGroupedBarChart(
              labels: _weekLabels,
              systolic: dailySys,
              diastolic: dailyDia,
              maxValue: maxSys,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _legendDot(context, const Color(0xFFE53935), 'Massima (Sistolica)'),
                _legendDot(context, const Color(0xFF1E88E5), 'Minima (Diastolica)'),
              ],
            ),
            const SizedBox(height: 12),
            _buildViewAllButton(
              onPressed: () => Navigator.of(context).pushNamed('/diary/history/blood-pressure'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPastiPeriod(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final meals = health.mealEntries.where((m) => _inPeriod(m.date)).toList();
    final totalKcal = meals.fold<int>(0, (s, m) => s + m.calories);

    final dailyKcal = List<double?>.filled(7, null);
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayMeals = meals.where((m) => _sameDay(m.date, day)).toList();
      if (dayMeals.isNotEmpty) {
        dailyKcal[i] = dayMeals.fold<int>(0, (s, m) => s + m.calories).toDouble();
      }
    }

    final maxDailyKcal = dailyKcal.whereType<double>().fold<double>(2000.0, math.max);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.restaurant_outlined,
            iconColor: cs.secondary,
            iconBg: cs.secondaryContainer,
            title: 'Pasti',
          ),
          const SizedBox(height: 12),
          if (meals.isEmpty)
            Text('Nessun pasto registrato nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            _ValueLine(label: 'Totale:', value: '$totalKcal', unit: 'kcal', color: cs.onSurface),
            const SizedBox(height: 16),
            SimpleBarChart(
              labels: _weekLabels,
              values: dailyKcal,
              maxValue: maxDailyKcal,
              color: cs.secondary,
            ),
            const SizedBox(height: 12),
            _buildViewAllButton(
              onPressed: () => Navigator.of(context).pushNamed('/diary/history/meals'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttivitaPeriod(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = health.activityEntries.where((a) => _inPeriod(a.date)).toList();
    final steps = entries.fold<int>(0, (s, a) => s + a.steps);
    final minutes = entries.fold<int>(0, (s, a) => s + a.minutes);

    final dailyMinutes = List<double?>.filled(7, null);
    for (int i = 0; i < 7; i++) {
      final day = _periodStart.add(Duration(days: i));
      final dayMin = entries
          .where((a) => _sameDay(a.date, day))
          .fold<int>(0, (s, a) => s + a.minutes);
      if (dayMin > 0) {
        dailyMinutes[i] = dayMin.toDouble();
      }
    }
    final maxDailyMin = dailyMinutes.whereType<double>().fold<double>(60.0, math.max);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.directions_walk_rounded,
            iconColor: cs.tertiary,
            iconBg: cs.tertiaryContainer,
            title: 'Attività',
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text('Nessuna attività registrata nel periodo.', style: theme.textTheme.bodyMedium)
          else ...[
            _ValueLine(label: 'Totale:', value: '$minutes', unit: 'minuti', color: cs.onSurface),
            if (steps > 0) ...[
              const SizedBox(height: 4),
              Text('$steps passi totali', style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            SimpleBarChart(
              labels: _weekLabels,
              values: dailyMinutes,
              maxValue: maxDailyMin,
              color: cs.tertiary,
              valueSuffix: 'm',
            ),
            const SizedBox(height: 12),
            _buildViewAllButton(
              onPressed: () => Navigator.of(context).pushNamed('/diary/history/activity'),
            ),
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
      trailing = Material(
        color: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: busy
              ? null
              : () async {
                  final provider = context.read<HealthProvider>();
                  final ok = await provider.toggleTherapyTaken(item.id);
                  if (!ok && mounted && !provider.isTherapyToggling(item.id)) {
                    _showMessage(provider.errorMessage ?? 'Salvataggio non riuscito. Riprova.');
                  }
                },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else ...[
                  const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  const Text(
                    'Prendi',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } else if (_isToday && taken) {
      final busy = health.isTherapyToggling(item.id);
      trailing = Material(
        color: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cs.outlineVariant, width: 1.2),
        ),
        child: InkWell(
          onTap: busy
              ? null
              : () async {
                  final provider = context.read<HealthProvider>();
                  final ok = await provider.toggleTherapyTaken(item.id);
                  if (!ok && mounted && !provider.isTherapyToggling(item.id)) {
                    _showMessage(provider.errorMessage ?? 'Operazione non riuscita. Riprova.');
                  }
                },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant),
                  )
                else ...[
                  Icon(Icons.undo_rounded, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Annulla',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: taken
                ? Colors.green.withValues(alpha: 0.35)
                : AppColors.accent.withValues(alpha: 0.3),
            width: 1.3,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: taken
                    ? Colors.green.withValues(alpha: 0.12)
                    : AppColors.lightPeach,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                taken ? Icons.check_circle_rounded : Icons.medication_outlined,
                size: 20,
                color: taken ? Colors.green.shade700 : AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: taken ? Colors.green.shade700 : AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          taken
                              ? '${item.time} · Presa'
                              : isPast
                                  ? '${item.time} · Non registrata'
                                  : '${item.time} · Da assumere',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: taken
                                ? Colors.green.shade700
                                : isPast
                                    ? cs.onSurfaceVariant
                                    : AppColors.accent,
                            fontWeight: taken ? FontWeight.w600 : FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildCardAddButton({
    required String label,
    required VoidCallback onAdd,
    IconData icon = Icons.add_rounded,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onAdd,
        icon: Icon(icon, size: 18),
        label: Text(label),
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
    );
  }

  // ---------------------------------------------------------------- Glicemia

  Widget _buildGlicemiaSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dayReadings =
        health.glucoseReadings.where((r) => _sameDay(r.time, _selectedDate)).toList();
    final reading = dayReadings.isNotEmpty
        ? dayReadings.last
        : _lastUpTo(health.glucoseReadings, (r) => r.time);

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
            onEdit: reading != null ? _editGlucose : null,
          ),
          const SizedBox(height: 12),
          if (reading == null) ...[
            Text('Non è presente alcuna misurazione', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _buildCardAddButton(
              label: 'Aggiungi misurazione',
              onAdd: _addGlucose,
            ),
          ] else ...[
            _ValueLine(
              value: _fmtNum(reading.value),
              unit: 'mg/dL',
              color: cs.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              'Ultima misurazione: ${_formatWhen(reading.time)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildCardAddButton(
              label: 'Aggiungi misurazione',
              onAdd: _addGlucose,
            ),
            if (dayReadings.length > 1) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              Text(
                'Misurazioni della giornata (${dayReadings.length}):',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final r in dayReadings.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        (r.value < 70 || r.value > 180)
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: (r.value < 70 || r.value > 180) ? cs.error : cs.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ore ${_hhmm(r.time)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_fmtNum(r.value)} mg/dL',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: (r.value < 70 || r.value > 180) ? cs.error : cs.onSurface,
                        ),
                      ),
                      if (r.value < 70 || r.value > 180) ...[
                        const SizedBox(width: 8),
                        Text(
                          r.value < 70 ? '(Ipoglicemia)' : '(Iperglicemia)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Pressione

  Widget _buildPressioneSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dayReadings =
        health.pressureReadings.where((r) => _sameDay(r.time, _selectedDate)).toList();
    final reading = dayReadings.isNotEmpty
        ? dayReadings.last
        : _lastUpTo(health.pressureReadings, (r) => r.time);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.favorite_outline_rounded,
            iconColor: cs.secondary,
            iconBg: cs.secondaryContainer,
            title: 'Pressione',
            onEdit: reading != null ? _editPressure : null,
          ),
          const SizedBox(height: 12),
          if (reading == null) ...[
            Text('Non è presente alcuna misurazione', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _buildCardAddButton(
              label: 'Aggiungi misurazione',
              onAdd: _addPressure,
            ),
          ] else ...[
            _ValueLine(
              value: '${reading.systolic} / ${reading.diastolic}',
              unit: 'mmHg',
              color: cs.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              'Ultima misurazione: ${_formatWhen(reading.time)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildCardAddButton(
              label: 'Aggiungi misurazione',
              onAdd: _addPressure,
            ),
            if (dayReadings.length > 1) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              Text(
                'Misurazioni della giornata (${dayReadings.length}):',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final r in dayReadings.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.favorite_border_rounded, size: 18, color: cs.secondary),
                      const SizedBox(width: 8),
                      Text('Ore ${_hhmm(r.time)}', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 10),
                      Text(
                        '${r.systolic} / ${r.diastolic} mmHg',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
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
            onEdit: meals.isNotEmpty ? _editMeals : null,
          ),
          const SizedBox(height: 12),
          if (meals.isEmpty)
            Text('Nessun pasto registrato', style: theme.textTheme.bodyMedium)
          else
            for (final m in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                            if (m.hasExplicitTime)
                              TextSpan(
                                text: ' (${_hhmm(m.date)})',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            TextSpan(text: ' · ${m.description}'),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${m.isEstimated ? '~' : ''}${m.calories} kcal${m.carbsGrams != null ? ' · ${m.carbsGrams}g carb' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          _buildCardAddButton(
            label: 'Aggiungi pasto',
            onAdd: _addMeal,
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
            onEdit: entries.isNotEmpty ? _editActivities : null,
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text('Nessuna attività registrata', style: theme.textTheme.bodyMedium)
          else ...[
            if (steps > 0) _ValueLine(value: '$steps', unit: 'passi', color: cs.tertiary),
            Text('$minutes minuti di attività', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (final a in entries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ore ${_hhmm(a.date)} · ${a.type} (${a.minutes} min'
                  '${a.steps > 0 ? ', ${a.steps} passi' : ''})',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          const SizedBox(height: 12),
          _buildCardAddButton(
            label: 'Aggiungi attività',
            onAdd: _addActivity,
          ),
        ],
      ),
    );
  }
}

/// Intestazione di card: icona discreta, titolo ed eventuale bottone "Modifica" a destra (stile Visite).
class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final VoidCallback? onEdit;

  const _CardHeader({
    required this.icon,
    this.iconColor = AppColors.accent,
    this.iconBg = AppColors.lightPeach,
    required this.title,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
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
          child: Icon(icon, color: AppColors.accent, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              fontSize: 18,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onEdit != null) ...[
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
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
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
    );
  }
}

/// Valore con eventuale etichetta (es. "Media:", "Aderenza:", "Totale:")
/// e unità di misura sulla stessa linea di base.
class _ValueLine extends StatelessWidget {
  final String? label;
  final String value;
  final String unit;
  final Color color;

  const _ValueLine({
    this.label,
    required this.value,
    this.unit = '',
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              unit,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}