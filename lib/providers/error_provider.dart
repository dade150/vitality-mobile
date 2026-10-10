import 'package:flutter/foundation.dart';

import '../services/error_handler.dart';

/// Mixin per i provider (HealthProvider, ecc.): mantiene la firma `bool`
/// delle scritture, ma centralizza la gestione errori.
///
/// - errore atteso    -> [errorMessage] valorizzato, la UI mostra una snackbar
/// - errore imprevisto -> [errorMessage] resta null, compare la schermata errore
mixin ErrorReporting on ChangeNotifier {
  String? errorMessage;

  Future<bool> guard(Future<void> Function() action, {String? where}) async {
    errorMessage = null;
    try {
      await action();
      return true;
    } catch (e, st) {
      final failure = ErrorHandler.handle(e, st, where);
      if (!failure.unexpected) errorMessage = failure.message;
      notifyListeners();
      return false;
    }
  }
}