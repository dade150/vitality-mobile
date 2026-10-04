import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Seed principale: arancio vivo (prima era un rosso-ruggine scuro, A43700,
  /// che dava l'effetto "floscio").
  static const Color seed = Color(0xFFE65100);
  static const Color secondarySeed = Color(0xFF1B6D24);
  static const Color tertiarySeed = Color(0xFF00609A);
  static const Color errorSeed = Color(0xFFBA1A1A);

  /// Arancio per titoli, bottoni pieni e call-to-action. Con testo bianco
  /// sopra ha contrasto ~3.8:1 (ok per testo grande/bold, come le etichette
  /// dei bottoni). Invariato in tema chiaro e scuro.
  static const Color accent = Color(0xFFE65100);

  /// Arancio ancora più brillante: SOLO per elementi decorativi o grandi
  /// (indicatori, barre, icone). Non usarlo come sfondo di testo bianco:
  /// il contrasto scenderebbe a ~2.8:1.
  static const Color vibrantOrange = Color(0xFFFF6D00);

  // --- Superfici tema chiaro (caldo, luminoso, mai #FFFFFF per lo sfondo) ---
  static const Color lightBackground = Color(0xFFFFF8F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFF0CFC2);
  static const Color lightMuted = Color(0xFFF6EEEA);
  static const Color lightPeach = Color(0xFFFFE9DF);
  static const Color lightGreenContainer = Color(0xFFDDF3DB);
  static const Color lightBlueContainer = Color(0xFFD6EAF8);
}