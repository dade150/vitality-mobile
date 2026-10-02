import 'package:flutter/material.dart';
import '../../models/request/registration_request.dart';

class RegisterStep2Credentials extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final RegistrationData data;

  const RegisterStep2Credentials({
    super.key,
    required this.formKey,
    required this.data,
  });

  @override
  State<RegisterStep2Credentials> createState() => _RegisterStep2CredentialsState();
}

class _RegisterStep2CredentialsState extends State<RegisterStep2Credentials> {
  late final _emailController = TextEditingController(text: widget.data.email);
  late final _passwordController = TextEditingController(text: widget.data.password);
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  late String _passwordValue = widget.data.password;
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _uppercaseRegex = RegExp(r'[A-Z]');
  static final _digitRegex = RegExp(r'[0-9]');
  // eslint-ish: caratteri speciali comuni, incluso backslash escapato.
  static final _specialRegex = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]~`/\\]''');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Inserisci una password';
    if (value.length < 10) return 'Almeno 10 caratteri';
    if (!_uppercaseRegex.hasMatch(value)) return 'Serve almeno una lettera maiuscola';
    if (!_digitRegex.hasMatch(value)) return 'Serve almeno un numero';
    if (!_specialRegex.hasMatch(value)) return 'Serve almeno un carattere speciale';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: widget.formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credenziali di Accesso', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Indirizzo Email',
                hintText: 'es. mario.rossi@email.com',
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => widget.data.email = v.trim(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Inserisci la tua email';
                if (!_emailRegex.hasMatch(v.trim())) return 'Email non valida';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Crea una password sicura',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onChanged: (v) {
                widget.data.password = v;
                setState(() => _passwordValue = v);
                // Se la conferma è già stata scritta, rivalidala subito:
                // altrimenti un errore di mancata corrispondenza comparirebbe
                // solo al prossimo tocco del campo "Conferma", non appena
                // modifichi la password.
                if (_confirmController.text.isNotEmpty) {
                  _confirmFieldKey.currentState?.validate();
                }
              },
              validator: _validatePassword,
            ),
            const SizedBox(height: 8),
            _PasswordRequirements(password: _passwordValue),
            const SizedBox(height: 16),
            TextFormField(
              key: _confirmFieldKey,
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Conferma Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v != widget.data.password) return 'Le password non coincidono';
                return null;
              },
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: widget.data.consensoPrivacy,
              onChanged: (v) => setState(() => widget.data.consensoPrivacy = v ?? false),
              title: const Text(
                'Accetto il trattamento dei miei dati sanitari secondo la normativa GDPR',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elenco dei requisiti della password che si aggiorna in tempo reale,
/// un check verde per ogni condizione soddisfatta mentre l'utente scrive.
class _PasswordRequirements extends StatelessWidget {
  final String password;
  const _PasswordRequirements({required this.password});

  static final _uppercaseRegex = RegExp(r'[A-Z]');
  static final _digitRegex = RegExp(r'[0-9]');
  static final _specialRegex = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]~`/\\]''');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requirements = <(String, bool)>[
      ('Almeno 10 caratteri', password.length >= 10),
      ('Una lettera maiuscola', _uppercaseRegex.hasMatch(password)),
      ('Un numero', _digitRegex.hasMatch(password)),
      ('Un carattere speciale', _specialRegex.hasMatch(password)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: requirements.map((r) {
        final (label, met) = r;
        final color = met ? Colors.green : theme.colorScheme.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(met ? Icons.check_circle : Icons.circle_outlined, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}