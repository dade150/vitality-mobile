import 'dart:async';

import '../models/user_settings.dart';
import '../services/settings_service.dart';
import 'auth_scoped_provider.dart';

/// Provider per le impostazioni dell'utente caricate e salvate in Supabase (`public.user_settings`).
///
/// Segue lo stesso pattern di [ProfileProvider] e [AppointmentsProvider]:
/// - collegato al flusso di autenticazione di Supabase
/// - caricamento automatico all'accesso
/// - pulizia dello stato al logout
/// - aggiornamenti ottimistici con persistenza su database protetto da RLS
class SettingsProvider extends AuthScopedProvider {
  SettingsProvider({SettingsService? service}) : _service = service ?? SettingsService();

  final SettingsService _service;

  UserSettings? _settings;

  // ----------------------------------------------------------------- Getters

  UserSettings? get settings => _settings;

  AppFontSize get fontSize => _settings?.fontSize ?? AppFontSize.grande;
  bool get darkMode => _settings?.darkMode ?? false;
  bool get autoTts => _settings?.autoTts ?? false;
  bool get notifyTherapy => _settings?.notifyTherapy ?? true;
  bool get notifyAppointments => _settings?.notifyAppointments ?? true;

  // Retrocompatibilità
  bool get notificheTerapia => notifyTherapy;
  bool isSectionVisible(String key) => true;
  Map<String, bool> get sections => const {
        'terapia': true,
        'glicemia': true,
        'pressione': true,
        'pasti': true,
        'attivita': true,
      };

  void setSectionVisible(String key, bool value) {
    // Le sezioni del diario sono state semplificate e sono sempre visibili.
  }

  // --------------------------------------------------------------- Sessione

  @override
  void onClearState() {
    _settings = null;
  }

  // ------------------------------------------------------------- Caricamento

  @override
  Future<void> refresh() async {
    final uid = userId;
    if (uid == null) return;

    isLoading = true;
    loadFailed = false;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _service.fetch(uid);
      if (uid != userId) return;
      _settings = fetched;
      hasLoaded = true;
      loadFailed = false;
    } catch (e, st) {
      if (uid == userId) {
        loadFailed = true;
        guard(() => Future.error(e, st), where: 'SettingsProvider.refresh');
      }
    } finally {
      if (uid == userId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  // --------------------------------------------------------------- Scritture

  Future<bool> setDarkMode(bool value) async {
    final uid = userId;
    if (uid == null) return false;
    if (_settings != null && _settings!.darkMode == value) return true;

    final previous = _settings;
    _settings = (_settings ?? UserSettings.defaults(uid)).copyWith(darkMode: value);
    notifyListeners();

    final ok = await guard(
      () => _service.update(uid, darkMode: value),
      where: 'SettingsProvider.setDarkMode',
    );

    if (!ok) {
      _settings = previous;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> setFontSize(AppFontSize size) async {
    final uid = userId;
    if (uid == null) return false;
    if (_settings != null && _settings!.fontSize == size) return true;

    final previous = _settings;
    _settings = (_settings ?? UserSettings.defaults(uid)).copyWith(fontSize: size);
    notifyListeners();

    final ok = await guard(
      () => _service.update(uid, fontSize: size),
      where: 'SettingsProvider.setFontSize',
    );

    if (!ok) {
      _settings = previous;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> setNotifyTherapy(bool value) async {
    final uid = userId;
    if (uid == null) return false;
    if (_settings != null && _settings!.notifyTherapy == value) return true;

    final previous = _settings;
    _settings = (_settings ?? UserSettings.defaults(uid)).copyWith(notifyTherapy: value);
    notifyListeners();

    final ok = await guard(
      () => _service.update(uid, notifyTherapy: value),
      where: 'SettingsProvider.setNotifyTherapy',
    );

    if (!ok) {
      _settings = previous;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> setNotificheTerapia(bool value) => setNotifyTherapy(value);

  Future<bool> setNotifyAppointments(bool value) async {
    final uid = userId;
    if (uid == null) return false;
    if (_settings != null && _settings!.notifyAppointments == value) return true;

    final previous = _settings;
    _settings = (_settings ?? UserSettings.defaults(uid)).copyWith(notifyAppointments: value);
    notifyListeners();

    final ok = await guard(
      () => _service.update(uid, notifyAppointments: value),
      where: 'SettingsProvider.setNotifyAppointments',
    );

    if (!ok) {
      _settings = previous;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> setAutoTts(bool value) async {
    final uid = userId;
    if (uid == null) return false;
    if (_settings != null && _settings!.autoTts == value) return true;

    final previous = _settings;
    _settings = (_settings ?? UserSettings.defaults(uid)).copyWith(autoTts: value);
    notifyListeners();

    final ok = await guard(
      () => _service.update(uid, autoTts: value),
      where: 'SettingsProvider.setAutoTts',
    );

    if (!ok) {
      _settings = previous;
      notifyListeners();
      return false;
    }
    return true;
  }
}
