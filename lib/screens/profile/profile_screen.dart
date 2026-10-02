import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editProfile(BuildContext context, UserProvider user) async {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone);
    final ageController = TextEditingController(text: user.age.toString());
    final weightController = TextEditingController(text: user.weightKg.toStringAsFixed(0));
    final heightController = TextEditingController(text: user.heightCm.toStringAsFixed(0));
    String gender = user.gender;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modifica Dati', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome e Cognome')),
                    const SizedBox(height: 12),
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 12),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefono')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Età'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: gender,
                            decoration: const InputDecoration(labelText: 'Sesso'),
                            items: const [
                              DropdownMenuItem(value: 'Maschio', child: Text('Maschio')),
                              DropdownMenuItem(value: 'Femmina', child: Text('Femmina')),
                              DropdownMenuItem(value: 'Altro', child: Text('Altro')),
                            ],
                            onChanged: (v) => setState(() => gender = v ?? gender),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Peso (kg)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: heightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Altezza (cm)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          user.updateProfile(
                            name: nameController.text,
                            email: emailController.text,
                            phone: phoneController.text,
                            age: int.tryParse(ageController.text) ?? user.age,
                            gender: gender,
                            weightKg: double.tryParse(weightController.text) ?? user.weightKg,
                            heightCm: double.tryParse(heightController.text) ?? user.heightCm,
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Salva'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = context.watch<UserProvider>();

    return AppScaffold(
      navIndex: 1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.person_rounded, size: 48, color: cs.primary),
                ),
                const SizedBox(height: 16),
                Text(user.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '${user.email}\n${user.phone}\nEtà: ${user.age} anni\nSesso: ${user.gender}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PillButton(
                  label: 'Modifica Dati',
                  icon: Icons.edit_rounded,
                  filled: true,
                  onTap: () => _editProfile(context, user),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Parametri Vitali', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 520 ? 3 : 1;
              final items = [
                _VitalStat(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Peso',
                  value: user.weightKg.toStringAsFixed(0),
                  unit: 'kg',
                  color: cs.primary,
                ),
                _VitalStat(
                  icon: Icons.height_rounded,
                  label: 'Altezza',
                  value: user.heightCm.toStringAsFixed(0),
                  unit: 'cm',
                  color: cs.secondary,
                ),
                _VitalStat(
                  icon: Icons.speed_rounded,
                  label: 'BMI',
                  value: user.bmi.toStringAsFixed(1),
                  unit: '(${user.bmiCategory})',
                  color: cs.tertiary,
                ),
              ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3.4 : 1.15,
                children: items,
              );
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await auth.signOut();          // 1) PRIMA aspetta: sessione azzerata
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);  // 2) POI naviga
            },
            icon: Icon(Icons.logout_rounded, color: cs.error),
            label: Text('Esci', style: TextStyle(color: cs.error)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _VitalStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text.rich(
                  TextSpan(
                    text: value,
                    style: theme.textTheme.headlineSmall,
                    children: [
                      TextSpan(text: ' $unit', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
