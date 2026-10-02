import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color seed = Color(0xFFA43700);
  static const Color secondarySeed = Color(0xFF1B6D24);
  static const Color tertiarySeed = Color(0xFF00609A);
  static const Color errorSeed = Color(0xFFBA1A1A);

  /// Arancione vivido usato per i titoli in evidenza e le call-to-action
  /// principali, coerente con l'accento usato nei design esportati da Stitch.
  /// Rimane invariato sia in tema chiaro sia in tema scuro.
  static const Color accent = Color(0xFFE65100);

  /// Arancione più brillante e saturo di [accent], riservato a elementi che
  /// devono risaltare con più energia (es. indicatore di avanzamento nel
  /// flusso di registrazione). Rimane invariato sia in tema chiaro sia in
  /// tema scuro, come [accent].
  static const Color vibrantOrange = Color(0xFFFF6D00);
}