import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../models/request/registration_request.dart';
import '../../widgets/legal_documents_sheet.dart';

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
  late final TapGestureRecognizer _termsTapRecognizer;
  late final TapGestureRecognizer _privacyTapRecognizer;
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
  void initState() {
    super.initState();
    _termsTapRecognizer = TapGestureRecognizer()
      ..onTap = () => LegalDocumentsSheet.showTermsOfService(context);
    _privacyTapRecognizer = TapGestureRecognizer()
      ..onTap = () => LegalDocumentsSheet.showPrivacyPolicy(context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
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
    final colorScheme = theme.colorScheme;

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
            const SizedBox(height: 20),
            Text(
              'Consensi Legali e Privacy (GDPR)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            // 1. Termini di Servizio e presa visione Informativa (GDPR Art. 6.1.b & Art. 13)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: widget.data.termsAccepted,
              onChanged: (v) => setState(() => widget.data.termsAccepted = v ?? false),
              title: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  children: [
                    const TextSpan(text: 'Dichiaro di aver letto e accettato i '),
                    TextSpan(
                      text: 'Termini e Condizioni di Servizio',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _termsTapRecognizer,
                    ),
                    const TextSpan(
                      text:
                          ' (inclusa la natura educazionale e non sostitutiva del medico) e di aver preso visione dell\'',
                    ),
                    TextSpan(
                      text: 'Informativa sulla Privacy (Art. 13 GDPR)',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _privacyTapRecognizer,
                    ),
                    const TextSpan(text: '. *'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 2. Consenso Esplicito Dati Sanitari & AI (GDPR Art. 9.2.a & Art. 22)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: widget.data.consensoPrivacy,
              onChanged: (v) => setState(() => widget.data.consensoPrivacy = v ?? false),
              title: Text(
                'Presto il consenso esplicito (Art. 9.2.a GDPR) al trattamento dei miei dati relativi alla salute (glicemie, pasti, terapie, referti) e alla loro elaborazione – previa de-identificazione – tramite sistemi di Intelligenza Artificiale per ricevere supporto educazionale. *',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Puoi revocare il consenso o cancellare i tuoi dati in qualsiasi momento dalle Impostazioni.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
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
