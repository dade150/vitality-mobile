import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/request/registration_request.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import 'email_confirmation.dart';
import 'register_step1.dart';
import 'register_step2.dart';
import 'register_step3.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _totalSteps = 3;

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

    if (_step == 1) {
      if (!(_step2FormKey.currentState?.validate() ?? false)) return;
      if (!_data.consensoPrivacy) {
        _showSnack('Devi accettare il trattamento dei dati per proseguire.');
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
      if (auth.pendingEmailConfirmation) {
        // Confirm email ON: utente creato ma sessione nulla, serve la conferma.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EmailConfirmationScreen(email: _data.email)),
        );
      } else {
        // Confirm email OFF: sessione già presente, entra subito nell'app.
        Navigator.of(context).pushNamedAndRemoveUntil('/diary', (r) => false);
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
                  RegisterStep2Credentials(formKey: _step2FormKey, data: _data),
                  RegisterStep3Settings(data: _data),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _goNext,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_step == _totalSteps - 1 ? 'Completa Registrazione' : 'Avanti'),
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