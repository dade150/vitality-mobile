import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Servizio per la gestione vocale (Speech-to-Text e Text-to-Speech)
/// per la chat di Vitality Assist.
class VoiceService extends ChangeNotifier with WidgetsBindingObserver {
  VoiceService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isTtsInitialized = false;
  Future<void>? _ttsInitFuture;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _disposed = false;
  bool _ttsStopPending = false;
  int _listenEpoch = 0;
  int _activeListenEpoch = 0;
  int _speakEpoch = 0;
  Timer? _notListeningGraceTimer;
  final ValueNotifier<double> _soundLevelNotifier = ValueNotifier<double>(0.0);
  String? _speakingMessageKey;
  String? _lastError;
  String? _lastErrorCode;
  VoidCallback? _onListeningDone;
  VoidCallback? _onSpeakCompleted;

  // Limite di sicurezza per il testo trascritto in un singolo turno vocale.
  static const int _maxTranscriptLength = 2000;
  static final _controlCharsRe = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  // Regex precompilate una sola volta per la sanitizzazione TTS.
  static final _lineSplitRe = RegExp(r'[\r\n]+');
  static final _tableSepRe = RegExp(r'^\|?(\s*:?-+:?\s*\|?)+$');
  static final _headingRe = RegExp(r'^\s*#+\s*');
  static final _bulletRe = RegExp(r'^\s*[\*\-•▪▫–—\+]\s+');
  static final _quoteRe = RegExp(r'^\s*>\s*');
  static final _edgePipeRe = RegExp(r'^\||\|$');
  static final _mdLinkRe = RegExp(r'\[([^\]]+)\]\([^\)]+\)');
  static final _mdImgRe = RegExp(r'!\[[^\]]*\]\([^\)]+\)');
  static final _urlRe = RegExp(r'https?://\S+');
  static final _boldItalicRe = RegExp(r'\*\*\*(.*?)\*\*\*');
  static final _boldRe = RegExp(r'\*\*(.*?)\*\*');
  static final _italicRe = RegExp(r'\*([^*]+)\*');
  static final _underscoreRe = RegExp(r'_{1,3}(.*?)_{1,3}');
  static final _strikeRe = RegExp(r'~~(.*?)~~');
  static final _codeInlineRe = RegExp(r'`([^`]+)`');
  static final _xmlTagRe = RegExp(r'<[^>]+>');
  static final _bpRe = RegExp(r'\b(\d{2,3})/(\d{2,3})\b');
  static final _specialMdRe = RegExp(r'[_~#>`\\{}[\]]');
  static final _multiSpaceRe = RegExp(r'\s+');
  static final _multiDotRe = RegExp(r'\.{2,}');
  static final _commaDotRe = RegExp(r',\s*\.');
  static final _colonDotRe = RegExp(r':\s*\.');

  // Velocità di lettura normale e fluida
  static const double _normalSpeechRate = 0.55;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  double get soundLevel => _soundLevelNotifier.value;
  ValueListenable<double> get soundLevelListenable => _soundLevelNotifier;
  String? get speakingMessageKey => _speakingMessageKey;
  String? get lastError => _lastError;
  String? get lastErrorCode => _lastErrorCode;

  /// Verifica se l'ultimo errore è solo un silenzio/timeout naturale (non critico in conversazione continua).
  bool get isBenignSilenceError =>
      _lastErrorCode == 'error_no_match' || _lastErrorCode == 'error_speech_timeout';

  void _notifySafe() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _setSoundLevelSafe(double level) {
    if (!_disposed && (level - _soundLevelNotifier.value).abs() > 0.04) {
      _soundLevelNotifier.value = level;
    }
  }

  void _resetSoundLevelSafe() {
    if (!_disposed && _soundLevelNotifier.value != 0.0) {
      _soundLevelNotifier.value = 0.0;
    }
  }

  static String _sanitizeTranscript(String raw) {
    var clean = raw.replaceAll(_controlCharsRe, '').trim();
    if (clean.length > _maxTranscriptLength) {
      clean = clean.substring(0, _maxTranscriptLength);
    }
    return clean;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hardening Privacy & Security: non lasciare mai il microfono o il TTS attivi
    // quando l'app passa in background, perde il focus o lo schermo viene bloccato.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_isListening) unawaited(cancelListening());
      if (_isSpeaking) unawaited(stopSpeaking());
    }
  }

  // ------------------------------------------------------------- STT (Microfono)

  void _finishListeningSession({required int expectedEpoch}) {
    _notListeningGraceTimer?.cancel();
    _notListeningGraceTimer = null;
    if (!_isListening || _activeListenEpoch != expectedEpoch || expectedEpoch != _listenEpoch) {
      return;
    }
    // Incrementa _listenEpoch alla chiusura della sessione così nessun callback tardivo
    // di Android SpeechRecognizer (es. finalResult dopo notListening) può riattivare onResult.
    _listenEpoch++;
    _isListening = false;
    _resetSoundLevelSafe();
    final cb = _onListeningDone;
    _onListeningDone = null;
    _notifySafe();
    cb?.call();
  }

  Future<bool> initSpeech() async {
    if (_isSpeechInitialized) return true;

    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            _finishListeningSession(expectedEpoch: _activeListenEpoch);
          } else if (status == 'notListening') {
            // Su Android onEndOfSpeech emette 'notListening' ~150ms PRIMA del finalResult:
            // attendiamo brevemente così il finalResult arriva pulito una sola volta,
            // chiudendo comunque la sessione se il dispositivo non emette 'done'.
            if (_isListening && _activeListenEpoch == _listenEpoch) {
              final epoch = _activeListenEpoch;
              _notListeningGraceTimer?.cancel();
              _notListeningGraceTimer = Timer(const Duration(milliseconds: 350), () {
                _finishListeningSession(expectedEpoch: epoch);
              });
            }
          }
        },
        onError: (errorNotification) {
          if (_activeListenEpoch != _listenEpoch || !_isListening) return;
          _notListeningGraceTimer?.cancel();
          _notListeningGraceTimer = null;
          _listenEpoch++;
          _lastErrorCode = errorNotification.errorMsg;
          _lastError = _mapSpeechError(errorNotification.errorMsg);
          _isListening = false;
          _resetSoundLevelSafe();
          final cb = _onListeningDone;
          _onListeningDone = null;
          _notifySafe();
          cb?.call();
        },
      );
    } catch (e) {
      _lastErrorCode = 'exception';
      _lastError = _mapSpeechException(e);
      _isSpeechInitialized = false;
    }

    _notifySafe();
    return _isSpeechInitialized;
  }

  Future<bool> startListening({
    required void Function(String words) onResult,
    VoidCallback? onDone,
    String localeId = 'it_IT',
  }) async {
    _notListeningGraceTimer?.cancel();
    _notListeningGraceTimer = null;
    final myEpoch = ++_listenEpoch;

    if (_isListening) {
      _onListeningDone = null;
      _isListening = false;
      _resetSoundLevelSafe();
      try {
        await _speech.cancel();
      } catch (_) {}
      if (myEpoch != _listenEpoch || _disposed) return false;
    }

    if (_isSpeaking) {
      await stopSpeaking();
      if (myEpoch != _listenEpoch || _disposed) return false;
    }

    final available = await initSpeech();
    if (myEpoch != _listenEpoch || _disposed) return false;

    if (!available) {
      _lastErrorCode = 'unavailable';
      _lastError = 'Riconoscimento vocale non disponibile o permessi negati';
      _notifySafe();
      return false;
    }

    _lastError = null;
    _lastErrorCode = null;
    _resetSoundLevelSafe();
    _activeListenEpoch = myEpoch;
    _isListening = true;
    _onListeningDone = onDone;
    _notifySafe();

    try {
      await _speech.listen(
        onResult: (result) {
          if (myEpoch != _listenEpoch || !_isListening || _disposed) return;
          final sanitized = _sanitizeTranscript(result.recognizedWords);
          // Protegge dal bug Android per cui un callback finale vuoto sovrascrive il testo appena dettato.
          if (sanitized.isNotEmpty) {
            onResult(sanitized);
          }
          if (result.finalResult && _isListening && myEpoch == _listenEpoch) {
            _finishListeningSession(expectedEpoch: myEpoch);
          }
        },
        onSoundLevelChange: (level) {
          if (myEpoch != _listenEpoch || !_isListening || _disposed) return;
          // Normalizza i dB tipici di Android (-2..10 dB) in 0.0..1.0 senza rebuildare la schermata.
          final normalized = ((level + 2.0) / 12.0).clamp(0.0, 1.0);
          _setSoundLevelSafe(normalized);
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          localeId: localeId,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 60),
        ),
      );
      if (myEpoch != _listenEpoch || _disposed) {
        try {
          await _speech.cancel();
        } catch (_) {}
        return false;
      }
      return true;
    } catch (e) {
      if (myEpoch != _listenEpoch || _disposed) return false;
      _lastErrorCode = 'exception';
      _lastError = _mapSpeechException(e);
      _isListening = false;
      _resetSoundLevelSafe();
      final cb = _onListeningDone;
      _onListeningDone = null;
      _notifySafe();
      cb?.call();
      return false;
    }
  }

  Future<void> stopListening() async {
    _notListeningGraceTimer?.cancel();
    _notListeningGraceTimer = null;
    _listenEpoch++;
    if (!_isListening) return;
    _isListening = false;
    _resetSoundLevelSafe();
    final cb = _onListeningDone;
    _onListeningDone = null;
    try {
      await _speech.stop();
    } catch (_) {}
    _notifySafe();
    cb?.call();
  }

  /// Interrompe e annulla immediatamente l'ascolto senza invocare [onDone] (es. tasto Annulla / Background / Logout).
  Future<void> cancelListening() async {
    _notListeningGraceTimer?.cancel();
    _notListeningGraceTimer = null;
    _listenEpoch++;
    _onListeningDone = null;
    final wasListening = _isListening;
    _isListening = false;
    _resetSoundLevelSafe();
    if (wasListening || _speech.isListening) {
      try {
        await _speech.cancel();
      } catch (_) {}
    }
    _notifySafe();
  }

  // ------------------------------------------------------------- TTS (Lettura)

  Future<void> _ensureTtsInitialized() {
    if (_isTtsInitialized) return Future<void>.value();
    return _ttsInitFuture ??= _initTts().whenComplete(() {
      _ttsInitFuture = null;
    });
  }

  Future<void> _initTts() async {
    try {
      _tts.setStartHandler(() {
        _ttsStopPending = false;
        _isSpeaking = true;
        _notifySafe();
      });

      _tts.setCompletionHandler(() {
        if (_ttsStopPending) {
          _ttsStopPending = false;
          return;
        }
        _isSpeaking = false;
        _speakingMessageKey = null;
        final doneCb = _onSpeakCompleted;
        _onSpeakCompleted = null;
        _notifySafe();
        doneCb?.call();
      });

      _tts.setCancelHandler(() {
        // Ignora un callback onCancel ritardato proveniente da un precedente stopSpeaking()
        // quando è già partita una nuova lettura vocale.
        if (_ttsStopPending) {
          _ttsStopPending = false;
          return;
        }
        _isSpeaking = false;
        _speakingMessageKey = null;
        _onSpeakCompleted = null;
        _notifySafe();
      });

      _tts.setErrorHandler((dynamic msg) {
        _ttsStopPending = false;
        _isSpeaking = false;
        _speakingMessageKey = null;
        _onSpeakCompleted = null;
        _lastError = _mapTtsError(msg);
        _notifySafe();
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
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('VoiceService initTts warning: $e');
    }
  }

  /// Pulisce il testo da formattazioni Markdown e caratteri grafici prima della lettura vocale (TTS).
  /// Rimuove qualsiasi asterisco (*) o marcatore di elenco/grassetto che verrebbe altrimenti
  /// pronunciato letteralmente dal motore vocale ("asterisco", "cancelletto", "trattino", etc.).
  String sanitizeForTts(String raw) {
    if (raw.trim().isEmpty) return '';

    final lines = raw.split(_lineSplitRe);
    final buffer = <String>[];

    for (final line in lines) {
      var l = line.trim();
      if (l.isEmpty) continue;

      // Salta righe di separazione tabelle markdown (es. |---|---|)
      if (_tableSepRe.hasMatch(l)) continue;

      // Salta delimitatori blocco codice (``` o ```json)
      if (l.startsWith('```')) continue;

      // Rimuovi intestazioni markdown (# Titolo, ## Sotto-titolo)
      l = l.replaceAll(_headingRe, '');

      // Rimuovi marcatori di elenchi puntati a inizio riga (*, -, +, •, ▪, etc.)
      l = l.replaceAll(_bulletRe, '');

      // Rimuovi prefissi di citazione (> Citazione)
      l = l.replaceAll(_quoteRe, '');

      // Rimuovi pipe a inizio o fine riga (tabelle)
      l = l.replaceAll(_edgePipeRe, '');

      // Sostituisci pipe interne di tabella con virgola per pausa naturale
      l = l.replaceAll('|', ', ');

      // Markdown link: [testo](url) -> testo
      l = l.replaceAllMapped(_mdLinkRe, (m) => m[1] ?? '');

      // Immagini markdown: ![alt](url) -> rimuovi
      l = l.replaceAll(_mdImgRe, '');

      // URL web crudi -> rimuovi per evitare la sillabazione dell'indirizzo
      l = l.replaceAll(_urlRe, '');

      // Grassetto e corsivo con 3 asterischi: ***testo*** -> testo
      l = l.replaceAllMapped(_boldItalicRe, (m) => m[1] ?? '');

      // Grassetto: **testo** -> testo
      l = l.replaceAllMapped(_boldRe, (m) => m[1] ?? '');

      // Corsivo: *testo* -> testo
      l = l.replaceAllMapped(_italicRe, (m) => m[1] ?? '');

      // Underscore grassetto/corsivo: ___testo___, __testo__, _testo_
      l = l.replaceAllMapped(_underscoreRe, (m) => m[1] ?? '');

      // Testo barrato: ~~testo~~ -> testo
      l = l.replaceAllMapped(_strikeRe, (m) => m[1] ?? '');

      // Codice inline: `codice` -> codice
      l = l.replaceAllMapped(_codeInlineRe, (m) => m[1] ?? '');

      // Tag XML / HTML residui
      l = l.replaceAll(_xmlTagRe, '');

      // Pressione arteriosa (es. 120/80 -> "120 su 80" per lettura naturale in italiano)
      l = l.replaceAllMapped(_bpRe, (m) => '${m[1]} su ${m[2]}');

      // ELIMINA TOTALMENTE qualsiasi asterisco residuo (garanzia assoluta: nessun "asterisco" letto a voce)
      l = l.replaceAll('*', '');

      // Rimuovi altri caratteri speciali markdown che il TTS leggerebbe letteralmente
      l = l.replaceAll(_specialMdRe, ' ');

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
    result = result.replaceAll(_multiSpaceRe, ' ');
    // Pulisci doppie punteggiature generate dalle concatenazioni
    result = result.replaceAll(_multiDotRe, '.');
    result = result.replaceAll(_commaDotRe, '.');
    result = result.replaceAll(_colonDotRe, ':');

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

  Future<void> speak(
    String text, {
    String? messageKey,
    VoidCallback? onComplete,
  }) async {
    final myEpoch = ++_speakEpoch;

    if (_isListening) {
      await cancelListening();
      if (myEpoch != _speakEpoch || _disposed) return;
    }

    if (_isSpeaking) {
      _ttsStopPending = true;
      _onSpeakCompleted = null;
      _isSpeaking = false;
      _speakingMessageKey = null;
      if (_isTtsInitialized) {
        try {
          await _tts.stop();
        } catch (_) {}
      }
      if (myEpoch != _speakEpoch || _disposed) return;
    }

    final cleanText = sanitizeForTts(text);
    if (cleanText.isEmpty) {
      onComplete?.call();
      return;
    }

    await _ensureTtsInitialized();
    if (myEpoch != _speakEpoch || _disposed) return;

    _speakingMessageKey = messageKey;
    _onSpeakCompleted = onComplete;
    _isSpeaking = true;
    _notifySafe();

    try {
      await _tts.setSpeechRate(_normalSpeechRate);
      if (myEpoch != _speakEpoch || _disposed) return;
      await _tts.speak(cleanText);
    } catch (e) {
      if (myEpoch != _speakEpoch || _disposed) return;
      _ttsStopPending = false;
      _isSpeaking = false;
      _speakingMessageKey = null;
      _onSpeakCompleted = null;
      _lastError = _mapTtsError(e);
      _notifySafe();
    }
  }

  Future<void> stopSpeaking() async {
    _speakEpoch++;
    _onSpeakCompleted = null;
    final wasSpeaking = _isSpeaking;
    _isSpeaking = false;
    _speakingMessageKey = null;
    if (_isTtsInitialized && wasSpeaking) {
      _ttsStopPending = true;
      try {
        await _tts.stop();
      } catch (_) {}
    } else {
      _ttsStopPending = false;
    }
    _notifySafe();
  }

  /// Azzeramento di sicurezza completo (GDPR Art. 25): interrompe immediatamente
  /// qualsiasi ascolto o sintesi vocale e pulisce tutti i riferimenti/buffer in RAM.
  Future<void> stopAllAndClear() async {
    _listenEpoch++;
    _speakEpoch++;
    _onListeningDone = null;
    _onSpeakCompleted = null;
    _lastError = null;
    _lastErrorCode = null;
    _resetSoundLevelSafe();
    await cancelListening();
    await stopSpeaking();
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
    _disposed = true;
    _notListeningGraceTimer?.cancel();
    _notListeningGraceTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(cancelListening());
    unawaited(stopSpeaking());
    _soundLevelNotifier.dispose();
    super.dispose();
  }
}
