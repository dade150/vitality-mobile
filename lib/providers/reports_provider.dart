import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medical_report.dart';
import '../services/error_handler.dart';
import 'error_provider.dart';

/// Stato dei referti medici caricati dall'utente, collegato alla tabella
/// `reports` di Supabase (nessun dato mockato).
class ReportsProvider extends ChangeNotifier with ErrorReporting {
  ReportsProvider([SupabaseClient? client]) : _db = client ?? Supabase.instance.client {
    final auth = _db.auth;
    _authSub = auth.onAuthStateChange.listen(_onAuthChange);

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
  bool _hasLoaded = false;
  final List<MedicalReport> _reports = [];

  List<MedicalReport> get reports => List.unmodifiable(_reports);
  bool get isLoading => _loading;
  bool get hasLoaded => _hasLoaded;

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
    _hasLoaded = false;
    errorMessage = null;
    _reports.clear();
    if (notify) notifyListeners();
  }

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null) return;

    _loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final rows = await _db
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      if (uid != _userId) return;

      final loaded = <MedicalReport>[];
      for (final r in rows) {
        final id = r['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final rawTitle = (r['title'] ?? r['file_name'] ?? 'Referto medico').toString().trim();
        final rawDate = (r['report_date'] ?? r['created_at'])?.toString() ?? '';
        final parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();

        final extractedMap = <String, String>{};
        final rawExtracted = r['extracted_params'] ?? r['extracted'];
        if (rawExtracted is Map) {
          for (final entry in rawExtracted.entries) {
            extractedMap[entry.key.toString()] = entry.value.toString();
          }
        }

        // Preserva i parametri estratti in memoria se il referto è appena stato caricato
        final existing = _reports.where((e) => e.id == id).firstOrNull;
        loaded.add(
          MedicalReport(
            id: id,
            title: rawTitle.isEmpty ? 'Referto medico' : rawTitle,
            date: parsedDate,
            extractedParams: extractedMap.isNotEmpty
                ? extractedMap
                : (existing?.extractedParams ?? const {}),
          ),
        );
      }

      _reports
        ..clear()
        ..addAll(loaded);
      _hasLoaded = true;
    } catch (e, st) {
      ErrorHandler.logOnly(e, st, 'ReportsProvider.refresh');
      _hasLoaded = true;
    } finally {
      if (uid == _userId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void addReport(MedicalReport report) {
    _reports.removeWhere((r) => r.id == report.id);
    _reports.insert(0, report);
    notifyListeners();
  }

  Future<bool> deleteReport(String id) async {
    final ok = await guard(
      () async {
        await _db.from('reports').delete().eq('id', id);
      },
      where: 'ReportsProvider.deleteReport',
    );
    if (ok) {
      _reports.removeWhere((r) => r.id == id);
      notifyListeners();
    }
    return ok;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
