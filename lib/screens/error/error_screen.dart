import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/error_handler.dart';

/// Schermata per gli errori imprevisti: immagine, messaggio sotto, tasto OK.
/// OK -> /chat se autenticato, altrimenti /login.
class ErrorScreen extends StatefulWidget {
  const ErrorScreen({super.key});

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  @override
  void dispose() {
    ErrorHandler.onScreenClosed();
    super.dispose();
  }

  void _confirm() {
    final isAuth = context.read<AuthProvider>().isAuthenticated;
    Navigator.of(context).pushNamedAndRemoveUntil(
      isAuth ? '/chat' : '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final args = ModalRoute.of(context)?.settings.arguments;
    final failure = args is AppFailure ? args : null;
    final message = failure?.message ?? ErrorHandler.genericMessage;

    return PopScope(
      canPop: false, // l'unica uscita è il tasto OK
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Ops, qualcosa è andato storto',
                        style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(message,
                        style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                    if (kDebugMode && failure?.cause != null) ...[
                      const SizedBox(height: 16),
                      Text('${failure!.cause}',
                          style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _confirm,
                        child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}