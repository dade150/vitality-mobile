import 'package:flutter/material.dart';

/// Gestisce le preferenze dell'app: quali sezioni del Diario sono visibili
/// (per permettere all'utente di "pulire" la schermata) e se le notifiche
/// di promemoria terapia sono attive.
class SettingsProvider extends ChangeNotifier {
  final Map<String, bool> _sections = {
    'terapia': true,
    'glicemia': true,
    'pressione': true,
    'pasti': true,
    'attivita': true,
  };

  bool _notificheTerapia = true;

  bool isSectionVisible(String key) => _sections[key] ?? true;

  Map<String, bool> get sections => Map.unmodifiable(_sections);

  bool get notificheTerapia => _notificheTerapia;

  void setSectionVisible(String key, bool value) {
    _sections[key] = value;
    notifyListeners();
  }

  void setNotificheTerapia(bool value) {
    _notificheTerapia = value;
    notifyListeners();
  }
}
