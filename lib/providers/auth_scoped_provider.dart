import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_provider.dart';

/// Base comune per i provider legati alla sessione utente su Supabase.
///
/// Centralizza:
/// - sottoscrizione a `onAuthStateChange` (caricamento automatico all'accesso
///   e pulizia immediata della memoria al logout o cambio utente per GDPR);
/// - stato condiviso [isLoading], [loadFailed], [hasLoaded];
/// - cancellazione della subscription in [dispose].
abstract class AuthScopedProvider extends ChangeNotifier with ErrorReporting {
  AuthScopedProvider([SupabaseClient? client])
      : _db = client ?? Supabase.instance.client {
    final auth = _db.auth;
    _authSub = auth.onAuthStateChange.listen(_onAuthChange);

    // Provider creato all'avvio o lazy dopo il login: lo stato iniziale
    // non passa dallo stream onAuthStateChange.
    final user = auth.currentUser;
    if (user != null) {
      _userId = user.id;
      Future.microtask(refresh);
    }
  }

  final SupabaseClient _db;
  StreamSubscription<AuthState>? _authSub;

  String? _userId;
  bool _loading = false;
  bool _loadFailed = false;
  bool _hasLoaded = false;

  @protected
  SupabaseClient get db => _db;

  @protected
  String? get userId => _userId;

  bool get isLoading => _loading;
  bool get loadFailed => _loadFailed;
  bool get hasLoaded => _hasLoaded;

  @protected
  set isLoading(bool value) => _loading = value;

  @protected
  set loadFailed(bool value) => _loadFailed = value;

  @protected
  set hasLoaded(bool value) => _hasLoaded = value;

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
    _loading = false;
    _loadFailed = false;
    _hasLoaded = false;
    errorMessage = null;
    onClearState();
    if (notify) notifyListeners();
  }

  /// Ripulisce i dati di dominio conservati in RAM (chiamato al logout/cambio utente).
  @protected
  void onClearState();

  /// Ricarica i dati di dominio per l'utente corrente.
  Future<void> refresh();

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
