import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/appointments_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/clinical_provider.dart';
import '../providers/health_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/reports_provider.dart';
import '../services/error_handler.dart';
import '../services/gdpr_service.dart';

/// Avvia il download dell'archivio JSON dei dati personali e sanitari (GDPR Art. 20)
/// mostrando un indicatore di caricamento.
Future<void> triggerGdprJsonExport(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          margin: EdgeInsets.all(24),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Flexible(
                  child: Text('Preparazione archivio dati JSON (GDPR)...'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  try {
    final bytes = await GdprService.downloadPersonalDataJson();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) return;
    await GdprService.saveJsonBytesToFile(context, bytes);
  } catch (e, st) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    final failure = ErrorHandler.handle(e, st, 'triggerGdprJsonExport');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure.message.isNotEmpty
                ? failure.message
                : 'Impossibile esportare i dati in questo momento. Riprova.',
          ),
        ),
      );
    }
  }
}

/// Apre il dialogo di sicurezza a più livelli per l'eliminazione definitiva
/// dell'account e dei dati sanitari (Diritto all'Oblio - GDPR Art. 17),
/// proponendo prima di scaricare l'archivio JSON dei dati collezionati.
Future<void> showDeleteAccountSecurityDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _DeleteAccountSheetContent(rootContext: context),
  );
}

class _DeleteAccountSheetContent extends StatefulWidget {
  final BuildContext rootContext;

  const _DeleteAccountSheetContent({required this.rootContext});

  @override
  State<_DeleteAccountSheetContent> createState() => _DeleteAccountSheetContentState();
}

class _DeleteAccountSheetContentState extends State<_DeleteAccountSheetContent> {
  bool _confirmedIrreversible = false;
  bool _isExportingJson = false;
  bool _hasExportedJson = false;
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _handleDownloadJsonBeforeDelete() async {
    if (_isExportingJson || _isDeleting) return;
    setState(() {
      _isExportingJson = true;
      _errorMessage = null;
    });

    try {
      final saved = await GdprService.exportAndSaveJson(context);
      if (!mounted) return;
      setState(() {
        _isExportingJson = false;
        if (saved) _hasExportedJson = true;
      });
    } catch (e, st) {
      ErrorHandler.handle(e, st, 'DeleteAccountDialog.exportJson');
      if (!mounted) return;
      setState(() {
        _isExportingJson = false;
        _errorMessage = 'Impossibile scaricare il file JSON. Riprova prima di eliminare.';
      });
    }
  }

  Future<void> _handleConfirmDelete() async {
    if (!_confirmedIrreversible || _isDeleting || _isExportingJson) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      // 1. Cancellazione definitiva lato server e DB (dati sanitari + auth.users)
      await GdprService.deleteAccountAndAllData();

      if (!mounted) return;

      // 2. Pulizia sessione chat e rimozione credenziali d'accesso automatico (AuthChangeEvent.signedOut azzera già i provider clinici)
      final rootCtx = widget.rootContext;
      if (rootCtx.mounted) {
        rootCtx.read<ChatProvider>().clear();
        await rootCtx.read<AuthProvider>().signOut();
      }

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (rootCtx.mounted) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          const SnackBar(
            content: Text(
              'Il tuo account e tutti i tuoi dati sanitari sono stati eliminati definitivamente.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.of(rootCtx).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e, st) {
      final failure = ErrorHandler.handle(e, st, 'DeleteAccountDialog.delete');
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = failure.message.isNotEmpty
            ? failure.message
            : 'Impossibile completare l\'eliminazione in questo momento. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header di sicurezza in rosso
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: cs.onErrorContainer,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elimina Account e Dati Sanitari',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.error,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diritto all\'Oblio (Art. 17 Regolamento UE GDPR)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Avviso di sicurezza dettagliato
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.error.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Attenzione: questa operazione è definitiva e irreversibile.\n'
                '• Verranno cancellati tutti i tuoi dati glicemici, pasti, attività fisica, piano terapeutico, visite mediche, referti e l\'intera cronologia delle chat.\n'
                '• Verranno rimosse anche le credenziali salvate per l\'accesso automatico e verrai riportato alla pagina iniziale di login/registrazione.',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Box invito al salvataggio preventivo del JSON (Art. 20 GDPR)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hasExportedJson
                      ? const Color(0xFF2E7D32)
                      : cs.primary.withValues(alpha: 0.4),
                  width: 1.3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _hasExportedJson
                            ? Icons.check_circle_rounded
                            : Icons.download_for_offline_outlined,
                        color: _hasExportedJson ? const Color(0xFF2E7D32) : cs.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hasExportedJson
                              ? 'Archivio dati JSON scaricato con successo'
                              : 'Vuoi salvare una copia dei tuoi dati prima di eliminarli?',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Prima di procedere con la cancellazione definitiva, puoi scaricare tutti i dati collezionati fino ad oggi in formato strutturato JSON (Art. 20 GDPR).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_isExportingJson || _isDeleting)
                          ? null
                          : _handleDownloadJsonBeforeDelete,
                      icon: _isExportingJson
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _hasExportedJson
                                  ? Icons.download_done_rounded
                                  : Icons.file_download_outlined,
                            ),
                      label: Text(
                        _isExportingJson
                            ? 'Esportazione JSON in corso...'
                            : (_hasExportedJson
                                ? 'Scarica di nuovo il report dati (JSON)'
                                : 'Scarica prima i miei dati (JSON)'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Spunta di sicurezza obbligatoria
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmedIrreversible,
              onChanged: _isDeleting
                  ? null
                  : (v) => setState(() => _confirmedIrreversible = v ?? false),
              title: Text(
                'Ho compreso che l\'eliminazione del mio account e di tutti i miei dati sanitari è definitiva e non potrà essere annullata.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    ),
                    onPressed: (!_confirmedIrreversible || _isDeleting || _isExportingJson)
                        ? null
                        : _handleConfirmDelete,
                    icon: _isDeleting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onError,
                            ),
                          )
                        : const Icon(Icons.delete_forever_rounded),
                    label: Text(_isDeleting ? 'Eliminazione...' : 'Elimina Tutto'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
