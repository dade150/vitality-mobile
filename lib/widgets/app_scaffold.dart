import 'package:flutter/material.dart';
import 'app_bottom_nav_bar.dart';

/// Scaffold di base usato dalle schermate principali: centra il contenuto
/// e lo vincola a una larghezza massima (design responsive su tablet/desktop)
/// e include sempre la barra di navigazione inferiore condivisa.
class AppScaffold extends StatelessWidget {
  final int navIndex;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final Widget? floatingActionButton;
  final double maxWidth;

  const AppScaffold({
    super.key,
    required this.navIndex,
    required this.body,
    this.appBar,
    this.scrollable = true,
    this.padding,
    this.floatingActionButton,
    this.maxWidth = 680,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: body,
        ),
      ),
    );

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
      bottomNavigationBar: AppBottomNavBar(currentIndex: navIndex),
      floatingActionButton: floatingActionButton,
    );
  }
}
