import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../theme/app_colors.dart';
import '../utils/date_format.dart';
import 'section_card.dart';

/// Card uniforme per la visualizzazione di una visita medica.
class AppointmentCard extends StatelessWidget {
  final Appointment appt;
  final bool isPast;
  final VoidCallback onEdit;

  const AppointmentCard({
    super.key,
    required this.appt,
    required this.isPast,
    required this.onEdit,
  });

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentText = isDark ? cs.primary : AppColors.accentText;
    final dateBoxBg = isDark ? cs.surfaceContainerHigh : AppColors.lightPeach;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        highlight: false,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blocchetto compatto con Mese, Giorno e Orario integrati
                Container(
                  width: 62,
                  decoration: BoxDecoration(
                    color: dateBoxBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentText.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        AppDateFormat.monthShort(appt.date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accentText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${appt.date.day}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 62,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: accentText.withValues(alpha: 0.14),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        ),
                        child: Text(
                          _formatTime(appt.time),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Titolo visita e riferimenti (medico / luogo)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.type,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          height: 1.25,
                        ),
                      ),
                      if (appt.doctorName.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 17,
                              color: accentText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                appt.doctorName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (appt.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 17,
                              color: accentText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                appt.location,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (appt.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.45)),
              const SizedBox(height: 8),
              Text(
                appt.notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Bottone Modifica a tutta larghezza
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifica'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentText,
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(
                  color: accentText.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                backgroundColor: dateBoxBg.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
