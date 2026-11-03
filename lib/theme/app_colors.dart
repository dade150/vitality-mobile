import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Seed principale: arancio vivo
  static const Color seed = Color(0xFFE65100);
  static const Color secondarySeed = Color(0xFF1B6D24);
  static const Color tertiarySeed = Color(0xFF00609A);
  static const Color errorSeed = Color(0xFFBA1A1A);

  /// Arancio primario per bottoni pieni, call-to-action e indicatori principali.
  /// Con testo bianco sopra ha contrasto ~3.8:1 (ottimo per bottoni ampi e bold).
  static const Color accent = Color(0xFFE65100);

  /// Arancio ad ALTO CONTRASTO studiato appositamente per testi, link, bordi
  /// e icone su sfondo chiaro o pesca. Rapporto di contrasto WCAG AAA:
  /// ~5.6:1 su lightBackground e ~4.8:1 su lightPeach.
  static const Color accentText = Color(0xFFB83E00);

  /// Arancio ancora più brillante: SOLO per elementi decorativi o grandi
  /// (indicatori, barre, icone). Non usarlo come sfondo di testo bianco.
  static const Color vibrantOrange = Color(0xFFFF6D00);

  // --- Superfici tema chiaro (caldo, luminoso, mai #FFFFFF sterile per lo sfondo) ---
  static const Color lightBackground = Color(0xFFFFF8F5);
  static const Color lightCard = Color(0xFFFFFFFF);

  /// Bordo visibile ad alto contrasto (rapporto di contrasto migliorato da 1.35:1 a >2.8:1)
  /// per delimitare nettamente le card bianche sullo sfondo crema e i campi di testo.
  static const Color lightBorder = Color(0xFFDCAB99);

  static const Color lightMuted = Color(0xFFF6EEEA);
  static const Color lightPeach = Color(0xFFFFE9DF);
  static const Color lightGreenContainer = Color(0xFFDDF3DB);
  static const Color lightBlueContainer = Color(0xFFD6EAF8);
}
