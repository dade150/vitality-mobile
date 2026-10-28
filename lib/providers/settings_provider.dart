import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_settings.dart';
import '../services/settings_service.dart';
import 'error_provider.dart';

/// Provider per le impostazioni dell'utente caricate e salvate in Supabase (`public.user_settings`).
///
/// Segue lo stesso pattern di [ProfileProvider] e [AppointmentsProvider]:
/// - collegato al flusso di autenticazione di Supabase
/// - caricamento automatico all'accesso
/// - pulizia dello stato al logout
/// - aggiornamenti ottimistici con persistenza su database protetto da RLS
class SettingsProvider extends ChangeNotifier with ErrorReporting {
  SettingsProvider([SettingsService? service]) : _service = service ?? SettingsService() {
    final auth = Supabase.instance.client.auth;
    _authSub = auth.onAuthStateChange.listen(_onAuthChange);

    final user = auth.currentUser;
    if (user != null) {
      _userId = user.id;
      Future.microtask(refresh);
    }
  }

  final SettingsService _service;
  StreamSubscription<AuthState>? _authSub;

  String? _userId;
  UserSettings? _settings;
  bool _loading = false;
  bool _loadFailed = false;
  bool _hasLoaded = false;

  // ----------------------------------------------------------------- Getters

  UserSettings? get settings => _settings;
  bool get isLoading => _loading;
  bool get loadFailed => _loadFailed;
  bool get hasLoaded => _hasLoaded;

  AppFontSize get fontSize => _settings?.fontSize ?? AppFontSize.grande;
  bool get darkMode => _settings?.darkMode ?? false;
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

  void _onAuthChange(AuthState data) {
    final uid = data.session?.user.id;
    if (data.event == AuthChangeEvent.signedOut || uid == null) {
      _clear();
      return;
    }
    if (uid != _userId) {
      _clear(notify: false);
      _userId = uid;
      unawaited(refresh());
    }
  }

  void _clear({bool notify = true}) {
    _userId = null;
    _settings = null;
    _loading = false;
    _loadFailed = false;
    _hasLoaded = false;
    errorMessage = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- Caricamento

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null) return;

    _loading = true;
    _loadFailed = false;
    errorMessage = null;
    notifyListeners();

    try {
      _settings = await _service.fetch(uid);
      _hasLoaded = true;
      _loadFailed = false;
    } catch (e, st) {
      _loadFailed = true;
      guard(() => Future.error(e, st), where: 'SettingsProvider.refresh');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------- Scritture

  Future<bool> setDarkMode(bool value) async {
    final uid = _userId;
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
    final uid = _userId;
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
    final uid = _userId;
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
    final uid = _userId;
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
}
