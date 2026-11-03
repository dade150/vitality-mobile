import 'package:flutter/material.dart';
import '../../models/request/registration_request.dart';
import '../../widgets/section_card.dart';

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
          Text('Tema', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                RadioListTile<bool>(
                  secondary: const Icon(Icons.light_mode_outlined),
                  title: const Text('Tema chiaro'),
                  value: false,
                  groupValue: d.darkMode,
                  onChanged: (val) {
                    if (val != null) setState(() => d.darkMode = val);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<bool>(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Tema scuro'),
                  value: true,
                  groupValue: d.darkMode,
                  onChanged: (val) {
                    if (val != null) setState(() => d.darkMode = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Dimensione testo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                RadioListTile<String>(
                  secondary: const Icon(Icons.format_size_rounded, size: 18),
                  title: const Text('Piccolo'),
                  value: 'PICCOLO',
                  groupValue: d.fontSize.toUpperCase(),
                  onChanged: (val) {
                    if (val != null) setState(() => d.fontSize = val);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  secondary: const Icon(Icons.format_size_rounded, size: 22),
                  title: const Text('Medio'),
                  value: 'MEDIO',
                  groupValue: d.fontSize.toUpperCase(),
                  onChanged: (val) {
                    if (val != null) setState(() => d.fontSize = val);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  secondary: const Icon(Icons.format_size_rounded, size: 26),
                  title: const Text('Grande'),
                  value: 'GRANDE',
                  groupValue: d.fontSize.toUpperCase(),
                  onChanged: (val) {
                    if (val != null) setState(() => d.fontSize = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Notifiche', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Promemoria terapia'),
                  value: d.notifyTherapy,
                  onChanged: (v) => setState(() => d.notifyTherapy = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Promemoria visite'),
                  value: d.notifyAppointments,
                  onChanged: (v) => setState(() => d.notifyAppointments = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
