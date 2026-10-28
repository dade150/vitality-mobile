enum AppFontSize {
  piccolo('PICCOLO', 'Piccolo', 0.9),
  medio('MEDIO', 'Medio', 1.0),
  grande('GRANDE', 'Grande', 1.15);

  final String dbCode;
  final String label;
  final double scale;

  const AppFontSize(this.dbCode, this.label, this.scale);

  static AppFontSize fromDb(String? value) {
    if (value == null) return AppFontSize.grande;
    return switch (value.trim().toUpperCase()) {
      'PICCOLO' => AppFontSize.piccolo,
      'MEDIO' => AppFontSize.medio,
      'GRANDE' => AppFontSize.grande,
      _ => AppFontSize.grande,
    };
  }
}

/// Modello delle preferenze utente salvate nella tabella `public.user_settings`.
class UserSettings {
  final int? id;
  final String userId;
  final AppFontSize fontSize;
  final bool darkMode;
  final bool notifyTherapy;
  final bool notifyAppointments;
  final bool showMeals;
  final bool showActivities;
  final bool showReports;
  final bool showAppointments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserSettings({
    this.id,
    required this.userId,
    this.fontSize = AppFontSize.grande,
    this.darkMode = false,
    this.notifyTherapy = true,
    this.notifyAppointments = true,
    this.showMeals = true,
    this.showActivities = true,
    this.showReports = true,
    this.showAppointments = true,
    this.createdAt,
    this.updatedAt,
  });

  factory UserSettings.defaults(String userId) => UserSettings(userId: userId);

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
      userId: map['user_id']?.toString() ?? '',
      fontSize: AppFontSize.fromDb(map['font_size'] as String?),
      darkMode: map['dark_mode'] as bool? ?? false,
      notifyTherapy: map['notify_therapy'] as bool? ?? true,
      notifyAppointments: map['notify_appointments'] as bool? ?? true,
      showMeals: map['show_meals'] as bool? ?? true,
      showActivities: map['show_activities'] as bool? ?? true,
      showReports: map['show_reports'] as bool? ?? true,
      showAppointments: map['show_appointments'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'font_size': fontSize.dbCode,
      'dark_mode': darkMode,
      'notify_therapy': notifyTherapy,
      'notify_appointments': notifyAppointments,
      'show_meals': showMeals,
      'show_activities': showActivities,
      'show_reports': showReports,
      'show_appointments': showAppointments,
    };
  }

  UserSettings copyWith({
    int? id,
    String? userId,
    AppFontSize? fontSize,
    bool? darkMode,
    bool? notifyTherapy,
    bool? notifyAppointments,
    bool? showMeals,
    bool? showActivities,
    bool? showReports,
    bool? showAppointments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fontSize: fontSize ?? this.fontSize,
      darkMode: darkMode ?? this.darkMode,
      notifyTherapy: notifyTherapy ?? this.notifyTherapy,
      notifyAppointments: notifyAppointments ?? this.notifyAppointments,
      showMeals: showMeals ?? this.showMeals,
      showActivities: showActivities ?? this.showActivities,
      showReports: showReports ?? this.showReports,
      showAppointments: showAppointments ?? this.showAppointments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
