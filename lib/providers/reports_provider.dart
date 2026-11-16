import 'dart:async';

import '../models/medical_report.dart';
import '../services/error_handler.dart';
import 'auth_scoped_provider.dart';

/// Stato dei referti medici caricati dall'utente, collegato alla tabella
/// `patient_reports` di Supabase (nessun dato mockato).
class ReportsProvider extends AuthScopedProvider {
  static const _table = 'patient_reports';

  ReportsProvider([super.client]);

  final List<MedicalReport> _reports = [];

  List<MedicalReport> get reports => List.unmodifiable(_reports);

  @override
  void onClearState() {
    _reports.clear();
  }

  @override
  Future<void> refresh() async {
    final uid = userId;
    if (uid == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final rows = await db
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      if (uid != userId) return;

      final loaded = <MedicalReport>[];
      for (final r in rows) {
        final id = r['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final rawTitle = (r['source_name'] ?? r['title'] ?? r['file_name'] ?? 'Referto medico').toString().trim();
        final rawDate = (r['report_at'] ?? r['report_date'] ?? r['created_at'])?.toString() ?? '';
        final parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();

        final extractedMap = <String, String>{};
        final rawExtracted = r['extracted_params'] ?? r['extracted'];
        if (rawExtracted is Map) {
          for (final entry in rawExtracted.entries) {
            extractedMap[entry.key.toString()] = entry.value.toString();
          }
        }

        final cleanSummary = (r['clean_summary'] ?? r['summary'])?.toString();
        final filePath = r['file_path']?.toString();

        // Preserva i parametri estratti in memoria se il referto è appena stato caricato
        final existing = _reports.where((e) => e.id == id).firstOrNull;
        loaded.add(
          MedicalReport(
            id: id,
            title: rawTitle.isEmpty ? 'Referto medico' : rawTitle,
            date: parsedDate,
            cleanSummary: cleanSummary ?? existing?.cleanSummary,
            filePath: filePath ?? existing?.filePath,
            extractedParams: extractedMap.isNotEmpty
                ? extractedMap
                : (existing?.extractedParams ?? const {}),
          ),
        );
      }

      _reports
        ..clear()
        ..addAll(loaded);
      hasLoaded = true;
    } catch (e, st) {
      ErrorHandler.logOnly(e, st, 'ReportsProvider.refresh');
      hasLoaded = true;
    } finally {
      if (uid == userId) {
        isLoading = false;
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
        await db.from(_table).delete().eq('id', id);
      },
      where: 'ReportsProvider.deleteReport',
    );
    if (ok) {
      _reports.removeWhere((r) => r.id == id);
      notifyListeners();
    }
    return ok;
  }
}
