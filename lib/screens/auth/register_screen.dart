import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/request/registration_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/error_handler.dart';
import '../../services/health_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_feedback.dart';
import 'email_confirmation.dart';
import 'register_step1.dart';
import 'register_step_therapy.dart';
import 'register_step2.dart';
import 'register_step3.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _totalSteps = 4;

  final _pageController = PageController();
  final _data = RegistrationData();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  int _step = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    AppFeedback.showErrorDialog(context, message: message);
  }

  void _goNext() {
    if (_step == 0) {
      if (!(_step1FormKey.currentState?.validate() ?? false)) return;
      if (_data.birth == null) {
        _showSnack('Seleziona la data di nascita.');
        return;
      }
      if (_data.sesso == null) {
        _showSnack('Seleziona il sesso biologico.');
        return;
      }
    }

    // Step 1: Terapia farmacologica (facoltativa) - nessun blocco, si prosegue sempre

    if (_step == 2) {
      if (!(_step2FormKey.currentState?.validate() ?? false)) return;
      if (!_data.termsAccepted) {
        _showSnack('Devi accettare i Termini e Condizioni di Servizio per proseguire.');
        return;
      }
      if (!_data.consensoPrivacy) {
        _showSnack('Devi prestare il consenso esplicito GDPR Art. 9 per il trattamento dei dati sanitari.');
        return;
      }
    }

    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.signUp(
      _data.toMetadata(),
      email: _data.email,
      password: _data.password,
    );

    if (!mounted) return;

    if (ok) {
      // Inserimento farmaci della terapia se la sessione è già attiva
      if (_data.therapies.isNotEmpty && !auth.pendingEmailConfirmation) {
        for (final t in _data.therapies) {
          try {
            await HealthService().insertTherapy(name: t.name, time: t.time);
          } catch (e, st) {
            ErrorHandler.logOnly(e, st, 'RegisterScreen.insertTherapy');
          }
        }
      }

      if (!mounted) return;

      if (auth.pendingEmailConfirmation) {
        // Confirm email ON: utente creato ma sessione nulla, serve la conferma.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EmailConfirmationScreen(email: _data.email)),
        );
      } else {
        // Confirm email OFF: sessione già presente, entra subito nell'app.
        Navigator.of(context).pushNamedAndRemoveUntil('/chat', (r) => false);
      }
    } else if (auth.errorMessage != null) {
      _showSnack(auth.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: auth.isLoading ? null : _goBack,
        ),
        title: const Text('Registrazione'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _StepIndicator(currentStep: _step, totalSteps: _totalSteps),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  RegisterStep1Profile(formKey: _step1FormKey, data: _data),
                  RegisterStepTherapy(data: _data),
                  RegisterStep2Credentials(formKey: _step2FormKey, data: _data),
                  RegisterStep3Settings(data: _data),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: auth.isLoading ? null : _goNext,
                  icon: auth.isLoading
                      ? const SizedBox.shrink()
                      : Icon(
                          _step == _totalSteps - 1
                              ? Icons.check_circle_outline_rounded
                              : Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                  label: auth.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(
                          _step == _totalSteps - 1 ? 'Completa Registrazione' : 'Avanti',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final trackColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i <= currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 8),
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.vibrantOrange : trackColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}