import 'package:flutter/material.dart';
import '../../models/request/registration_request.dart';
import '../../models/therapy_item.dart';
import '../../theme/app_colors.dart';
import '../../widgets/section_card.dart';
import '../../widgets/therapy_dialog.dart';

/// Step di registrazione per la configurazione iniziale del piano terapeutico.
///
/// Collocato subito dopo l'inserimento dei parametri vitali/fisici (Step 1).
/// Riutilizza [TherapyItemDialog] per coerenza grafica e logica con la
/// schermata di configurazione terapia esistente.
/// Il passaggio è facoltativo e include opzione esplicita di Skip ("Salta").
class RegisterStepTherapy extends StatefulWidget {
  final RegistrationData data;
  final VoidCallback? onSkip;

  const RegisterStepTherapy({
    super.key,
    required this.data,
    this.onSkip,
  });

  @override
  State<RegisterStepTherapy> createState() => _RegisterStepTherapyState();
}

class _RegisterStepTherapyState extends State<RegisterStepTherapy> {
  Future<void> _addOrEditTherapy({TherapyItem? existing, int? index}) async {
    await TherapyItemDialog.show(
      context: context,
      existing: existing,
      onSave: (name, time) async {
        setState(() {
          if (existing != null && index != null) {
            existing.name = name;
            existing.time = time;
          } else {
            widget.data.therapies.add(
              TherapyItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                time: time,
              ),
            );
          }
        });
        return true;
      },
    );
  }

  void _removeTherapy(int index) {
    setState(() {
      widget.data.therapies.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentText = isDark ? cs.primary : AppColors.accentText;
    final therapies = widget.data.therapies;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? cs.primaryContainer : AppColors.lightPeach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.medication_outlined, color: accentText, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Terapia farmacologica', style: theme.textTheme.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Se segui una terapia quotidiana per il diabete, la pressione o altre patologie, inserisci i farmaci e gli orari di assunzione per ricevere promemoria puntuali.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),

          // Lista dei farmaci aggiunti
          if (therapies.isNotEmpty) ...[
            Text(
              'Farmaci inseriti (${therapies.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < therapies.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? cs.primaryContainer : AppColors.lightPeach,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.medication_outlined, color: accentText, size: 20),
                    ),
                    title: Text(
                      therapies[i].name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('Ore ${therapies[i].time}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Modifica',
                          onPressed: () => _addOrEditTherapy(existing: therapies[i], index: i),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.error),
                          tooltip: 'Rimuovi',
                          onPressed: () => _removeTherapy(i),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Tasto Aggiungi Farmaco
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _addOrEditTherapy(),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentText,
                side: BorderSide(color: accentText.withValues(alpha: 0.5), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Aggiungi farmaco',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
