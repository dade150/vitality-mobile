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
              notifyListeners();
            }
          }
        },
        onError: (errorNotification) {
          _lastError = errorNotification.errorMsg;
          _isListening = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _lastError = e.toString();
      _isSpeechInitialized = false;
    }

    notifyListeners();
    return _isSpeechInitialized;
  }

  Future<bool> startListening({
    required void Function(String words) onResult,
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
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        localeId: localeId,
        pauseFor: const Duration(seconds: 5),
        listenFor: const Duration(seconds: 60),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isListening = false;
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
        _lastError = msg?.toString();
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

  /// Pulisce il testo da formattazioni Markdown prima della lettura
  String sanitizeForTts(String raw) {
    return raw
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'_([^_]+)_'), r'$1')
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'[\r\n]+'), '. ')
        .trim();
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
      _lastError = e.toString();
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

  @override
  void dispose() {
    stopListening();
    stopSpeaking();
    super.dispose();
  }
}
