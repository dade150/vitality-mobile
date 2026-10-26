# Contesto di Progetto: Front-End Coaching Conversazionale Diabete Tipo 2 (T2D) - Vitality Assist

## 1. REGOLE DI SICUREZZA E OPERATIVITÀ ASSOLUTE (CRITICO)
- **DIVIETO DI ACCESSO A CREDENZIALI E SEGRETI**: Non aprire, leggere, stampare in terminale o modificare MAI eventuali file `.env`, file di chiavi/credenziali (`*.json`, `*.jks`, `key.properties`) o file contenenti URL/chiavi segrete di Supabase (`lib/services/supabase_client.dart` se contiene chiavi hardcodate).
- **CONFERMA PRIMA DELLE MODIFICHE**: Prima di modificare qualsiasi file esistente o crearne di nuovi, spiega brevemente la modifica all'utente e attendi conferma esplicita.
- **PROTEZIONE DATI SANITARI IN MEMORIA (GDPR)**: I dati trattati rientrano nelle categorie particolari (art. 9 GDPR). Al logout o cambio utente, qualsiasi stato in memoria (cronologia chat, dati clinici caricati nei Provider) deve essere azzerato immediatamente (es. `ChatProvider.clear()`).

## 2. ARCHITETTURA ATTUALE (FRONT-END FLUTTER)
- **Framework & Linguaggio**: Flutter (Dart SDK `>=3.3.0 <4.0.0`), Material 3.
- **State Management**: `provider` (`ChangeNotifier` + `MultiProvider` in `lib/main.dart`), con gestione centralizzata degli errori tramite `ErrorHandler` e mixin `ErrorReporting` (`guard(...)`).
- **Autenticazione & Backend**:
  - Autenticazione e persistenza sessione tramite `supabase_flutter` e `flutter_secure_storage`, governata da `AuthProvider` e `_AuthRedirector` in `lib/main.dart`.
  - Comunicazione con il Back-End Python tramite `ApiService` (`lib/services/api_services.dart`) su richieste REST JSON decodificate in UTF-8 (`utf8.decode(res.bodyBytes)`).
- **Design System ("Vitality Assist")**:
  - Tipografia ad alta leggibilità definita in `AppTheme` (`lib/theme/app_theme.dart`): **Atkinson Hyperlegible** per titoli, intestazioni e pulsanti (`headline`, `title`, `labelLarge`) e **Open Sans** per il corpo del testo (`body`).
  - Supporto a tema Chiaro e Scuro (`ThemeProvider`) e personalizzazione delle sezioni visibili (`SettingsProvider`).

## 3. REQUISITI DI DOMINIO, ACCESSIBILITÀ E UX (TESI MAGISTRALE)
- **Accessibilità Cognitiva e Visiva (Target Pazienti T2D)**:
  - L'interfaccia deve essere utilizzabile anche da utenti anziani, con ridotta familiarità tecnologica o con difficoltà visive/motorie (es. retinopatia diabetica).
  - **Dimensioni e Contrasto**: Rispettare i font generosi del `TextTheme` (corpo base 18-22px, titoli 22-40px), contrasto cromatico elevato, bordi netti (`Card` e `InputDecoration` con bordi visibili) e possibilità di regolare la dimensione del testo nelle impostazioni.
  - **Target Tattili Ampi**: Pulsanti primari e secondari con altezza minima di 56-60px (`minimumSize: Size.fromHeight(60)`), icone chiare accompagnate sempre da etichette testuali comprensibili.
  - **Navigazione e Inserimento Semplificati**: Pochi passaggi per registrare un dato, evitare form macchinosi o sovraccarichi; supportare l'input vocale nella chat come alternativa alla digitazione.
- **Modulo di Chat e Inserimento Dati Conversazionale**:
  - La chat (`/chat`) è il punto di ingresso principale dell'applicativo dopo il login.
  - **Consenso Esplicito per Salvataggio da Chat**: Quando il Back-End riconosce nel messaggio dell'utente dei valori clinici (glicemia, pasto, attività fisica, peso, pressione) e restituisce un payload strutturato, il Front-End NON deve salvarli in modo silenzioso, ma mostrare una chiara scheda/dialog di conferma per raccogliere il consenso esplicito dell'utente prima della registrazione.
- **Diario del Paziente, Parametri Clinici e Referti**:
  - Gestione completa (CRUD) e visualizzazione giornaliera/settimanale chiara per:
    1. **Diario quotidiano**: Glicemia capillare SMBG (con codice colore e alert immediato per valori fuori range ipo/iperglicemici), Pasti, Attività fisica, Terapia farmacologica e Pressione arteriosa.
    2. **Sorveglianza e Referti**: Appuntamenti medici, archiviazione referti e indicatori clinici T2D (HbA1c, eGFR, UACR, Colesterolo totale, HDL, LDL, Trigliceridi).
- **Guardrails UX e Sicurezza Clinica**:
  - Mostrare chiaramente il **disclaimer medico** (l'assistente fornisce supporto educativo e di autogestione basato su linee guida ADA 2026 / SID-AMD 2025 / ADCES7, non formula diagnosi né modifica terapie o dosaggi).
  - Evidenziare visivamente gli alert di sicurezza restituiti dal BE o rilevati sui valori glicemici fuori soglia.
  - Gestire timeout ed errori del modello linguistico in modo rassicurante e comprensibile per il paziente, senza esporre stack trace o dettagli tecnici.
