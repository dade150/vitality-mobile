import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// Mostrata dopo una registrazione riuscita quando "Confirm email" è attivo
/// su Supabase (comportamento di default): a questo punto esiste un utente
/// in `auth.users` ma la sessione è ancora nulla finché non conferma.
class EmailConfirmationScreen extends StatefulWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendConfirmation(widget.email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Email inviata di nuovo.' : (auth.errorMessage ?? 'Errore. Riprova.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_read_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Controlla la tua email',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ti abbiamo inviato un link di conferma a ${widget.email}. '
                  'Aprilo dal tuo telefono per attivare l\'account.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: auth.isLoading ? null : _resend,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Invia di nuovo l'email"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Torna al login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}