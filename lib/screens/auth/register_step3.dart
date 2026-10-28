import 'package:flutter/material.dart';
import '../../models/request/registration_request.dart';

class RegisterStep3Settings extends StatefulWidget {
  final RegistrationData data;

  const RegisterStep3Settings({super.key, required this.data});

  @override
  State<RegisterStep3Settings> createState() => _RegisterStep3SettingsState();
}

class _RegisterStep3SettingsState extends State<RegisterStep3Settings> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personalizzazione e Preferenze', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Imposta le tue preferenze per la visualizzazione dell\'app e le notifiche. '
            'Potrai modificarle in qualsiasi momento dalle impostazioni.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('Dimensione testo', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'PICCOLO', label: Text('Piccolo')),
              ButtonSegment(value: 'MEDIO', label: Text('Medio')),
              ButtonSegment(value: 'GRANDE', label: Text('Grande')),
            ],
            selected: {d.fontSize.toUpperCase()},
            onSelectionChanged: (s) => setState(() => d.fontSize = s.first),
          ),
          const SizedBox(height: 24),
          Text('Tema', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Chiaro'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: true, label: Text('Scuro'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {d.darkMode},
            onSelectionChanged: (s) => setState(() => d.darkMode = s.first),
          ),
          const SizedBox(height: 24),
          Text('Notifiche', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Promemoria terapia'),
            value: d.notifyTherapy,
            onChanged: (v) => setState(() => d.notifyTherapy = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.calendar_month_outlined),
            title: const Text('Promemoria appuntamenti'),
            value: d.notifyAppointments,
            onChanged: (v) => setState(() => d.notifyAppointments = v),
          ),
        ],
      ),
    );
  }
}
