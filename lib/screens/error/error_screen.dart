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
                    Image.asset(
                      'assets/images/error.png',
                      height: 220,
                      fit: BoxFit.contain,
                      semanticLabel: 'Illustrazione di errore',
                      // Fallback finché non aggiungi l'immagine.
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.error_outline_rounded, size: 120, color: cs.primary),
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
                      child: ElevatedButton(onPressed: _confirm, child: const Text('OK')),
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