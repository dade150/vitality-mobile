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

  static const String currentTermsVersion = '1.1';
  static const String currentPrivacyVersion = '1.1';

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
      heading: '1. Cos\'è diaLog2',
      body:
          'diaLog2 è un assistente conversazionale di supporto per persone con Diabete Mellito di Tipo 2.\n'
          'Ti aiuta a registrare e consultare il tuo diario quotidiano (glicemie, pressione, pasti, attività fisica, terapie prescritte dal medico, visite e referti) e offre indicazioni educazionali e motivazionali basate su linee guida cliniche ufficiali.',
    ),
    LegalSection(
      heading: '2. Cosa NON è (Esclusione Dispositivo Medico MDR UE 2017/745)',
      body:
          'diaLog2 NON è un dispositivo medico e non sostituisce in alcun modo il medico curante o il diabetologo.\n'
          '• L\'applicazione non effettua diagnosi mediche.\n'
          '• L\'assistente non prescrive farmaci né modifica dosaggi di insulina o di ipoglicemizzanti orali.\n'
          '• Qualsiasi scelta terapeutica o variazione di cura deve essere sempre concordata con il proprio medico.',
    ),
    LegalSection(
      heading: '3. Gestione delle Emergenze Sanitarie',
      body:
          'diaLog2 non è un servizio di pronto soccorso né di telemedicina d\'urgenza. In caso di sintomi acuti o malessere improvviso (ipoglicemie severe, chetoacidosi, dolore toracico, difficoltà respiratoria, perdita di sensi), non attendere le risposte dell\'app: contatta immediatamente il 112/118 o recati al Pronto Soccorso.',
    ),
    LegalSection(
      heading: '4. Controllo e Conferma Umana dei Dati (Art. 14 EU AI Act)',
      body:
          'Tutti i valori clinici estratti dalle conversazioni o dai documenti caricati vengono salvati nel diario solo ed esclusivamente dopo che li hai verificati e confermati tramite le apposite schede di proposta.',
    ),
    LegalSection(
      heading: '5. Finalità di Tesi Accademica e Responsabilità',
      body:
          'L\'applicazione è un prototipo di ricerca sviluppato a scopo accademico e di tesi di laurea, fornito "così com\'è". L\'utente è responsabile della veridicità e accuratezza delle informazioni inserite.',
    ),
  ];

  static const List<LegalSection> _privacySections = [
    LegalSection(
      heading: '1. Titolare del Trattamento e Categorie di Dati (Art. 9 GDPR)',
      body:
          'Titolare del trattamento: Davide Cruciata (progetto di tesi accademica).\n'
          'Trattiamo le seguenti categorie di dati:\n'
          '• Dati anagrafici e di account: nome, cognome, data di nascita, sesso biologico ed email.\n'
          '• Dati particolari sulla salute (Art. 9 GDPR): glicemie, pressione arteriosa, HbA1c, esami ematochimici, diario pasti, attività fisica, terapie, appuntamenti, referti medici e messaggi scambiati con l\'assistente.',
    ),
    LegalSection(
      heading: '2. Basi Giuridiche del Trattamento (Art. 6 e Art. 9 GDPR)',
      body:
          '• Esecuzione del contratto di servizio (Art. 6.1.b GDPR): per l\'erogazione delle funzionalità dell\'applicazione e la gestione del profilo.\n'
          '• Consenso esplicito dell\'interessato (Art. 9.2.a GDPR): per il trattamento dei dati relativi alla salute e la loro elaborazione tramite modelli di Intelligenza Artificiale a fini di coaching educazionale.',
    ),
    LegalSection(
      heading: '3. Elaborazione con Intelligenza Artificiale e Trattamento Documenti',
      body:
          'L\'elaborazione dell\'assistente conversazionale avviene tramite Google Cloud Vertex AI (modelli Gemini) nella regione Unione Europea:\n'
          '• PDF digitali nativi: il testo viene estratto in memoria e pseudonimizzato prima dell\'invio (rimozione automatica di Codice Fiscale, nominativi, contatti, indirizzi e strutture ospedaliere).\n'
          '• Immagini e PDF scansionati: vengono trasmessi in modalità multimodale protetta per la sola lettura ottica ed estrazione clinica. Si raccomanda di coprire o non inquadrare il nome e il Codice Fiscale prima dello scatto o del caricamento.\n'
          '• Archiviazione del file originale: una copia del documento caricato (con metadati EXIF e GPS rimossi) viene conservata nel tuo spazio cloud privato protetto da isolamento Row-Level Security (RLS), accessibile solo a te, per consentirti di consultarlo e riscaricarlo in qualunque momento.\n'
          '• I dati non vengono mai utilizzati per addestrare modelli di Intelligenza Artificiale pubblici o di terze parti.',
    ),
    LegalSection(
      heading: '4. Conservazione dei Dati e Misure di Sicurezza (Art. 5 e Art. 32 GDPR)',
      body:
          'I dati risiedono su infrastruttura Supabase (regione UE) con trasmissione protetta da cifratura TLS 1.3 e isolamento dei dati per singolo utente tramite politiche PostgreSQL Row-Level Security (RLS).\n'
          'Le conversazioni di chat sono conservate fino a un massimo di 12 mesi o fino alla cancellazione manuale.',
    ),
    LegalSection(
      heading: '5. Diritti dell\'Interessato e Revoca del Consenso (Artt. 15–22 GDPR)',
      body:
          'Dalla sezione Impostazioni > Privacy e Dati Sanitari puoi in qualunque momento:\n'
          '• Esportare una copia integrale dei tuoi dati sanitari in formato JSON strutturato (Diritto alla Portabilità - Art. 20 GDPR).\n'
          '• Cancellare l\'intera cronologia delle conversazioni.\n'
          '• Eliminare definitivamente il tuo account e tutti i dati associati (Diritto all\'Oblio - Art. 17 GDPR), revocando contemporaneamente il consenso prestato.\n'
          'Hai inoltre il diritto di proporre reclamo all\'Autorità Garante per la Protezione dei Dati Personali (www.garanteprivacy.it).',
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
