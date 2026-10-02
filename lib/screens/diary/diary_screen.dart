import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_card.dart';
import '../../utils/date_format.dart';
import '../../theme/app_colors.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDate = DateTime.now();

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _showDeleteConfirmDialog({required VoidCallback onConfirm}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sei sicuro?'),
          content: const Text('Vuoi davvero eliminare questo dato? L\'operazione non è reversibile.'),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Indietro'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.errorSeed),
              onPressed: () {
                onConfirm();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQuickAddDialog({
    required String title,
    required String unitLabel,
    required void Function(double value) onConfirm,
    bool isBloodPressure = false,
  }) async {
    final controller = TextEditingController();
    final controllerDia = TextEditingController();
    final health = context.read<HealthProvider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: isBloodPressure
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sistolica'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: controllerDia,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Diastolica'),
                      ),
                    ),
                  ],
                )
              : TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: unitLabel),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (isBloodPressure) {
                  final sys = double.tryParse(controller.text);
                  final dia = double.tryParse(controllerDia.text);
                  if (sys != null && dia != null) {
                    health.addPressureReading(sys.round(), dia.round());
                  }
                } else {
                  final value = double.tryParse(controller.text);
                  if (value != null) onConfirm(value);
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons({
    required VoidCallback onAdd,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactActionButton(
          label: 'Aggiungi',
          color: Colors.green.shade700,
          icon: Icons.add_circle_outline,
          onTap: onAdd,
        ),
        const SizedBox(height: 6),
        _CompactActionButton(
          label: 'Modifica',
          color: AppColors.accent,
          icon: Icons.edit_outlined,
          onTap: onEdit,
        ),
        const SizedBox(height: 6),
        _CompactActionButton(
          label: 'Cancella',
          color: AppColors.errorSeed,
          icon: Icons.delete_outline,
          onTap: onDelete,
        ),
      ],
    );
  }

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
          Text('Il mio Diario', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              PillButton(
                label: 'Storico',
                icon: Icons.history_rounded,
                onTap: () => Navigator.of(context).pushNamed('/history'),
              ),
              PillButton(
                label: 'Profilo',
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.of(context).pushNamed('/profile'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeDay(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Column(
                  children: [
                    Text(AppDateFormat.dayMonth(_selectedDate), style: theme.textTheme.titleMedium),
                    Text(
                      _isToday(_selectedDate) ? 'Oggi' : AppDateFormat.weekdayShort(_selectedDate),
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
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

  Widget _buildTerapiaSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.medication_outlined, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Text('Terapia', style: theme.textTheme.titleMedium),
                ],
              ),
              PillButton(
                label: 'Modifica',
                icon: Icons.edit_outlined,
                onTap: () => Navigator.of(context).pushNamed('/settings/therapy'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (health.therapyItems.isEmpty)
            Text(
              'Nessuna terapia registrata.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            for (final item in health.therapyItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: item.taken ? cs.secondaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: item.taken ? null : Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.taken ? Icons.check_circle_rounded : Icons.schedule_rounded,
                        color: item.taken ? cs.secondary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: theme.textTheme.titleSmall),
                            Text('${item.time}${item.taken ? ' · Presa' : ''}', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (!item.taken)
                        FilledButton(
                          onPressed: () => context.read<HealthProvider>().toggleTherapyTaken(item.id),
                          child: const Text('Segna come presa'),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildGlicemiaSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reading = health.lastGlucose;
    
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
            child: Icon(Icons.opacity_rounded, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Glicemia', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                if (reading == null)
                  Text('Non è presente alcuna misurazione', style: theme.textTheme.bodySmall)
                else ...[
                  Text('${reading.value.toStringAsFixed(0)} mg/dL',
                      style: theme.textTheme.headlineSmall?.copyWith(color: cs.primary)),
                  Text(
                    'Ultima misurazione: ${AppDateFormat.weekdayShort(reading.time)} '
                    '${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _buildActionButtons(
              onAdd: () => _showQuickAddDialog(
                title: 'Aggiungi Glicemia',
                unitLabel: 'mg/dL',
                onConfirm: (value) => context.read<HealthProvider>().addGlucoseReading(value),
              ),
              onEdit: () { /* Implementa logica di modifica */ },
              onDelete: () => _showDeleteConfirmDialog(
                onConfirm: () => context.read<HealthProvider>().removeLastGlucose(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPressioneSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reading = health.lastPressure;
    
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.secondaryContainer.withValues(alpha: 0.4),
            child: Icon(Icons.favorite_outline_rounded, color: cs.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pressione Arteriosa', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                if (reading == null)
                  Text('Non è presente alcuna misurazione', style: theme.textTheme.bodySmall)
                else ...[
                  Text('${reading.systolic} / ${reading.diastolic} mmHg',
                      style: theme.textTheme.headlineSmall?.copyWith(color: cs.secondary)),
                  Text(
                    'Ultima misurazione: ${AppDateFormat.weekdayShort(reading.time)} '
                    '${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _buildActionButtons(
              onAdd: () => _showQuickAddDialog(
                title: 'Aggiungi Pressione',
                unitLabel: 'mmHg',
                isBloodPressure: true,
                onConfirm: (_) {},
              ),
              onEdit: () { /* Implementa logica di modifica */ },
              onDelete: () => _showDeleteConfirmDialog(
                onConfirm: () => context.read<HealthProvider>().removeLastPressure(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastiSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final todayMeals = health.mealEntries
        .where((m) =>
            m.date.year == _selectedDate.year &&
            m.date.month == _selectedDate.month &&
            m.date.day == _selectedDate.day)
        .toList();
        
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.tertiaryContainer.withValues(alpha: 0.25),
            child: Icon(Icons.restaurant_outlined, color: cs.tertiary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pasti', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  todayMeals.isEmpty ? 'Nessun pasto registrato oggi' : '${todayMeals.length} pasti registrati',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _buildActionButtons(
              onAdd: () => Navigator.of(context).pushNamed('/diary/add-meal'),
              onEdit: () { /* Implementa logica di modifica */ },
              onDelete: () => _showDeleteConfirmDialog(onConfirm: () {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttivitaSection(BuildContext context, HealthProvider health) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.secondaryContainer.withValues(alpha: 0.4),
            child: Icon(Icons.directions_walk_rounded, color: cs.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attività', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                if (health.todaySteps == 0)
                  Text('Nessuna attività registrata oggi', style: theme.textTheme.bodySmall)
                else
                  Text('${health.todaySteps} passi', style: theme.textTheme.headlineSmall?.copyWith(color: cs.secondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _buildActionButtons(
              onAdd: () => Navigator.of(context).pushNamed('/diary/add-activity'),
              onEdit: () { /* Implementa logica di modifica */ },
              onDelete: () => _showDeleteConfirmDialog(onConfirm: () {}),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsante compatto utilizzato per le azioni in colonna (Aggiungi, Modifica, Cancella).
class _CompactActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CompactActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}