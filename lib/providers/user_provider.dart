import 'package:flutter/material.dart';

/// Gestisce l'autenticazione (demo) e i dati del profilo utente.
class UserProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String name = 'Mario Rossi';
  String email = 'mario.rossi@esempio.it';
  String phone = '+39 340 123 4567';
  int age = 72;
  String gender = 'Maschio';
  double weightKg = 82;
  double heightCm = 175;
  bool autoLogin = true;

  double get bmi {
    final heightM = heightCm / 100;
    if (heightM <= 0) return 0;
    return weightKg / (heightM * heightM);
  }

  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Sottopeso';
    if (b < 25) return 'Normale';
    if (b < 30) return 'Sovrappeso';
    return 'Obesità';
  }

  /// Login "demo": qualunque nome utente/password non vuoti sono accettati.
  /// Da sostituire con una vera autenticazione (es. backend, Firebase Auth).
  bool login(String username, String password) {
    if (username.trim().isEmpty || password.trim().isEmpty) return false;
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? phone,
    int? age,
    String? gender,
    double? weightKg,
    double? heightCm,
  }) {
    if (name != null && name.trim().isNotEmpty) this.name = name;
    if (email != null) this.email = email;
    if (phone != null) this.phone = phone;
    if (age != null) this.age = age;
    if (gender != null) this.gender = gender;
    if (weightKg != null) this.weightKg = weightKg;
    if (heightCm != null) this.heightCm = heightCm;
    notifyListeners();
  }
}
