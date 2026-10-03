import 'package:flutter/material.dart';

/// Pulsante ovale riutilizzato in tutta l'app (es. "Storico", "Profilo",
/// "Modifica Dati" nel profilo, "Modifica" nella sezione Terapia del Diario,
/// "Aggiungi" nelle varie card dei parametri vitali).
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool filled;

  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final background = filled ? cs.primary : cs.surfaceContainerHigh;
    final foreground = filled ? cs.onPrimary : cs.onSurface;

    return Material(
      color: background,
      shape: StadiumBorder(
        side: filled ? BorderSide.none : BorderSide(color: cs.outlineVariant, width: 1.5),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}