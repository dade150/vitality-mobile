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

  static const String currentTermsVersion = '1.2';
  static const String currentPrivacyVersion = '1.2';

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
      heading: '1. Titolare del Trattamento e Categorie di Dati (Art. 13 e Art. 9 GDPR)',
      body:
          'Titolare del trattamento: Davide Cruciata — progetto accademico di tesi magistrale (Università eCampus).\n'
          'Contatto per l\'esercizio dei diritti GDPR: tramite i riferimenti accademici del Titolare comunicati ai partecipanti dello studio pilota.\n\n'
          'Trattiamo le seguenti categorie di dati:\n'
          '• Dati anagrafici e di account: nome, cognome, data di nascita, sesso biologico ed email.\n'
          '• Dati particolari sulla salute (Art. 9 GDPR): glicemie, pressione arteriosa, HbA1c, esami ematochimici, diario pasti, attività fisica, terapie, appuntamenti, referti medici e messaggi scambiati con l\'assistente.',
    ),
    LegalSection(
      heading: '2. Basi Giuridiche del Trattamento (Art. 6, Art. 7 e Art. 9 GDPR)',
      body:
          '• Esecuzione del servizio (Art. 6.1.b GDPR): gestione dell\'account e delle impostazioni applicative.\n'
          '• Consenso esplicito per il diario sanitario (Art. 9.2.a GDPR): archiviazione e consultazione dei dati clinici personali.\n'
          '• Consenso esplicito separato e facoltativo per l\'Intelligenza Artificiale (Art. 7.4 e Art. 9.2.a GDPR): elaborazione pseudonimizzata per coaching conversazionale, estrazione referti e stima nutrizionale. È revocabile in qualunque momento senza perdere accesso al Diario.',
    ),
    LegalSection(
      heading: '3. Destinatari, Sub-Responsabili ed Elaborazione AI (Art. 13.1.e GDPR)',
      body:
          'Per erogare il servizio ci avvaliamo dei seguenti fornitori infrastrutturali configurati in Unione Europea:\n'
          '• Supabase (regione UE Irlanda - eu-west-1): database PostgreSQL, autenticazione JWT e object storage cifrato protetti da Row-Level Security (RLS).\n'
          '• Render (regione UE): esecuzione del server applicativo FastAPI che orchestra la de-identificazione in RAM e le chiamate AI.\n'
          '• Google Cloud Vertex AI (regione Unione Europea): modelli Gemini per chat, estrazione referti e stima nutrizionale; i dati non vengono mai usati per addestrare modelli di terze parti.\n'
          '• Servizi di sistema del dispositivo: il riconoscimento vocale (STT) e la sintesi vocale (TTS) utilizzano i motori del sistema operativo mobile; il caricamento dei font tipografici può richiedere una connessione ai server Google Fonts.\n\n'
          'Misure specifiche sui documenti clinici:\n'
          '• PDF digitali nativi: il testo viene estratto in RAM e pseudonimizzato prima dell\'invio (rimozione di CF, nomi, contatti, indirizzi e strutture sanitarie).\n'
          '• Foto e PDF scansionati: è disponibile una Privacy Mask visuale preventiva per oscurare l\'intestazione; i metadati EXIF/GPS vengono rimossi automaticamente.\n'
          '• Copia archiviata: conservata nel bucket privato isolato tramite RLS e scaricabile esclusivamente con autenticazione.',
    ),
    LegalSection(
      heading: '4. Conservazione dei Dati e Misure di Sicurezza (Art. 5 e Art. 32 GDPR)',
      body:
          '• Cronologia conversazioni chat: conservata fino a un massimo di 12 mesi (cancellazione automatica notturna tramite job pianificato) o fino alla cancellazione manuale immediata.\n'
          '• Dati del diario clinico, esami e referti: conservati per l\'intera durata dell\'account (e dello studio pilota) fino a cancellazione selettiva o eliminazione definitiva dell\'account.\n'
          '• Sicurezza: trasmissione cifrata TLS/HTTPS, credenziali protette con FlutterSecureStorage cifrato, isolamento multiutente stretto mediante RLS `auth.uid()`.',
    ),
    LegalSection(
      heading: '5. Diritti dell\'Interessato e Revoca del Consenso (Artt. 15–22 GDPR)',
      body:
          'Dalla sezione Impostazioni > Privacy e gestione dati (GDPR) puoi in qualunque momento:\n'
          '• Attivare o revocare il consenso all\'elaborazione con Intelligenza Artificiale (Art. 7.3 GDPR) mantenendo intatto il Diario.\n'
          '• Accedere e rettificare i tuoi dati clinici e anagrafici direttamente dalle sezioni Profilo, Diario, Esami e Visite (Artt. 15 e 16 GDPR).\n'
          '• Esportare una copia integrale dei tuoi dati in formato JSON strutturato (Portabilità - Art. 20 GDPR).\n'
          '• Cancellare l\'intera cronologia delle conversazioni chat con un clic.\n'
          '• Eliminare definitivamente l\'account, i dati clinici e tutti i referti nello Storage (Diritto all\'Oblio - Art. 17 GDPR), nonché esercitare i diritti di limitazione e opposizione (Artt. 18 e 21 GDPR).\n'
          'Hai inoltre il diritto di proporre reclamo al Garante per la Protezione dei Dati Personali (www.garanteprivacy.it).',
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
