import 'package:flutter/material.dart';

/// Bottom sheet riutilizzabile per la consultazione dei documenti legali
/// (Termini e Condizioni di Servizio & Informativa Privacy Art. 13 e Art. 9 GDPR),
/// richiamabile sia in fase di registrazione sia dalle Impostazioni del profilo.
class LegalDocumentsSheet extends StatelessWidget {
  final String title;
  final String version;
  final List<LegalSection> sections;

  const LegalDocumentsSheet._({
    required this.title,
    required this.version,
    required this.sections,
  });

  static const String currentTermsVersion = '1.0';
  static const String currentPrivacyVersion = '1.0';

  static Future<void> showTermsOfService(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LegalDocumentsSheet._(
        title: 'Termini e Condizioni di Servizio',
        version: currentTermsVersion,
        sections: _termsSections,
      ),
    );
  }

  static Future<void> showPrivacyPolicy(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LegalDocumentsSheet._(
        title: 'Informativa Privacy e Dati Sanitari (GDPR)',
        version: currentPrivacyVersion,
        sections: _privacySections,
      ),
    );
  }

  static const List<LegalSection> _termsSections = [
    LegalSection(
      heading: '1. Natura del Servizio (Health Coaching Educazionale)',
      body:
          'diaLog2 è un assistente conversazionale di supporto motivazionale, educazionale e di stile di vita dedicato alle persone con Diabete Mellito di Tipo 2.\n'
          'L\'applicazione aiuta l\'utente a tenere traccia del proprio diario giornaliero (glicemie, pasti, attività fisica, terapie prescritte dal medico, appuntamenti e referti) e fornisce informazioni educative basate su linee guida cliniche ufficiali.',
    ),
    LegalSection(
      heading: '2. Esclusione di Dispositivo Medico (MDR UE 2017/745)',
      body:
          'diaLog2 NON è un dispositivo medico ai sensi del Regolamento (UE) 2017/745 (MDR) e non sostituisce in alcun modo il medico curante o il diabetologo.\n'
          '• L\'assistente AI non formula diagnosi mediche.\n'
          '• L\'assistente AI non prescrive farmaci e non suggerisce né modifica dosaggi di insulina o di ipoglicemizzanti orali.\n'
          '• Qualsiasi decisione terapeutica o clinica deve essere sempre concordata con il proprio medico.',
    ),
    LegalSection(
      heading: '3. Gestione delle Emergenze Sanitarie',
      body:
          'diaLog2 non è un servizio di pronto soccorso né di telemedicina d\'urgenza. In presenza di sintomi acuti (ipoglicemia severa, iperglicemia critica, dolore toracico, difficoltà respiratoria, stato confusionale o malessere improvviso), non attendere la risposta dell\'app: contatta immediatamente il 112 o recati al Pronto Soccorso.',
    ),
    LegalSection(
      heading: '4. Conferma Umana dei Dati Estratti (Human-in-the-Loop)',
      body:
          'Ai sensi dell\'Art. 14 dell\'EU AI Act, nessun dato clinico estratto dalla conversazione o dalle foto/PDF dei referti viene salvato automaticamente nel diario senza la tua verifica e conferma esplicita tramite le apposite schede di proposta.',
    ),
  ];

  static const List<LegalSection> _privacySections = [
    LegalSection(
      heading: '1. Categorie di Dati Trattati (Art. 9 GDPR)',
      body:
          'Per erogare il servizio di diario e coaching, diaLog2 tratta:\n'
          '• Dati anagrafici e di contatto (nome, cognome, data di nascita, sesso biologico, email).\n'
          '• Categorie particolari di dati relativi alla salute (Art. 9 GDPR): misurazioni glicemiche, pressione arteriosa, emoglobina glicata (HbA1c), profilo lipidico, diario alimentare, attività fisica, piano terapeutico, visite mediche, testo/immagini di referti caricati e cronologia della chat.',
    ),
    LegalSection(
      heading: '2. Basi Giuridiche del Trattamento (Art. 6 e Art. 9 GDPR)',
      body:
          '• Esecuzione del contratto di servizio (Art. 6.1.b GDPR): per la gestione dell\'account e delle funzionalità base dell\'applicazione.\n'
          '• Consenso esplicito dell\'interessato (Art. 9.2.a e Art. 22 GDPR): per il trattamento dei dati relativi alla salute e per la loro elaborazione – previa rigorosa de-identificazione – tramite modelli di Intelligenza Artificiale (Google Cloud Vertex AI, regione Unione Europea).',
    ),
    LegalSection(
      heading: '3. Privacy-by-Design e De-identificazione prima dell\'IA',
      body:
          'Prima di inviare qualsiasi quesito o testo di referto al modello linguistico (Vertex AI EU):\n'
          '• I metadati EXIF/GPS vengono rimossi dalle immagini caricate.\n'
          '• I PDF digitali vengono ispezionati in memoria RAM rimuovendo Codici Fiscali, numeri di telefono, indirizzi email, indirizzi fisici e nomi di ospedali.\n'
          '• Il nome del paziente e del medico vengono sostituiti con segnaposto anonimi ({{NOME}}, {{MEDICO}}) e re-idratati solo sul tuo dispositivo.\n'
          '• I dati non vengono mai utilizzati per addestrare modelli di Intelligenza Artificiale di terze parti.',
    ),
    LegalSection(
      heading: '4. Conservazione dei Dati e Sicurezza (Art. 5.1.e e Art. 32 GDPR)',
      body:
          'I dati sono protetti nel database Supabase tramite isolamento crittografico Row-Level Security (RLS) associato esclusivamente al tuo utente. La cronologia delle conversazioni può essere cancellata in ogni momento dall\'utente ed è soggetta a limitazione della conservazione.',
    ),
    LegalSection(
      heading: '5. Diritti dell\'Interessato (Art. 7.3 e Artt. 15–22 GDPR)',
      body:
          'Dalla sezione Impostazioni > Privacy e Dati Sanitari puoi in qualsiasi momento:\n'
          '• Consultare lo stato dei consensi prestati e i presenti documenti.\n'
          '• Scaricare una copia integrale dei tuoi dati sanitari in formato strutturato JSON (Diritto alla Portabilità - Art. 20 GDPR).\n'
          '• Cancellare l\'intera cronologia delle conversazioni con l\'assistente.\n'
          '• Revocare il consenso ed eliminare definitivamente il tuo account e tutti i dati sanitari associati (Diritto all\'Oblio - Art. 17 GDPR).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v$version',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: sections.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, idx) {
                    final s = sections[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.heading,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ho letto e compreso'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LegalSection {
  final String heading;
  final String body;

  const LegalSection({
    required this.heading,
    required this.body,
  });
}
