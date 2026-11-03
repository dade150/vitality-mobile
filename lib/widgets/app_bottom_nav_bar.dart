import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
      label: 'Esami',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
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
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFFFFB59D) : AppColors.accentText;
    final activePillBg = isDark ? cs.primaryContainer : AppColors.lightPeach;
    final inactiveColor = cs.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6), width: 1.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              final color = active ? activeColor : inactiveColor;
              return Expanded(
                child: InkWell(
                  onTap: () => _onTap(context, i),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: active ? 20 : 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: active ? activePillBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          size: 25,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontSize: 13.5,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
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
