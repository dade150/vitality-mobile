import 'package:flutter/material.dart';

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

/// Barra di navigazione inferiore condivisa da tutte le schermate dell'app,
/// basata sulla struttura usata in "Nuova Visita". "Appuntamenti" è stato
/// rinominato in "Visite". Le icone cambiano stile (outline/filled) in base
/// alla scheda attiva per una navigazione più fluida e leggibile.
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({super.key, required this.currentIndex});

  static const List<_NavItemData> _items = [
    _NavItemData(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      route: '/chat',
    ),
    _NavItemData(
      label: 'Diario',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      route: '/diary',
    ),
    _NavItemData(
      label: 'Referti',
      icon: Icons.description_outlined,
      activeIcon: Icons.description_rounded,
      route: '/reports',
    ),
    _NavItemData(
      label: 'Visite',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      route: '/appointments',
    ),
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Navigator.of(context).pushNamedAndRemoveUntil(_items[index].route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              final color = active ? cs.primary : cs.onSurfaceVariant;
              return Expanded(
                child: InkWell(
                  onTap: () => _onTap(context, i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 3,
                        width: 28,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: active ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(active ? item.activeIcon : item.icon, size: 26, color: color),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
