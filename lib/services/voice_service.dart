import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Servizio per la gestione vocale (Speech-to-Text e Text-to-Speech)
/// per la chat di Vitality Assist.
class VoiceService extends ChangeNotifier {
  VoiceService() {
    _initTts();
  }

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _speakingMessageKey;
  String? _lastError;
  VoidCallback? _onListeningDone;

  // Velocità di lettura normale e fluida
  static const double _normalSpeechRate = 0.55;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String? get speakingMessageKey => _speakingMessageKey;
  String? get lastError => _lastError;

  // ------------------------------------------------------------- STT (Microfono)

  Future<bool> initSpeech() async {
    if (_isSpeechInitialized) return true;

    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              _isListening = false;
              final cb = _onListeningDone;
              _onListeningDone = null;
              cb?.call();
              notifyListeners();
            }
          }
        },
        onError: (errorNotification) {
          _lastError = _mapSpeechError(errorNotification.errorMsg);
          _isListening = false;
          final cb = _onListeningDone;
          _onListeningDone = null;
          cb?.call();
          notifyListeners();
        },
      );
    } catch (e) {
      _lastError = _mapSpeechException(e);
      _isSpeechInitialized = false;
    }

    notifyListeners();
    return _isSpeechInitialized;
  }

  Future<bool> startListening({
    required void Function(String words) onResult,
    VoidCallback? onDone,
    String localeId = 'it_IT',
  }) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }

    final available = await initSpeech();
    if (!available) {
      _lastError = 'Riconoscimento vocale non disponibile o permessi negati';
      notifyListeners();
      return false;
    }

    _lastError = null;
    _isListening = true;
    _onListeningDone = onDone;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          localeId: localeId,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 60),
        ),
      );
      return true;
    } catch (e) {
      _lastError = _mapSpeechException(e);
      _isListening = false;
      final cb = _onListeningDone;
      _onListeningDone = null;
      cb?.call();
      notifyListeners();
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    _isListening = false;
    final cb = _onListeningDone;
    _onListeningDone = null;
    cb?.call();
    notifyListeners();
  }

  // ------------------------------------------------------------- TTS (Lettura)

  Future<void> _initTts() async {
    try {
      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingMessageKey = null;
        notifyListeners();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _speakingMessageKey = null;
        notifyListeners();
      });

      _tts.setErrorHandler((dynamic msg) {
        _isSpeaking = false;
        _speakingMessageKey = null;
        _lastError = _mapTtsError(msg);
        notifyListeners();
      });

      await _tts.setLanguage('it-IT');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(_normalSpeechRate);

      // Cerca e seleziona automaticamente la voce italiana femminile predefinita
      final voices = await _tts.getVoices;
      if (voices is List) {
        for (final v in voices) {
          if (v is Map) {
            final map = Map<String, dynamic>.from(v);
            final locale = (map['locale'] ?? '').toString().toLowerCase();
            final name = (map['name'] ?? '').toString().toLowerCase();
            final gender = (map['gender'] ?? '').toString().toLowerCase();

            if (locale.startsWith('it')) {
              final isFemale = gender.contains('female') ||
                  gender.contains('femmina') ||
                  name.contains('female') ||
                  name.contains('femmina') ||
                  name.contains('elsa') ||
                  name.contains('alice') ||
                  name.contains('federica') ||
                  name.contains('bianca') ||
                  name.contains('it-it-x-kda') ||
                  name.contains('it-it-x-itb');

              if (isFemale && map['name'] != null) {
                await _tts.setVoice({
                  'name': map['name'].toString(),
                  'locale': (map['locale'] ?? 'it-IT').toString(),
                });
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('VoiceService initTts warning: $e');
    }
  }

  /// Pulisce il testo da formattazioni Markdown e caratteri grafici prima della lettura vocale (TTS).
  /// Rimuove qualsiasi asterisco (*) o marcatore di elenco/grassetto che verrebbe altrimenti
  /// pronunciato letteralmente dal motore vocale ("asterisco", "cancelletto", "trattino", etc.).
  String sanitizeForTts(String raw) {
    if (raw.trim().isEmpty) return '';

    final lines = raw.split(RegExp(r'[\r\n]+'));
    final buffer = <String>[];

    for (final line in lines) {
      var l = line.trim();
      if (l.isEmpty) continue;

      // Salta righe di separazione tabelle markdown (es. |---|---|)
      if (RegExp(r'^\|?(\s*:?-+:?\s*\|?)+$').hasMatch(l)) continue;

      // Salta delimitatori blocco codice (``` o ```json)
      if (l.startsWith('```')) continue;

      // Rimuovi intestazioni markdown (# Titolo, ## Sotto-titolo)
      l = l.replaceAll(RegExp(r'^\s*#+\s*'), '');

      // Rimuovi marcatori di elenchi puntati a inizio riga (*, -, +, •, ▪, etc.)
      l = l.replaceAll(RegExp(r'^\s*[\*\-•▪▫–—\+]\s+'), '');

      // Rimuovi prefissi di citazione (> Citazione)
      l = l.replaceAll(RegExp(r'^\s*>\s*'), '');

      // Rimuovi pipe a inizio o fine riga (tabelle)
      l = l.replaceAll(RegExp(r'^\||\|$'), '');

      // Sostituisci pipe interne di tabella con virgola per pausa naturale
      l = l.replaceAll('|', ', ');

      // Markdown link: [testo](url) -> testo
      l = l.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m[1] ?? '');

      // Immagini markdown: ![alt](url) -> rimuovi
      l = l.replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]+\)'), '');

      // URL web crudi -> rimuovi per evitare la sillabazione dell'indirizzo
      l = l.replaceAll(RegExp(r'https?://\S+'), '');

      // Grassetto e corsivo con 3 asterischi: ***testo*** -> testo
      l = l.replaceAllMapped(RegExp(r'\*\*\*(.*?)\*\*\*'), (m) => m[1] ?? '');

      // Grassetto: **testo** -> testo
      l = l.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m[1] ?? '');

      // Corsivo: *testo* -> testo
      l = l.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1] ?? '');

      // Underscore grassetto/corsivo: ___testo___, __testo__, _testo_
      l = l.replaceAllMapped(RegExp(r'_{1,3}(.*?)_{1,3}'), (m) => m[1] ?? '');

      // Testo barrato: ~~testo~~ -> testo
      l = l.replaceAllMapped(RegExp(r'~~(.*?)~~'), (m) => m[1] ?? '');

      // Codice inline: `codice` -> codice
      l = l.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '');

      // Tag XML / HTML residui
      l = l.replaceAll(RegExp(r'<[^>]+>'), '');

      // Pressione arteriosa (es. 120/80 -> "120 su 80" per lettura naturale in italiano)
      l = l.replaceAllMapped(RegExp(r'\b(\d{2,3})/(\d{2,3})\b'), (m) => '${m[1]} su ${m[2]}');

      // ELIMINA TOTALMENTE qualsiasi asterisco residuo (garanzia assoluta: nessun "asterisco" letto a voce)
      l = l.replaceAll('*', '');

      // Rimuovi altri caratteri speciali markdown che il TTS leggerebbe letteralmente
      l = l.replaceAll(RegExp(r'[_~#>`\\{}[\]]'), ' ');

      l = l.trim();
      if (l.isEmpty) continue;

      // Assicura punteggiatura naturale a fine riga per far fare una pausa al sintetizzatore vocale
      final lastChar = l[l.length - 1];
      if (!['.', ',', '!', '?', ':', ';'].contains(lastChar)) {
        l = '$l.';
      }

      buffer.add(l);
    }

    var result = buffer.join(' ');
    // Normalizza spazi multipli
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    // Pulisci doppie punteggiature generate dalle concatenazioni
    result = result.replaceAll(RegExp(r'\.{2,}'), '.');
    result = result.replaceAll(RegExp(r',\s*\.'), '.');
    result = result.replaceAll(RegExp(r':\s*\.'), ':');

    return result.trim();
  }

  /// Avvia o interrompe la lettura vocale del messaggio indicato
  Future<void> toggleSpeak(String text, {required String messageKey}) async {
    if (_isSpeaking && _speakingMessageKey == messageKey) {
      await stopSpeaking();
      return;
    }
    await speak(text, messageKey: messageKey);
  }

  Future<void> speak(String text, {String? messageKey}) async {
    if (_isListening) {
      await stopListening();
    }

    if (_isSpeaking) {
      await stopSpeaking();
    }

    final cleanText = sanitizeForTts(text);
    if (cleanText.isEmpty) return;

    _speakingMessageKey = messageKey;
    _isSpeaking = true;
    notifyListeners();

    try {
      await _tts.setSpeechRate(_normalSpeechRate);
      await _tts.speak(cleanText);
    } catch (e) {
      _isSpeaking = false;
      _speakingMessageKey = null;
      _lastError = _mapTtsError(e);
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
    _speakingMessageKey = null;
    notifyListeners();
  }

  static String _mapSpeechError(String? code) {
    switch (code) {
      case 'error_no_match':
        return 'Nessuna voce riconosciuta. Riprova parlando vicino al microfono.';
      case 'error_speech_timeout':
        return 'Tempo di ascolto scaduto. Riprova.';
      case 'error_audio':
        return 'Errore di registrazione audio. Controlla il microfono.';
      case 'error_busy':
        return 'Il microfono è attualmente occupato da un\'altra applicazione.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Connessione di rete non sufficiente per il riconoscimento vocale.';
      case 'error_permission':
      case 'error_insufficient_permissions':
        return 'Permesso per l\'uso del microfono negato.';
      default:
        return 'Riconoscimento vocale non riuscito. Riprova tra qualche istante.';
    }
  }

  static String _mapSpeechException(Object e) {
    final str = e.toString().toLowerCase();
    if (str.contains('permission') || str.contains('denied')) {
      return 'Permesso microfono non concesso. Puoi abilitarlo dalle impostazioni.';
    }
    return 'Riconoscimento vocale non disponibile o permessi negati.';
  }

  static String _mapTtsError(dynamic err) {
    return 'Impossibile riprodurre la sintesi vocale in questo momento.';
  }

  @override
  void dispose() {
    stopListening();
    stopSpeaking();
    super.dispose();
  }
}
