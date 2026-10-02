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
          Text('Preferenze Diario', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Seleziona quali moduli desideri attivare per il monitoraggio quotidiano. '
            'Potrai modificarli in seguito dalle impostazioni.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Attività Fisica'),
            value: d.showActivities,
            onChanged: (v) => setState(() => d.showActivities = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pasti'),
            value: d.showMeals,
            onChanged: (v) => setState(() => d.showMeals = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Appuntamenti'),
            value: d.showAppointments,
            onChanged: (v) => setState(() => d.showAppointments = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Documenti / Referti'),
            value: d.showReports,
            onChanged: (v) => setState(() => d.showReports = v),
          ),
          const SizedBox(height: 20),
          Text('Dimensione testo', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'piccolo', label: Text('Piccolo')),
              ButtonSegment(value: 'medio', label: Text('Medio')),
              ButtonSegment(value: 'grande', label: Text('Grande')),
            ],
            selected: {d.fontSize},
            onSelectionChanged: (s) => setState(() => d.fontSize = s.first),
          ),
          const SizedBox(height: 20),
          Text('Tema', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Chiara')),
              ButtonSegment(value: true, label: Text('Scura')),
            ],
            selected: {d.darkMode},
            onSelectionChanged: (s) => setState(() => d.darkMode = s.first),
          ),
          const SizedBox(height: 20),
          Text('Notifiche', style: theme.textTheme.labelLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Promemoria terapia'),
            value: d.notifyTherapy,
            onChanged: (v) => setState(() => d.notifyTherapy = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Promemoria appuntamenti'),
            value: d.notifyAppointments,
            onChanged: (v) => setState(() => d.notifyAppointments = v),
          ),
        ],
      ),
    );
  }
}