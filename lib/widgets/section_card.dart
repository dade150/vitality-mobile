import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Se true mostra una barra arancio in cima alla card (come nel design).
  final bool highlight;

  /// Callback opzionale per rendere la card interattiva con feedback al tocco.
  final VoidCallback? onTap;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlight = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        child: content,
      );
    }

    if (!highlight) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 6, color: Theme.of(context).colorScheme.primary),
          content,
        ],
      ),
    );
  }
}
