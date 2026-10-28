import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment.dart';
import '../services/error_handler.dart';
import 'error_provider.dart';

/// Stato delle visite mediche / appuntamenti, collegato alla tabella
/// `appointments` di Supabase (nessun dato mockato).
///
/// Rispetta le regole GDPR e di sessione: carica i dati all'accesso e
/// svuota immediatamente la memoria al logout o cambio utente.
class AppointmentsProvider extends ChangeNotifier with ErrorReporting {
  AppointmentsProvider([SupabaseClient? client]) : _db = client ?? Supabase.instance.client {
    final auth = _db.auth;
    _authSub = auth.onAuthStateChange.listen(_onAuthChange);

    final user = auth.currentUser;
    if (user != null) {
      _userId = user.id;
      Future.microtask(refresh);
    }
  }

  static const _table = 'appointments';

  final SupabaseClient _db;
  StreamSubscription<AuthState>? _authSub;

  String? _userId;
  bool _loading = false;
  bool _loadFailed = false;
  bool _hasLoaded = false;

  final List<Appointment> _appointments = [];

  // ---------------------------------------------------------------- Getter

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _loading;
  bool get loadFailed => _loadFailed;
  bool get hasLoaded => _hasLoaded;

  /// Tutti gli appuntamenti ordinati cronologicamente (dal meno recente al più lontano).
  List<Appointment> get sorted {
    final list = List<Appointment>.from(_appointments);
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  DateTime get _cutoff => DateTime.now().subtract(const Duration(hours: 1));

  /// Il prossimo appuntamento in programma (da un'ora fa in avanti).
  Appointment? get next {
    final cutoff = _cutoff;
    final future = sorted.where((a) => a.dateTime.isAfter(cutoff));
    return future.isEmpty ? null : future.first;
  }

  /// Le visite future successive a [next], in ordine cronologico crescente.
  List<Appointment> get upcoming {
    final cutoff = _cutoff;
    final nextAppt = next;
    return sorted
        .where((a) => a.dateTime.isAfter(cutoff) && a.id != nextAppt?.id)
        .toList();
  }

  /// Storico delle visite passate, ordinate dalla più recente alla più vecchia.
  List<Appointment> get past {
    final cutoff = _cutoff;
    final list = _appointments.where((a) => !a.dateTime.isAfter(cutoff)).toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
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
    _loading = false;
    _loadFailed = false;
    _hasLoaded = false;
    errorMessage = null;
    _appointments.clear();
    if (notify) notifyListeners();
  }

  // --------------------------------------------------- Conversioni & Fetch

  static Appointment? _fromRow(Map<String, dynamic> r) {
    final id = r['id']?.toString();
    if (id == null || id.isEmpty || id == 'null') return null;

    final type = (r['visit_type'] ?? r['type'] ?? r['title'] ?? '').toString().trim();
    if (type.isEmpty) return null;

    DateTime? dt;
    final rawAt = r['appointment_at'] ?? r['scheduled_at'] ?? r['visit_at'];
    if (rawAt != null) {
      dt = DateTime.tryParse(rawAt.toString())?.toLocal();
    } else if (r['date'] != null) {
      final d = DateTime.tryParse(r['date'].toString())?.toLocal();
      if (d != null) {
        final rawTime = (r['time'] ?? '09:00').toString();
        final parts = rawTime.split(':');
        final h = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 9) : 9;
        final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        dt = DateTime(d.year, d.month, d.day, h, m);
      }
    }
    if (dt == null) return null;

    final location = (r['location'] ?? r['doctor_name'] ?? '').toString().trim();
    final notes = (r['notes'] ?? '').toString().trim();

    return Appointment(
      id: id,
      type: type,
      date: DateTime(dt.year, dt.month, dt.day),
      time: TimeOfDay(hour: dt.hour, minute: dt.minute),
      location: location,
      notes: notes,
    );
  }

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null) return;

    _loading = true;
    _loadFailed = false;
    errorMessage = null;
    notifyListeners();

    try {
      final rows = await _db.from(_table).select().limit(500);
      if (uid != _userId) return;

      final loaded = <Appointment>[];
      for (final r in rows) {
        final appt = _fromRow(r);
        if (appt != null) loaded.add(appt);
      }

      _appointments
        ..clear()
        ..addAll(loaded);
      _hasLoaded = true;
    } catch (e, st) {
      ErrorHandler.handle(e, st, 'AppointmentsProvider.refresh');
      if (uid == _userId) _loadFailed = true;
    } finally {
      if (uid == _userId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reload() async {
    final uid = _userId;
    final rows = await _db.from(_table).select().limit(500);
    if (uid != _userId) return;
    final loaded = <Appointment>[];
    for (final r in rows) {
      final appt = _fromRow(r);
      if (appt != null) loaded.add(appt);
    }
    _appointments
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<bool> _write(Future<void> Function() op, {required String where}) async {
    final ok = await guard(op, where: 'AppointmentsProvider.$where');
    if (!ok) return false;
    try {
      await _reload();
    } catch (e, st) {
      ErrorHandler.handle(e, st, 'AppointmentsProvider.$where.reload');
      _loadFailed = true;
      notifyListeners();
    }
    return true;
  }

  static void _validate(Appointment a) {
    if (a.type.trim().isEmpty || a.type.trim().length > 150) {
      throw ArgumentError('tipo visita non valido');
    }
    if (a.location.trim().length > 200) {
      throw ArgumentError('luogo troppo lungo');
    }
    if (a.notes.trim().length > 1000) {
      throw ArgumentError('note troppo lunghe');
    }
  }

  // -------------------------------------------------------------- Scrittura

  Future<bool> addAppointment(Appointment appointment) => _write(
        () async {
          _validate(appointment);
          await _db.from(_table).insert({
            'visit_type': appointment.type.trim(),
            'appointment_at': appointment.dateTime.toUtc().toIso8601String(),
            'location': appointment.location.trim().isEmpty ? null : appointment.location.trim(),
            'notes': appointment.notes.trim().isEmpty ? null : appointment.notes.trim(),
          });
        },
        where: 'addAppointment',
      );

  Future<bool> updateAppointment(Appointment appointment) => _write(
        () async {
          _validate(appointment);
          final Object id = int.tryParse(appointment.id) ?? appointment.id;
          final rows = await _db
              .from(_table)
              .update({
                'visit_type': appointment.type.trim(),
                'appointment_at': appointment.dateTime.toUtc().toIso8601String(),
                'location':
                    appointment.location.trim().isEmpty ? null : appointment.location.trim(),
                'notes': appointment.notes.trim().isEmpty ? null : appointment.notes.trim(),
              })
              .eq('id', id)
              .select('id');
          if (rows.isEmpty) {
            throw const AppFailure(
              'La visita non esiste più o non puoi modificarla.',
              cause: 'nessuna riga interessata in appointments.update',
            );
          }
        },
        where: 'updateAppointment',
      );

  Future<bool> removeAppointment(String id) => _write(
        () async {
          final Object dbId = int.tryParse(id) ?? id;
          final rows = await _db.from(_table).delete().eq('id', dbId).select('id');
          if (rows.isEmpty) {
            throw const AppFailure(
              'La visita non esiste più o non puoi eliminarla.',
              cause: 'nessuna riga interessata in appointments.delete',
            );
          }
        },
        where: 'removeAppointment',
      );

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
