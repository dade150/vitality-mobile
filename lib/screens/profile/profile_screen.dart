import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Accetta sia la virgola sia il punto (tastiera italiana).
  static double? _parseDouble(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    return (v == null || v.isNaN || v.isInfinite) ? null : v;
  }

  Future<void> _editProfile(BuildContext context, ProfileProvider profileProvider) async {
    final profile = profileProvider.profile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.name);
    final surnameController = TextEditingController(text: profile.surname);
    final phoneController = TextEditingController(text: profile.phone);
    final weightController = TextEditingController(text: profile.peso.toStringAsFixed(1));
    final heightController = TextEditingController(text: profile.altezza.toString());

    // Nullable: se manca la data, il campo resta vuoto finché non la scegli.
    DateTime? selectedBirth = profile.birth;
    String gender = profile.sesso;

    try {
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
                final genderItems = [
                  for (final v in Profile.sessoValues)
                    DropdownMenuItem(value: v, child: Text(Profile.labelForSesso(v))),
                  // Valore già nel DB ma non proposto dall'app: va mostrato
                  // altrimenti DropdownButton va in assert.
                  if (gender.isNotEmpty && !Profile.sessoValues.contains(gender))
                    DropdownMenuItem(value: gender, child: Text(Profile.labelForSesso(gender))),
                ];

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modifica Dati', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: surnameController, decoration: const InputDecoration(labelText: 'Cognome'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefono')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final first = DateTime(now.year - 120);
                                // initialDate deve stare tra first e last:
                                // una data fuori range fa assert del date picker.
                                var initial = selectedBirth ?? DateTime(now.year - 60);
                                if (initial.isBefore(first)) initial = first;
                                if (initial.isAfter(now)) initial = now;
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: first,
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  setState(() => selectedBirth = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Data di nascita'),
                                child: Text(selectedBirth == null
                                    ? 'gg/mm/aaaa'
                                    : DateFormat('dd/MM/yyyy').format(selectedBirth!)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: gender.isEmpty ? null : gender,
                              decoration: const InputDecoration(labelText: 'Sesso'),
                              items: genderItems,
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          onPressed: () async {
                            final ok = await profileProvider.updateProfile(
                              name: nameController.text,
                              surname: surnameController.text,
                              phone: phoneController.text,
                              birth: selectedBirth,
                              sesso: gender.isEmpty ? null : gender,
                              peso: _parseDouble(weightController.text) ?? profile.peso,
                              altezza: int.tryParse(heightController.text) ?? profile.altezza,
                            );
                            if (!sheetContext.mounted) return;
                            if (!ok) {
                              // Errore atteso: resta nel form con il motivo.
                              ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                                content: Text(profileProvider.errorMessage ??
                                    'Salvataggio non riuscito. Riprova.'),
                              ));
                              return;
                            }
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
    } finally {
      nameController.dispose();
      surnameController.dispose();
      phoneController.dispose();
      weightController.dispose();
      heightController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return AppScaffold(
        navIndex: 1,
        body: Center(
          child: profileProvider.loadFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
                    const SizedBox(height: 12),
                    const Text('Impossibile caricare il profilo.'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: profileProvider.refresh,
                      child: const Text('Riprova'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

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
                Text('${profile.name} ${profile.surname}', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '${profile.email}\n${profile.phone}\n'
                  'Età: ${profile.age ?? '—'} anni\n'
                  'Sesso: ${profile.sessoLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PillButton(
                  label: 'Modifica Dati',
                  icon: Icons.edit_rounded,
                  filled: true,
                  onTap: () => _editProfile(context, profileProvider),
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
                  value: profile.peso.toStringAsFixed(1),
                  unit: 'kg',
                  color: cs.primary,
                ),
                _VitalStat(
                  icon: Icons.height_rounded,
                  label: 'Altezza',
                  value: profile.altezza.toString(),
                  unit: 'cm',
                  color: cs.secondary,
                ),
                _VitalStat(
                  icon: Icons.speed_rounded,
                  label: 'BMI',
                  value: profile.bmi.toStringAsFixed(1),
                  unit: '(${profile.bmiCategory})',
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
                await auth.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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