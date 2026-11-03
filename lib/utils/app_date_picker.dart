import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Helper unificato per la selezione e la visualizzazione di date e orari
/// in tutta l'applicazione diaLog2.
///
/// Garantisce:
/// - Standard italiano per date (calendario che inizia da Lunedì, mesi e giorni in italiano)
/// - Standard italiano per orari (formato 24 ore senza AM/PM)
/// - Pulsanti e testi uniformi ("Annulla", "Conferma", helpText personalizzato)
/// - Tema grafico coerente ad alto contrasto (WCAG AAA)
class AppDateTimePicker {
  AppDateTimePicker._();

  /// Apre il selettore della data uniforme e localizzato in italiano.
  static Future<DateTime?> pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
    String cancelText = 'Annulla',
    String confirmText = 'Conferma',
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  }) async {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentText = isDark ? cs.primary : AppColors.accentText;

    var safeInitial = initialDate;
    if (safeInitial.isBefore(firstDate)) safeInitial = firstDate;
    if (safeInitial.isAfter(lastDate)) safeInitial = lastDate;

    return showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: initialEntryMode,
      helpText: helpText ?? 'Scegli la data',
      cancelText: cancelText,
      confirmText: confirmText,
      locale: const Locale('it', 'IT'),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: isDark ? cs.surfaceContainerHigh : AppColors.accent,
              headerForegroundColor: Colors.white,
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              dayStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              weekdayStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: accentText,
              ),
              yearStyle: theme.textTheme.bodyMedium,
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: accentText,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Apre il selettore dell'orario uniforme e localizzato in italiano nel formato a 24 ore.
  static Future<TimeOfDay?> pickTime({
    required BuildContext context,
    required TimeOfDay initialTime,
    String? helpText,
    String cancelText = 'Annulla',
    String confirmText = 'Conferma',
    TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  }) async {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? cs.primary : AppColors.accent;
    final accentText = isDark ? cs.primary : AppColors.accentText;

    return showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: initialEntryMode,
      helpText: helpText ?? 'Scegli l\'orario',
      cancelText: cancelText,
      confirmText: confirmText,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: theme.copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: cs.surface,
                hourMinuteColor: isDark ? cs.surfaceContainerHigh : AppColors.lightPeach,
                hourMinuteTextColor: accentText,
                dialHandColor: accentColor,
                dialBackgroundColor: isDark ? cs.surfaceContainerHigh : AppColors.lightMuted,
                dialTextColor: cs.onSurface,
                entryModeIconColor: accentText,
                helpTextStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                cancelButtonStyle: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                confirmButtonStyle: TextButton.styleFrom(
                  foregroundColor: accentText,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Widget unificato per mostrare un campo cliccabile di data o orario
/// con accessibilità tattile garantita (min 52dp), contrasto elevato
/// e stile visivo identico in tutte le schermate.
class AppPickerTile extends StatelessWidget {
  final IconData icon;
  final String caption;
  final String valueText;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AppPickerTile({
    super.key,
    required this.icon,
    required this.caption,
    required this.valueText,
    this.enabled = true,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentText = isDark ? cs.primary : AppColors.accentText;

    return Material(
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outlineVariant,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: enabled ? accentText : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        valueText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w700,
                          fontSize: 16.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
