import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/medical_report.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_card.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  bool _uploaded = false;
  bool _uploading = false;

  Future<void> _simulateUpload() async {
    setState(() => _uploading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _uploaded = true;
    });
    context.read<ReportsProvider>().addReport(
          MedicalReport(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Referto Caricato',
            date: DateTime.now(),
            extractedParams: const {
              'HbA1c': '6.8%',
              'eGFR': '92 mL/min',
              'UACR': '15 mg/g',
              'Pressione': '120/80',
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      navIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              // Titolo sempre arancione, indipendentemente dal tema (chiaro/scuro).
              Text('Aggiungi Referto', style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _simulateUpload,
              icon: _uploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_uploading ? 'Caricamento...' : 'Carica Documento'),
            ),
          ),
          if (_uploaded) ...[
            const SizedBox(height: 28),
            Text('Parametri Clinici Estratti', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                children: [
                  _paramRow(context, icon: Icons.bloodtype_outlined, label: 'HbA1c', value: '6.8%'),
                  const Divider(),
                  // eGFR (velocità di filtrazione renale): icona semplice a "imbuto/filtro".
                  _paramRow(context, icon: Icons.filter_alt_outlined, label: 'eGFR', value: '92 mL/min'),
                  const Divider(),
                  _paramRow(context, icon: Icons.science_outlined, label: 'UACR', value: '15 mg/g'),
                  const Divider(),
                  _paramRow(context, icon: Icons.favorite_outline_rounded, label: 'Pressione', value: '120/80'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Note e Screening Medici', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _noteRow(context,
                      icon: Icons.visibility_outlined,
                      title: 'Visita Oculistica',
                      date: '15 Maggio 2023',
                      note: 'Retinopatia assente, prossimo controllo tra 1 anno.'),
                  const SizedBox(height: 16),
                  _noteRow(context,
                      icon: Icons.directions_walk_outlined,
                      title: 'Controllo Piede',
                      date: '10 Aprile 2023',
                      note: 'Nessuna lesione riscontrata, sensibilità conservata.'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Attività Recente', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.description_outlined, color: cs.primary),
                    title: const Text('Referto Cardiologico'),
                    subtitle: const Text('Oggi, 10:30'),
                    trailing: Icon(Icons.check_circle_rounded, color: cs.secondary),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.image_outlined, color: cs.primary),
                    title: const Text('Ricetta Medica'),
                    subtitle: const Text('Ieri, 15:45'),
                    trailing: Icon(Icons.check_circle_rounded, color: cs.secondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paramRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(color: cs.primary)),
        ],
      ),
    );
  }

  Widget _noteRow(BuildContext context,
      {required IconData icon, required String title, required String date, required String note}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                  Text(date, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(note, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }
}
