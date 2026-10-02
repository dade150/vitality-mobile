# Vitality Assist — Flutter App (Android)

App Flutter per il coaching conversazionale dedicato alla gestione del diabete di tipo 2.
Target: Android.

## Setup

```bash
cd vitality_assist
flutter pub get
flutter run
```

## Struttura del progetto

```
lib/
  main.dart                  # MultiProvider + MaterialApp + rotte
  theme/                     # Colori e ThemeData (Material 3, chiaro/scuro)
  models/                    # Classi dati (nessuna logica)
  providers/                 # ChangeNotifier per lo stato (Provider)
  utils/                     # Helper (formattazione date in italiano)
  widgets/                   # Componenti condivisi (bottom nav, card, grafici)
  screens/                   # Una cartella per area funzionale
```

### Provider

| Provider | Ruolo |
|---|---|
| `ThemeProvider` | Tema chiaro/scuro/sistema |
| `SettingsProvider` | Sezioni Diario visibili, notifiche |
| `UserProvider` | Login demo e dati profilo |
| `HealthProvider` | Terapia, glicemia, pressione, attivita, pasti |
| `AppointmentsProvider` | Visite mediche |
| `ReportsProvider` | Referti caricati |
| `ChatProvider` | Messaggi chat con il coach |

### Navigazione

Bottom nav bar con 4 schede: **Chat, Diario, Referti, Visite**.
Le schermate usano `Navigator.pushNamed` con rotte nominate definite in `main.dart`.

## Cosa e demo (da collegare a backend reale)

- **Login**: accetta qualunque credenziale non vuota (`UserProvider.login`)
- **Chat coach**: risposte simulate in locale (`ChatProvider._reply`)
- **Carica Referto**: upload simulato con parametri di esempio
- **Stima calorie**: euristica approssimativa, non calcolo nutrizionale reale
- **Notifiche**: toggle solo su stato locale, servono `flutter_local_notifications` per push reali

## Dipendenze

- `provider` — gestione stato
- `google_fonts` — Atkinson Hyperlegible + Open Sans
- `intl` — formattazione date italiano
