import 'package:flutter/material.dart';

/// Chiave globale del Navigator.
///
/// Vive fuori da `main.dart` per evitare import circolari
/// (`ErrorHandler` -> `main.dart` -> `ErrorHandler`).
///
/// Deve restare UNA sola istanza: `MaterialApp.navigatorKey` e
/// `ErrorHandler` devono leggere la stessa chiave, altrimenti la
/// schermata di errore verrebbe spinta su un navigator che l'app
/// non monta (errore silenzioso, nessuna schermata).
final navigatorKey = GlobalKey<NavigatorState>();
