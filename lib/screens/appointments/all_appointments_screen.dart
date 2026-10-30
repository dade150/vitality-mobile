import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../providers/appointments_provider.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/appointment_card.dart';

enum AppointmentsArchiveTab { upcoming, past }

/// Schermata di archivio completo di tutte le visite (prossime e passate)
/// con ricerca testuale e vocale, simile alla schermata dei referti.
class AllAppointmentsScreen extends StatefulWidget {
  final AppointmentsArchiveTab initialTab;

  const AllAppointmentsScreen({
    super.key,
    this.initialTab = AppointmentsArchiveTab.upcoming,
  });

  @override
  State<AllAppointmentsScreen> createState() => _AllAppointmentsScreenState();
}

class _AllAppointmentsScreenState extends State<AllAppointmentsScreen> {
  late AppointmentsArchiveTab _currentTab;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      if (args == 'past') {
        _currentTab = AppointmentsArchiveTab.past;
      } else if (args == 'upcoming') {
        _currentTab = AppointmentsArchiveTab.upcoming;
      }
    } else if (args is AppointmentsArchiveTab) {
      _currentTab = args;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceListening() async {
    final voice = context.read<VoiceService>();
    if (voice.isListening) {
      await voice.stopListening();
      return;
    }

    final started = await voice.startListening(
      onResult: (words) {
        if (!mounted) return;
        final clean = words.trim();
        setState(() {
          _searchController.text = clean;
          _searchQuery = clean.toLowerCase();
        });
      },
    );

    if (!started && mounted && voice.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(voice.lastError!)),
      );
    }
  }

  Widget _pillButton(String label, AppointmentsArchiveTab tab) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = _currentTab == tab;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }

  void _editVisit(Appointment appt) {
    Navigator.of(context).pushNamed('/appointments/add', arguments: appt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = context.watch<AppointmentsProvider>();
    final voice = context.watch<VoiceService>();

    final allUpcoming = [
      if (provider.next != null) provider.next!,
      ...provider.upcoming,
    ];
    final allPast = provider.past;

    final targetList = _currentTab == AppointmentsArchiveTab.upcoming
        ? allUpcoming
        : allPast;

    final filteredList = targetList.where((appt) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      return appt.type.toLowerCase().contains(q) ||
          appt.doctorName.toLowerCase().contains(q) ||
          appt.location.toLowerCase().contains(q) ||
          appt.notes.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutte le Visite'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Aggiungi visita',
            onPressed: () => Navigator.of(context).pushNamed('/appointments/add'),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Selettore Pillola
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _pillButton('Prossime visite', AppointmentsArchiveTab.upcoming),
                        ),
                        Expanded(
                          child: _pillButton('Storico visite', AppointmentsArchiveTab.past),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Barra di ricerca con comando vocale
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: voice.isListening
                            ? AppColors.accent
                            : cs.outlineVariant.withValues(alpha: 0.4),
                        width: voice.isListening ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                            decoration: const InputDecoration(
                              hintText: 'Cerca visita, medico o luogo...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            tooltip: 'Cancella',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: voice.isListening ? AppColors.accent : cs.onSurfaceVariant,
                          ),
                          tooltip: voice.isListening ? 'Ferma dettatura' : 'Dettatura vocale',
                          onPressed: _toggleVoiceListening,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conteggio e risultati
                  if (filteredList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 56,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Nessuna visita trovata per "$_searchQuery"'
                                : (_currentTab == AppointmentsArchiveTab.upcoming
                                    ? 'Nessuna visita in programma'
                                    : 'Nessuna visita passata registrata'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Prova a cercare un nome diverso o cancella il filtro.'
                                : 'Aggiungi una nuova visita toccando il tasto + in alto.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final appt in filteredList)
                      AppointmentCard(
                        appt: appt,
                        isPast: _currentTab == AppointmentsArchiveTab.past,
                        onEdit: () => _editVisit(appt),
                      ),
                ],
              ),
            ),
    );
  }
}
