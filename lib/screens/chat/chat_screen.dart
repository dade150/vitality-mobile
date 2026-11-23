import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';
import '../../models/chat_models.dart';
import '../../models/proposed_entry.dart';
import '../../providers/appointments_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/device_file_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/clinical_proposal_card.dart';
import '../../widgets/formatted_chat_message.dart';
import '../../widgets/pdf_export_sheet.dart';
import '../../widgets/report_privacy_mask_dialog.dart';
import '../settings/settings_screen.dart';
import 'chat_drawer.dart';

class _PendingAttachment {
  final String fileName;
  final String kind;
  final String mimeType;
  final Uint8List bytes;

  _PendingAttachment({
    required this.fileName,
    required this.kind,
    required this.mimeType,
    required this.bytes,
  });

  bool get isPdf => mimeType == 'application/pdf';
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _greetings = [
    'Come posso aiutarti oggi?',
    'Come va oggi?',
    'Hai fatto un po\' di movimento oggi?',
    'Cosa hai mangiato oggi?',
    'Come ti senti oggi?',
    'Hai bevuto abbastanza acqua oggi?',
    'Un piccolo passo alla volta: come posso aiutarti?',
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  VoiceService? _voiceService;
  String _liveSpokenText = '';
  String? _voicePauseReason;
  bool _isVoiceConversationMode = false;
  bool _isStartingVoiceTurn = false;
  bool _isCommittingVoice = false;
  Timer? _silenceAutoSendTimer;
  Timer? _autoRelistenTimer;

  // Lazy: con l'hot reload initState non viene ri-eseguito sugli stati già
  // vivi, un late assegnato lì andrebbe in LateInitializationError.
  late final String _greeting = _greetings[math.Random().nextInt(_greetings.length)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voiceService = context.read<VoiceService>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hardening Privacy & Security: al passaggio in background/inattività annulla
    // subito tutti i timer vocali e azzera i buffer in RAM per impedire riaperture del microfono.
    if (state != AppLifecycleState.resumed) {
      _silenceAutoSendTimer?.cancel();
      _autoRelistenTimer?.cancel();
      if (_isVoiceConversationMode || _liveSpokenText.isNotEmpty) {
        unawaited(_voiceService?.stopAllAndClear());
        if (mounted) {
          setState(() {
            _isVoiceConversationMode = false;
            _liveSpokenText = '';
            _voicePauseReason = null;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _silenceAutoSendTimer?.cancel();
    _autoRelistenTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    unawaited(_voiceService?.stopAllAndClear());
    super.dispose();
  }

  void _scrollToEnd({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (immediate) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  _PendingAttachment? _pendingAttachment;

  Future<void> _pickImage(ImageSource source, {required String kind, bool isReport = false}) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final name = pickedFile.name;

      Uint8List finalBytes;
      if (isReport) {
        if (!mounted) return;
        final sanitized = await ReportPrivacyMaskDialog.show(
          context,
          imageBytes: bytes,
          fileName: name,
        );
        if (sanitized == null || !mounted) return;
        finalBytes = sanitized;
      } else {
        // Garantisce formato supportato (JPEG/PNG/WebP, convertendo es. HEIC) e dimensione <= 3.5 MB
        finalBytes = await normalizeImageForUpload(bytes);
        if (!mounted) return;
      }

      // Rileva sempre il MIME reale dai magic bytes per evitare mismatch HTTP 400 sul backend
      final mimeType = detectImageMimeType(finalBytes, fallback: '');
      if (mimeType.isEmpty) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Formato immagine non supportato. Usa una foto in formato JPG, PNG o WebP.',
        );
        return;
      }
      if (finalBytes.length > kMaxUploadAttachmentBytes) {
        AppFeedback.showErrorDialog(
          context,
          message: 'L\'immagine supera il limite massimo di 5 MB. Prova con una foto più leggera.',
        );
        return;
      }
      final finalName = normalizeMaskedFileName(name, finalBytes);

      // Se l'utente ha appena fotografato un referto clinico dalla fotocamera,
      // ne salva automaticamente una copia nella Galleria del dispositivo (Pictures/diaLog2).
      if (isReport && source == ImageSource.camera && DeviceFileService.isAndroid) {
        try {
          final now = DateTime.now();
          String p2(int n) => n.toString().padLeft(2, '0');
          final ext = DeviceFileService.extensionForMime(mimeType);
          final galleryName =
              'Referto_${now.year}${p2(now.month)}${p2(now.day)}_${p2(now.hour)}${p2(now.minute)}${p2(now.second)}.$ext';
          final dest = await DeviceFileService.saveReportToDevice(
            bytes: finalBytes,
            fileName: galleryName,
            mimeType: mimeType,
          );
          if (dest != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Foto referto salvata in Galleria ($dest).')),
            );
          }
        } catch (_) {
          // Best-effort: non blocca mai l'allegato in chat
        }
      }

      setState(() {
        _pendingAttachment = _PendingAttachment(
          fileName: finalName,
          kind: kind,
          mimeType: mimeType,
          bytes: finalBytes,
        );
      });
    } catch (_) {
      if (mounted) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Impossibile selezionare l\'immagine. Riprova.',
        );
      }
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
      if (bytes == null) {
        if (mounted) {
          AppFeedback.showErrorDialog(
            context,
            message: 'Impossibile leggere il file selezionato.',
          );
        }
        return;
      }
      if (!isPdfBytes(bytes)) {
        if (mounted) {
          AppFeedback.showErrorDialog(
            context,
            message: 'Il file selezionato non sembra un documento PDF valido.',
          );
        }
        return;
      }
      if (bytes.length > kMaxUploadAttachmentBytes) {
        if (mounted) {
          AppFeedback.showErrorDialog(
            context,
            message: 'Il PDF supera il limite massimo di 5 MB. Scegli un documento più leggero.',
          );
        }
        return;
      }

      setState(() {
        _pendingAttachment = _PendingAttachment(
          fileName: file.name,
          kind: 'medical_report',
          mimeType: 'application/pdf',
          bytes: bytes!,
        );
      });
    } catch (_) {
      if (mounted) {
        AppFeedback.showErrorDialog(
          context,
          message: 'Impossibile selezionare il PDF. Riprova.',
        );
      }
    }
  }

  void _showAttachmentModal() {
    final hasAiConsent = context.read<ProfileProvider>().aiHealthConsent;
    if (!hasAiConsent) {
      AppFeedback.showErrorDialog(
        context,
        title: 'Consenso richiesto',
        message: 'Il consenso al trattamento dati sanitari con IA è disattivato. Riattivalo dalle Impostazioni per allegare documenti.',
      );
      return;
    }
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.restaurant_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Foto Pasto o Glucometro', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Riconoscimento alimenti CREA o valore glicemia', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _pickImage(ImageSource.camera, kind: 'meal_photo', isReport: false);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.document_scanner_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Foto Referto Clinico', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Con Privacy Mask per oscurare Nome e CF', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _pickImage(ImageSource.camera, kind: 'medical_report', isReport: true);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.photo_library_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Scegli da Galleria', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Seleziona un\'immagine salvata sul dispositivo', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _showGalleryChoiceDialog();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.picture_as_pdf_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Documento PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Referto nativo con de-identificazione in RAM', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _pickPdf();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGalleryChoiceDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Cosa contiene l\'immagine selezionata?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.restaurant_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Foto Pasto o Glucometro', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Nessun dato anagrafico da oscurare', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery, kind: 'meal_photo', isReport: false);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightPeach,
                    child: Icon(Icons.document_scanner_rounded, color: AppColors.accent),
                  ),
                  title: const Text('Referto Medico Cartaceo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Apre l\'anteprima con Privacy Mask per annerire l\'intestazione', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery, kind: 'medical_report', isReport: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _send({
    String? overrideText,
    bool fromVoiceConversation = false,
  }) async {
    _silenceAutoSendTimer?.cancel();
    _autoRelistenTimer?.cancel();

    final hasAiConsent = context.read<ProfileProvider>().aiHealthConsent;
    if (!hasAiConsent) {
      await _exitVoiceConversationMode();
      if (!mounted) return;
      AppFeedback.showErrorDialog(
        context,
        title: 'Consenso richiesto',
        message: 'Il consenso al trattamento dati sanitari con IA è disattivato. Riattivalo dalle Impostazioni per chattare.',
      );
      return;
    }
    final chat = context.read<ChatProvider>();
    final voice = context.read<VoiceService>();
    final text = (overrideText ?? _controller.text).trim();
    final att = _pendingAttachment;
    if ((text.isEmpty && att == null) || chat.isSending) return;

    if (voice.isListening) {
      await voice.cancelListening();
    }
    if (voice.isSpeaking) {
      await voice.stopSpeaking();
    }

    ChatAttachmentIn? attachmentIn;
    String? attachmentFileName;

    if (att != null) {
      attachmentIn = ChatAttachmentIn(
        kind: att.kind,
        mimeType: att.mimeType,
        dataBase64: base64Encode(att.bytes),
      );
      attachmentFileName = att.fileName;
    }

    if (overrideText == null) {
      _controller.clear();
    }
    setState(() {
      _pendingAttachment = null;
      _liveSpokenText = '';
      _voicePauseReason = null;
      if (fromVoiceConversation) {
        _isVoiceConversationMode = true;
      }
    });

    final pending = chat.sendMessage(
      text,
      attachment: attachmentIn,
      attachmentFileName: attachmentFileName,
    );
    _scrollToEnd();
    final ok = await pending;
    if (!mounted) return;
    _scrollToEnd();
    if (!ok) {
      if (_isVoiceConversationMode) {
        setState(() {
          _isVoiceConversationMode = false;
          _voicePauseReason = null;
        });
      }
      if (chat.errorMessage != null) {
        AppFeedback.showErrorDialog(context, message: chat.errorMessage!);
      }
    } else {
      if (attachmentIn != null) {
        unawaited(context.read<ReportsProvider>().refresh());
      }
      final settings = context.read<SettingsProvider>();
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      final isAppActive = WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      // Nota: controlla _isVoiceConversationMode (non fromVoiceConversation) così se
      // l'utente ha premuto "Esci" durante lo streaming rispettiamo subito il silenzio.
      final shouldSpeakReply =
          (_isVoiceConversationMode || settings.autoTts) &&
          isCurrentRoute &&
          isAppActive &&
          chat.messages.isNotEmpty;
      if (shouldSpeakReply) {
        final lastMsg = chat.messages.last;
        if (!lastMsg.isUser && lastMsg.text.isNotEmpty) {
          final msgKey = lastMsg.id;
          unawaited(
            voice.speak(
              lastMsg.text,
              messageKey: msgKey,
              onComplete: () => _onAssistantFinishedSpeaking(lastMsg),
            ),
          );
        }
      }
    }
  }

  /// Chiamato al termine naturale della lettura TTS dell'assistente.
  /// Se siamo in modalità Conversazione Vocale Live e non ci sono schede cliniche HITL
  /// in attesa di conferma o emergenze, riapre il microfono automaticamente per
  /// proseguire il dialogo a mani libere.
  void _onAssistantFinishedSpeaking(ChatMessage assistantMsg) {
    if (!mounted || !_isVoiceConversationMode) return;

    // Security & Privacy check: riattiva il microfono solo se la schermata è attiva in primo piano,
    // l'app è in foreground e il consenso sanitario IA è ancora valido.
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    final isAppActive = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final hasConsent = context.read<ProfileProvider>().aiHealthConsent;
    if (!isCurrentRoute || !isAppActive || !hasConsent) {
      unawaited(_exitVoiceConversationMode());
      return;
    }

    // Se l'utente ha aperto la tastiera (es. sta modificando un campo dentro una scheda clinica),
    // non riapriamo il microfono per non togliergli il focus.
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hasPendingProposals = assistantMsg.proposedEntries.any(
      (p) => p.status == ProposalStatus.pending || p.status == ProposalStatus.saving,
    );
    final hasSuggestedAction = assistantMsg.suggestedAction != null;

    // Se è spuntato un dato clinico ancora da confermare (ClinicalProposalCard), una card azione (es. PDF)
    // o un banner di emergenza, mettiamo in pausa il riascolto automatico così il paziente può agire con calma.
    if (hasPendingProposals || hasSuggestedAction || assistantMsg.isEmergency || isKeyboardOpen) {
      _scrollToEnd();
      setState(() {
        _voicePauseReason = hasPendingProposals ? 'proposal' : null;
      });
      return;
    }

    _autoRelistenTimer?.cancel();
    _autoRelistenTimer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted || !_isVoiceConversationMode) return;
      final stillCurrent = ModalRoute.of(context)?.isCurrent ?? false;
      final stillActive = WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!stillCurrent || !stillActive) {
        unawaited(_exitVoiceConversationMode());
        return;
      }
      final chat = context.read<ChatProvider>();
      final voice = context.read<VoiceService>();
      if (!chat.isSending && !voice.isSpeaking && !voice.isListening) {
        unawaited(_startVoiceListeningTurn(isManualTrigger: false));
      }
    });
  }

  /// Conferma e invia automaticamente in chat quanto appena pronunciato dall'utente.
  Future<void> _commitLiveVoiceMessage() async {
    if (_isCommittingVoice) return;
    _silenceAutoSendTimer?.cancel();
    _autoRelistenTimer?.cancel();

    final spoken = _liveSpokenText.trim();
    // Guardrail sicurezza: ignora rumori ambientali o singole lettere accidentali (< 2 caratteri).
    if (spoken.length < 2) {
      if (mounted) {
        setState(() {
          _liveSpokenText = '';
        });
      }
      return;
    }

    _isCommittingVoice = true;
    try {
      final voice = context.read<VoiceService>();
      if (voice.isListening) {
        await voice.cancelListening();
      }
      if (!mounted) return;
      await _send(overrideText: spoken, fromVoiceConversation: true);
    } finally {
      _isCommittingVoice = false;
    }
  }

  /// Interrompe immediatamente la voce dell'assistente (Barge-In) e apre subito il microfono.
  Future<void> _interruptAndSpeak() async {
    _silenceAutoSendTimer?.cancel();
    _autoRelistenTimer?.cancel();
    final voice = context.read<VoiceService>();
    if (voice.isSpeaking) {
      await voice.stopSpeaking();
    }
    if (!mounted) return;
    await _startVoiceListeningTurn(isManualTrigger: true);
  }

  /// Esce completamente dalla modalità Conversazione Vocale Live e azzera i buffer vocali in RAM.
  Future<void> _exitVoiceConversationMode() async {
    _silenceAutoSendTimer?.cancel();
    _autoRelistenTimer?.cancel();
    final voice = _voiceService ?? context.read<VoiceService>();
    await voice.stopAllAndClear();
    if (!mounted) return;
    setState(() {
      _isVoiceConversationMode = false;
      _liveSpokenText = '';
      _voicePauseReason = null;
    });
  }

  Future<void> _toggleListening() async {
    final voice = context.read<VoiceService>();
    if (voice.isSpeaking) {
      await _interruptAndSpeak();
      return;
    }
    if (voice.isListening) {
      if (_liveSpokenText.trim().length >= 2) {
        await _commitLiveVoiceMessage();
      } else {
        await _exitVoiceConversationMode();
      }
      return;
    }
    await _startVoiceListeningTurn(isManualTrigger: true);
  }

  Future<void> _startVoiceListeningTurn({required bool isManualTrigger}) async {
    if (_isStartingVoiceTurn || _isCommittingVoice) return;
    final chat = context.read<ChatProvider>();
    if (chat.isSending) return;

    _silenceAutoSendTimer?.cancel();
    _autoRelistenTimer?.cancel();

    // Chiudi subito la tastiera virtuale se aperta
    FocusScope.of(context).unfocus();
    _focusNode.unfocus();

    final hasAiConsent = context.read<ProfileProvider>().aiHealthConsent;
    if (!hasAiConsent) {
      if (isManualTrigger && mounted) {
        AppFeedback.showErrorDialog(
          context,
          title: 'Consenso richiesto',
          message: 'Il consenso al trattamento dati sanitari con IA è disattivato. Riattivalo dalle Impostazioni per usare il microfono.',
        );
      }
      return;
    }

    _isStartingVoiceTurn = true;
    final voice = context.read<VoiceService>();
    setState(() {
      _isVoiceConversationMode = true;
      _liveSpokenText = '';
      _voicePauseReason = null;
    });
    _scrollToEnd();

    try {
      final started = await voice.startListening(
        onResult: (words) {
          if (!mounted || words.isEmpty) return;
          final changed = words != _liveSpokenText;
          if (changed) {
            setState(() {
              _liveSpokenText = words;
            });
            _scrollToEnd(immediate: true);
          }

          // Auto-invio dopo una pausa naturale di 2.4 secondi dall'ultima parola pronunciata
          _silenceAutoSendTimer?.cancel();
          if (words.trim().length >= 2) {
            _silenceAutoSendTimer = Timer(const Duration(milliseconds: 2400), () {
              if (mounted && !_isCommittingVoice && _liveSpokenText.trim().length >= 2) {
                unawaited(_commitLiveVoiceMessage());
              }
            });
          }
        },
        onDone: () {
          if (!mounted || _isCommittingVoice) return;
          _silenceAutoSendTimer?.cancel();
          if (_liveSpokenText.trim().length >= 2) {
            unawaited(_commitLiveVoiceMessage());
            return;
          }

          // Errore reale del microfono/rete arrivato in modo asincrono: avvisa sempre l'utente.
          final hasRealError = voice.lastError != null && !voice.isBenignSilenceError;
          if (hasRealError) {
            setState(() {
              _liveSpokenText = '';
              _isVoiceConversationMode = false;
              _voicePauseReason = null;
            });
            if (isManualTrigger) {
              AppFeedback.showErrorDialog(context, message: voice.lastError!);
            }
            return;
          }

          // Nessuna parola pronunciata (silenzio o timeout):
          // - Se era un riascolto automatico, chiudiamo dolcemente il loop vocale.
          // - Se aveva premuto il microfono manualmente, restiamo pronti con un feedback chiaro.
          setState(() {
            _liveSpokenText = '';
            if (!isManualTrigger) {
              _isVoiceConversationMode = false;
              _voicePauseReason = null;
            } else {
              _voicePauseReason = 'silence';
            }
          });
        },
      );

      if (!started && mounted) {
        setState(() {
          _isVoiceConversationMode = false;
          _liveSpokenText = '';
          _voicePauseReason = null;
        });
        if (isManualTrigger && voice.lastError != null) {
          AppFeedback.showErrorDialog(context, message: voice.lastError!);
        }
      }
    } finally {
      _isStartingVoiceTurn = false;
    }
  }

  void _refreshDomainProvider(TargetTable table) {
    switch (table) {
      case TargetTable.diabetesData:
        unawaited(context.read<HealthProvider>().refresh());
        unawaited(context.read<ClinicalProvider>().refresh());
        break;
      case TargetTable.meals:
      case TargetTable.physicalActivities:
      case TargetTable.therapyLogs:
      case TargetTable.therapies:
        unawaited(context.read<HealthProvider>().refresh());
        break;
      case TargetTable.appointments:
        unawaited(context.read<AppointmentsProvider>().refresh());
        break;
      case TargetTable.profile:
        unawaited(context.read<ProfileProvider>().refresh());
        break;
    }
  }

  Widget _buildAttachmentPreview(ThemeData theme, ColorScheme cs) {
    if (_pendingAttachment == null) return const SizedBox.shrink();

    final att = _pendingAttachment!;
    final isPdf = att.isPdf;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isPdf
                ? Container(
                    width: 44,
                    height: 44,
                    color: Colors.red.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.redAccent,
                      size: 26,
                    ),
                  )
                : Image.memory(
                    att.bytes,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  att.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(att.bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Rimuovi allegato',
            onPressed: () => setState(() => _pendingAttachment = null),
          ),
        ],
      ),
    );
  }

  static const double _voiceBarHeight = 72.0;

  /// Bolla utente "live" mostrata direttamente dentro la chat appena l'utente inizia a parlare.
  /// Scrive le parole in tempo reale con font grande ad alta leggibilità e si invia
  /// automaticamente dopo una breve pausa, senza doppi messaggi di stato o conferme extra.
  Widget _buildLiveListeningUserBubble(
    ThemeData theme,
    ColorScheme cs,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = screenWidth > 640 ? 540.0 : (screenWidth * 0.85);
    final fg = cs.onPrimary;

    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: 'Messaggio dettato: $_liveSpokenText. Tocca per inviare subito.',
        child: GestureDetector(
          onTap: _commitLiveVoiceMessage,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            constraints: BoxConstraints(
              maxWidth: bubbleMaxWidth,
              minWidth: math.min(120.0, bubbleMaxWidth),
            ),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(
                color: fg.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              '$_liveSpokenText ▍',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceSideActionButton({
    required ThemeData theme,
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required String semanticsLabel,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: SizedBox(
        width: 92,
        height: _voiceBarHeight,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(92, _voiceBarHeight),
            maximumSize: const Size(92, _voiceBarHeight),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: cs.onSurface,
            backgroundColor: cs.surfaceContainerHighest,
            side: BorderSide(color: cs.outline, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra inferiore minimalista ad alta visibilità per utenti anziani e ipovedenti:
  /// entrambi i pulsanti condividono la stessa altezza esatta ([_voiceBarHeight])
  /// per un allineamento perfetto senza dislivelli.
  Widget _buildVoiceConversationBar(
    ThemeData theme,
    ColorScheme cs,
    ChatProvider chat,
    VoiceService voice,
  ) {
    final hasWords = _liveSpokenText.trim().length >= 2;

    // 1. L'assistente sta parlando -> Grande pulsante "Interrompi e parla" (Barge-In)
    if (voice.isSpeaking) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: _voiceBarHeight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, _voiceBarHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.accentText,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _interruptAndSpeak,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_rounded, size: 26, color: Colors.white),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Interrompi e parla',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildVoiceSideActionButton(
            theme: theme,
            cs: cs,
            icon: Icons.stop_rounded,
            label: 'Stop',
            semanticsLabel: 'Ferma lettura vocale e torna alla tastiera',
            onPressed: _exitVoiceConversationMode,
          ),
        ],
      );
    }

    // 2. Microfono in ascolto -> Onda sonora minimalista che riempie tutto il pulsante
    if (voice.isListening) {
      final bg = hasWords ? cs.primary : AppColors.accentText;
      final fg = hasWords ? cs.onPrimary : Colors.white;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              button: hasWords,
              label: hasWords
                  ? 'Microfono in ascolto. Tocca per inviare subito.'
                  : 'Microfono in ascolto, parla pure.',
              child: SizedBox(
                height: _voiceBarHeight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, _voiceBarHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: bg,
                    foregroundColor: fg,
                    disabledBackgroundColor: AppColors.accentText,
                    disabledForegroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: hasWords ? _commitLiveVoiceMessage : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _FullWidthSoundWave(
                          color: fg,
                          soundLevelListenable: voice.soundLevelListenable,
                        ),
                      ),
                      if (hasWords) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.send_rounded, size: 24, color: fg),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildVoiceSideActionButton(
            theme: theme,
            cs: cs,
            icon: Icons.close_rounded,
            label: 'Esci',
            semanticsLabel: 'Annulla ascolto vocale',
            onPressed: _exitVoiceConversationMode,
          ),
        ],
      );
    }

    // 3. L'assistente sta elaborando la risposta in modalità vocale
    if (chat.isSending) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: _voiceBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Sto rispondendo...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildVoiceSideActionButton(
            theme: theme,
            cs: cs,
            icon: Icons.close_rounded,
            label: 'Esci',
            semanticsLabel: 'Esci dalla modalità vocale',
            onPressed: _exitVoiceConversationMode,
          ),
        ],
      );
    }

    // 4. In pausa (es. scheda clinica da confermare o silenzio al tocco manuale)
    final pauseLabel = switch (_voicePauseReason) {
      'silence' => 'Riprova a parlare',
      'proposal' => 'Continua a parlare',
      _ => 'Tocca per parlare',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: _voiceBarHeight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, _voiceBarHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => _startVoiceListeningTurn(isManualTrigger: true),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_rounded, size: 26, color: cs.onPrimary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      pauseLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildVoiceSideActionButton(
          theme: theme,
          cs: cs,
          icon: Icons.keyboard_rounded,
          label: 'Tastiera',
          semanticsLabel: 'Torna alla tastiera',
          onPressed: _exitVoiceConversationMode,
        ),
      ],
    );
  }

  Widget _buildAttachmentBadge(
    ThemeData theme,
    bool isUser,
    String kind,
    String? fileName,
  ) {
    final cs = theme.colorScheme;
    final isPdf = kind == 'medical_report' || kind == 'pdf_document';

    final String label = fileName ?? (isPdf ? 'Referto Medico PDF' : 'Immagine allegata');
    final IconData icon = isPdf ? Icons.picture_as_pdf_rounded : Icons.photo_camera_rounded;
    final iconColor = isUser ? Colors.white : (isPdf ? const Color(0xFFC0392B) : cs.primary);
    final iconBg = isUser
        ? Colors.white.withValues(alpha: 0.22)
        : (isPdf ? const Color(0xFFFDEDEC) : cs.primaryContainer);

    final cardBg = isUser ? Colors.white.withValues(alpha: 0.15) : cs.surfaceContainerLowest;
    final textColor = isUser ? cs.onPrimary : cs.onSurface;
    final subColor = isUser ? cs.onPrimary.withValues(alpha: 0.8) : cs.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUser ? Colors.white.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isPdf ? 'Documento protetto GDPR' : 'Foto inviata',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subColor,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Possibile Emergenza Medica',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 22),
              label: const Text(
                'Chiama subito il 112',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await _exitVoiceConversationMode();
                final uri = Uri.parse('tel:112');
                try {
                  await launchUrl(uri);
                } catch (_) {}
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedActionCard(ThemeData theme, ChatSuggestedAction action) {
    if (action.type != 'export_pdf_summary') return const SizedBox.shrink();

    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? cs.primary : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? cs.primaryContainer : AppColors.lightPeach,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Medico PDF (${action.months} mesi)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Riepilogo clinico stampabile per il medico',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text(
                'Genera e salva PDF',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                await _exitVoiceConversationMode();
                if (!mounted) return;
                await showPdfExportSheet(context, initialMonths: action.months);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestionChips(ThemeData theme) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final chipTextColor = isDark ? cs.primary : AppColors.accentText;
    final suggestions = [
      'Come posso gestire la glicemia oggi?',
      'Cosa posso mangiare a cena?',
      'Consigli per fare movimento',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: suggestions.map((sugg) {
          return ActionChip(
            avatar: Icon(Icons.lightbulb_outline_rounded, size: 18, color: chipTextColor),
            label: Text(
              sugg,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: chipTextColor,
              ),
            ),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            side: BorderSide(color: chipTextColor.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onPressed: () {
              final chat = context.read<ChatProvider>();
              if (!chat.isSending) {
                _controller.text = sugg;
                _send();
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _bubble({
    required ThemeData theme,
    required bool isUser,
    required Widget child,
  }) {
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = screenWidth > 640 ? 540.0 : (screenWidth * (isUser ? 0.80 : 0.86));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chat = context.watch<ChatProvider>();
    final voice = context.watch<VoiceService>();
    final profile = context.watch<ProfileProvider>();
    final showLiveVoiceBubble = _liveSpokenText.trim().isNotEmpty;
    final showVoiceBar =
        _isVoiceConversationMode || voice.isListening || voice.isSpeaking;

    return _AnimatedChatBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        onDrawerChanged: (isOpened) {
          if (isOpened) {
            unawaited(_exitVoiceConversationMode());
          }
        },
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 125,
          leading: Builder(
            builder: (scaffoldContext) {
              final isDark = theme.brightness == Brightness.dark;
              final menuColor = isDark ? cs.primary : AppColors.accentText;
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  splashColor: menuColor.withValues(alpha: 0.2),
                  highlightColor: menuColor.withValues(alpha: 0.1),
                  onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Offset ottico (+1.5dp) per compensare la codina inferiore del fumetto
                        // e allineare il corpo della nuvoletta all'altezza delle lettere di 'Menu'.
                        Transform.translate(
                          offset: const Offset(0, 1.5),
                          child: Image.asset(
                            'assets/logo/dialog_symbol.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Menu',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: menuColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            if (chat.hasMessages)
              IconButton(
                icon: Icon(
                  Icons.add_comment_outlined,
                  color: theme.brightness == Brightness.dark ? cs.primary : AppColors.accentText,
                ),
                tooltip: 'Nuova chat',
                onPressed: () {
                  unawaited(_exitVoiceConversationMode());
                  chat.newChat();
                },
              ),
          ],
        ),
        drawer: ChatDrawer(
          onNewChat: () {
            unawaited(_exitVoiceConversationMode());
            chat.newChat();
          },
          onPastChats: () {
            unawaited(_exitVoiceConversationMode());
            Navigator.of(context).pushNamed('/chat/history');
          },
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: chat.hasMessages
                        ? ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            itemCount: chat.messages.length + (showLiveVoiceBubble ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (showLiveVoiceBubble && index == chat.messages.length) {
                                return RepaintBoundary(
                                  child: _buildLiveListeningUserBubble(theme, cs),
                                );
                              }
                              final message = chat.messages[index];
                              if (message.isUser) {
                                return RepaintBoundary(
                                  child: _bubble(
                                    theme: theme,
                                    isUser: true,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (message.attachmentKind != null)
                                          _buildAttachmentBadge(
                                            theme,
                                            true,
                                            message.attachmentKind!,
                                            message.attachmentFileName,
                                          ),
                                        if (message.text.isNotEmpty)
                                          FormattedChatMessage(
                                            text: message.text,
                                            isUser: true,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: cs.onPrimary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final msgKey = message.id;
                              final isCurrentSpeaking =
                                  voice.isSpeaking && voice.speakingMessageKey == msgKey;

                              final isDark = theme.brightness == Brightness.dark;

                              return RepaintBoundary(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 8, right: 8),
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isDark ? cs.surfaceContainerHigh : AppColors.lightPeach,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: (isDark ? cs.primary : AppColors.accent).withValues(alpha: 0.3),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 17,
                                        color: isDark ? cs.primary : AppColors.accentText,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _bubble(
                                            theme: theme,
                                            isUser: false,
                                            child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (message.attachmentKind != null)
                                          _buildAttachmentBadge(
                                            theme,
                                            false,
                                            message.attachmentKind!,
                                            message.attachmentFileName,
                                          ),
                                        if (message.isStreaming && message.text.isEmpty)
                                          const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        else if (message.text.isNotEmpty)
                                          FormattedChatMessage(
                                            text: message.text,
                                            isUser: false,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: cs.onSurface,
                                            ),
                                          ),
                                        if (!message.isStreaming && message.text.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () => voice.toggleSpeak(
                                                message.text,
                                                messageKey: msgKey,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isCurrentSpeaking
                                                          ? Icons.stop_circle_rounded
                                                          : Icons.volume_up_rounded,
                                                      size: 18,
                                                      color: isCurrentSpeaking
                                                          ? AppColors.accent
                                                          : cs.onSurfaceVariant.withValues(alpha: 0.8),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isCurrentSpeaking ? 'Ferma' : 'Ascolta',
                                                      style: theme.textTheme.labelSmall?.copyWith(
                                                        color: isCurrentSpeaking
                                                            ? AppColors.accent
                                                            : cs.onSurfaceVariant.withValues(alpha: 0.8),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (message.isEmergency)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 480),
                                        child: _buildEmergencyBanner(theme),
                                      ),
                                    ),
                                  if (message.guardrailCategory == 'off_topic' ||
                                      message.guardrailCategory == 'jailbreak_blocked')
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 480),
                                        child: _buildQuickSuggestionChips(theme),
                                      ),
                                    ),
                                  if (!message.isStreaming && message.suggestedAction != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 480),
                                        child: _buildSuggestedActionCard(
                                          theme,
                                          message.suggestedAction!,
                                        ),
                                      ),
                                    ),
                                  if (message.visibleProposals.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 480),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (final proposal in message.visibleProposals)
                                              ClinicalProposalCard(
                                                key: ValueKey('${message.id}_${proposal.proposalId}'),
                                                messageId: message.id,
                                                proposal: proposal,
                                                onDismiss: () {
                                                  _autoRelistenTimer?.cancel();
                                                  chat.dismissProposal(message.id, proposal.proposalId);
                                                },
                                                onConfirm: (finalData) async {
                                                  _autoRelistenTimer?.cancel();
                                                  if (voice.isListening && _liveSpokenText.trim().isEmpty) {
                                                    await voice.cancelListening();
                                                  }
                                                  final ok = await chat.confirmProposal(
                                                    message.id,
                                                    proposal.proposalId,
                                                    finalData,
                                                  );
                                                  if (ok && mounted) {
                                                    _refreshDomainProvider(proposal.targetTable);
                                                  }
                                                  return ok;
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                        ],
                                      ),
                                    ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : showLiveVoiceBubble
                            ? ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                children: [
                                  _ChatGreeting(greeting: _greeting),
                                  const SizedBox(height: 12),
                                  _buildLiveListeningUserBubble(theme, cs),
                                ],
                              )
                            : _ChatGreeting(greeting: _greeting),
                  ),
                ),
              ),
              // "Nuova chat": compare solo quando il contesto sta per esaurirsi
              // (>= 80% dello storico massimo), come promemoria discreto sopra
              // l'input. Logica del reset da aggiungere dopo.
              if (chat.hasMessages && chat.messages.length >= (chat.maxHistory * 0.8).round())
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              unawaited(_exitVoiceConversationMode());
                              chat.newChat();
                            },
                            icon: const Icon(Icons.add_comment_outlined, size: 18),
                            label: const Text('Nuova chat'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              visualDensity: VisualDensity.compact,
                              textStyle: theme.textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Se il consenso IA è stato revocato (GDPR Art. 7.3 e Art. 9), mostra banner informativo dedicato
              if (profile.hasLoaded && !profile.aiHealthConsent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Card(
                        color: cs.surfaceContainerHighest,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.smart_toy_outlined, color: cs.primary, size: 28),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Assistente IA disattivato',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hai revocato il consenso al trattamento dei dati sanitari con l\'Intelligenza Artificiale (GDPR Art. 9). '
                                'Il tuo diario glicemico e i tuoi dati personali restano al sicuro.\n'
                                'Per riattivare l\'assistente conversazionale, concedi nuovamente il consenso nelle Impostazioni.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  icon: const Icon(Icons.settings_outlined, size: 18),
                                  label: const Text('Apri Impostazioni'),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Barra di inserimento messaggio, allegato, microfono o barra Conversazione Vocale Live.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_pendingAttachment != null)
                            _buildAttachmentPreview(theme, cs),
                          if (showVoiceBar)
                            _buildVoiceConversationBar(theme, cs, chat, voice)
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.multiline,
                                    minLines: 1,
                                    maxLines: 5,
                                    textInputAction: TextInputAction.newline,
                                    style: theme.textTheme.bodyMedium,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: cs.surfaceContainerLowest,
                                      hintText: _pendingAttachment == null
                                          ? 'Scrivi un messaggio...'
                                          : (_pendingAttachment!.kind == 'meal_photo'
                                              ? 'Aggiungi dettagli (es. 150 g, marca) o invia...'
                                              : 'Aggiungi un messaggio o invia...'),
                                      hintMaxLines: 1,
                                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                                        fontSize: 14.5,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 12,
                                      ),
                                      prefixIconConstraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 48,
                                      ),
                                      prefixIcon: IconButton(
                                        icon: const Icon(Icons.attach_file_rounded, size: 22),
                                        tooltip: 'Allega file',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 40,
                                          minHeight: 48,
                                        ),
                                        onPressed: _showAttachmentModal,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: cs.outlineVariant.withValues(alpha: 0.8),
                                          width: 1.2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: cs.outlineVariant.withValues(alpha: 0.8),
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: cs.primary,
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: FloatingActionButton(
                                    heroTag: 'mic',
                                    elevation: 1,
                                    tooltip: 'Avvia conversazione vocale',
                                    onPressed: _toggleListening,
                                    backgroundColor: cs.primaryContainer,
                                    child: Icon(
                                      Icons.mic_rounded,
                                      color: cs.onPrimaryContainer,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: FloatingActionButton(
                                    heroTag: 'send',
                                    elevation: 1,
                                    onPressed: chat.isSending ? null : _send,
                                    backgroundColor: cs.primary,
                                    child: Icon(
                                      Icons.send_rounded,
                                      color: cs.onPrimary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          Text(
                            'Sono un\'AI. NON sostituisco il medico.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: theme.brightness == Brightness.dark ? cs.onSurface : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      ),
    );
  }
}

/// Sfondo animato a tutto schermo che copre l'intera schermata della chat:
/// lavaggio di gradiente orbitante, orbs sfumati e onde morbide sul fondo.
/// Avvolge la SafeArea e tutti i controlli (bottoni in alto e barra di input in basso).
class _AnimatedChatBackground extends StatefulWidget {
  final Widget child;
  const _AnimatedChatBackground({required this.child});

  @override
  State<_AnimatedChatBackground> createState() => _AnimatedChatBackgroundState();
}

class _AnimatedChatBackgroundState extends State<_AnimatedChatBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // 20 step/s su un ciclo di 14s: movimento fluido identico, ma riduce ~75-80%
  // i repaint GPU degli shader rispetto a 60-120 FPS continui.
  static const int _fpsSteps = 280;

  late final AnimationController _controller;
  final ValueNotifier<int> _paintStep = ValueNotifier<int>(0);
  bool _disableAnimations = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..addListener(_onAnimationTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncTickerState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncTickerState();
  }

  void _syncTickerState() {
    final shouldRun = _isForeground && !_disableAnimations;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _onAnimationTick() {
    final step = (_controller.value * _fpsSteps).floor();
    if (step != _paintStep.value) {
      _paintStep.value = step;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    _paintStep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _OrbBackgroundPainter(
              stepListenable: _paintStep,
              fpsSteps: _fpsSteps,
              isDark: isDark,
              cs: cs,
              disableAnimations: _disableAnimations,
            ),
          ),
        ),
        RepaintBoundary(child: widget.child),
      ],
    );
  }
}

/// Contenuto centrale dello stato vuoto della chat: icona pulsante che "respira"
/// e messaggio di saluto casuale.
class _ChatGreeting extends StatefulWidget {
  final String greeting;
  const _ChatGreeting({required this.greeting});

  @override
  State<_ChatGreeting> createState() => _ChatGreetingState();
}

class _ChatGreetingState extends State<_ChatGreeting>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _disableAnimations = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncTickerState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncTickerState();
  }

  void _syncTickerState() {
    final shouldRun = _isForeground && !_disableAnimations;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final staticBadge = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? cs.primaryContainer.withValues(alpha: 0.35)
            : AppColors.lightPeach,
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 36,
        color: cs.primary,
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                child: staticBadge,
                builder: (context, child) {
                  final pulse = _disableAnimations ? 0.0 : _controller.value;
                  return SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.92 + pulse * 0.22,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary.withValues(
                                alpha: (isDark ? 0.18 : 0.14) * (1.15 - pulse * 0.35),
                              ),
                            ),
                          ),
                        ),
                        if (child != null) child,
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.greeting,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sfondo animato della chat: lavaggio di gradiente che orbita, quattro
/// orbs sfumati con effetto respiro e due onde sinusoidali morbide sul fondo.
/// Tutte le armoniche usano multipli interi di `t` (0..2π) per un loop continuo
/// senza alcuno scatto.
class _OrbBackgroundPainter extends CustomPainter {
  final ValueListenable<int> stepListenable;
  final int fpsSteps;
  final bool isDark;
  final ColorScheme cs;
  final bool disableAnimations;

  _OrbBackgroundPainter({
    required this.stepListenable,
    required this.fpsSteps,
    required this.isDark,
    required this.cs,
    required this.disableAnimations,
  }) : super(repaint: stepListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final t = disableAnimations ? 0.0 : (stepListenable.value / fpsSteps) * 2 * math.pi;
    final w = size.width;
    final h = size.height;
    final shortest = math.min(w, h);

    // 0. Base uniforme del canvas con il colore della superficie.
    canvas.drawRect(Offset.zero & size, Paint()..color = cs.surface);

    // 1. Lavaggio di colore di fondo che si muove dolcemente.
    final washCenter = Offset(
      w * 0.5 + math.sin(t) * w * 0.22,
      h * 0.32 + math.cos(t) * h * 0.14,
    );
    final washPaint = Paint()
      ..shader = RadialGradient(
        radius: 1.15,
        colors: [
          (isDark ? cs.primary : AppColors.lightPeach)
              .withValues(alpha: isDark ? 0.28 : 0.85),
          cs.surface.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: washCenter, radius: math.max(w, h) * 0.9));
    canvas.drawRect(Offset.zero & size, washPaint);

    // 2. Orbs sfumati con traiettoria fluida (Lissajous) ed effetto respiro.
    void orb({
      required Offset base,
      required double baseRadius,
      required Color color,
      required double phaseX,
      required double phaseY,
      int freqX = 1,
      int freqY = 1,
    }) {
      final center = base +
          Offset(
            math.sin(t * freqX + phaseX) * w * 0.15,
            math.cos(t * freqY + phaseY) * h * 0.11,
          );
      final breathingRadius =
          baseRadius * (0.9 + 0.16 * math.sin(t * 2 + phaseX));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: breathingRadius));
      canvas.drawCircle(center, breathingRadius, paint);
    }

    // Orb caldo arancio in alto a sinistra
    orb(
      base: Offset(w * 0.22, h * 0.24),
      baseRadius: shortest * 0.45,
      color: AppColors.vibrantOrange.withValues(alpha: isDark ? 0.26 : 0.24),
      phaseX: 0.0,
      phaseY: 0.6,
      freqX: 1,
      freqY: 2,
    );
    // Orb verde salvia a destra
    orb(
      base: Offset(w * 0.80, h * 0.44),
      baseRadius: shortest * 0.42,
      color: cs.secondary.withValues(alpha: isDark ? 0.24 : 0.20),
      phaseX: 1.4,
      phaseY: 0.9,
      freqX: 2,
      freqY: 1,
    );
    // Orb azzurro in basso al centro-sinistra
    orb(
      base: Offset(w * 0.38, h * 0.76),
      baseRadius: shortest * 0.48,
      color: cs.tertiary.withValues(alpha: isDark ? 0.22 : 0.18),
      phaseX: 2.6,
      phaseY: 1.8,
      freqX: 1,
      freqY: 1,
    );
    // Quarto orb pesca/primario che attraversa il centro
    orb(
      base: Offset(w * 0.62, h * 0.22),
      baseRadius: shortest * 0.36,
      color: cs.primary.withValues(alpha: isDark ? 0.20 : 0.18),
      phaseX: 4.0,
      phaseY: 2.2,
      freqX: 2,
      freqY: 2,
    );

    // 3. Due onde sinusoidali morbide sul fondo per dare continuità visiva.
    void drawWave({
      required double baseYFactor,
      required double amplitude,
      required double phase,
      required int speed,
      required Color topColor,
    }) {
      final path = Path()..moveTo(0, h);
      final baseY = h * baseYFactor;
      const steps = 48;
      for (int i = 0; i <= steps; i++) {
        final x = (w / steps) * i;
        final nx = (i / steps) * 2 * math.pi;
        final y = baseY +
            math.sin(nx + t * speed + phase) * amplitude +
            math.cos(nx * 2 - t + phase) * (amplitude * 0.4);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();

      final wavePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            topColor,
            topColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, baseY - amplitude * 2, w, h - baseY + amplitude * 2));
      canvas.drawPath(path, wavePaint);
    }

    drawWave(
      baseYFactor: 0.78,
      amplitude: h * 0.032,
      phase: 0.0,
      speed: 1,
      topColor: cs.primary.withValues(alpha: isDark ? 0.14 : 0.12),
    );
    drawWave(
      baseYFactor: 0.85,
      amplitude: h * 0.026,
      phase: 2.1,
      speed: 2,
      topColor: cs.tertiary.withValues(alpha: isDark ? 0.12 : 0.10),
    );
  }

  @override
  bool shouldRepaint(_OrbBackgroundPainter old) =>
      old.isDark != isDark ||
      old.cs != cs ||
      old.disableAnimations != disableAnimations ||
      old.stepListenable != stepListenable;
}

/// Onda sonora minimalista a tutta larghezza che riempie il pulsante di ascolto.
/// Disegnata via CustomPainter ascoltando direttamente [soundLevelListenable]
/// (zero rebuild della schermata) e rispettando "Rimuovi animazioni" di sistema.
class _FullWidthSoundWave extends StatefulWidget {
  final Color color;
  final ValueListenable<double> soundLevelListenable;
  const _FullWidthSoundWave({
    required this.color,
    required this.soundLevelListenable,
  });

  @override
  State<_FullWidthSoundWave> createState() => _FullWidthSoundWaveState();
}

class _FullWidthSoundWaveState extends State<_FullWidthSoundWave>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _anim;
  late Listenable _repaintListenable;
  bool _disableAnimations = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _repaintListenable = Listenable.merge([_anim, widget.soundLevelListenable]);
  }

  @override
  void didUpdateWidget(covariant _FullWidthSoundWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soundLevelListenable != widget.soundLevelListenable) {
      _repaintListenable = Listenable.merge([_anim, widget.soundLevelListenable]);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncTickerState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncTickerState();
  }

  void _syncTickerState() {
    final shouldRun = _isForeground && !_disableAnimations;
    if (shouldRun && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!shouldRun && _anim.isAnimating) {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 40,
        width: double.infinity,
        child: CustomPaint(
          painter: _FullWidthSoundWavePainter(
            repaint: _repaintListenable,
            anim: _anim,
            soundLevelListenable: widget.soundLevelListenable,
            color: widget.color,
            disableAnimations: _disableAnimations,
          ),
        ),
      ),
    );
  }
}

class _FullWidthSoundWavePainter extends CustomPainter {
  final Animation<double> anim;
  final ValueListenable<double> soundLevelListenable;
  final Color color;
  final bool disableAnimations;

  _FullWidthSoundWavePainter({
    required Listenable repaint,
    required this.anim,
    required this.soundLevelListenable,
    required this.color,
    required this.disableAnimations,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    const barWidth = 4.5;
    const barGap = 5.5;
    const step = barWidth + barGap;
    final barCount = math.max(7, (size.width / step).floor());
    final totalUsedWidth = barCount * barWidth + (barCount - 1) * barGap;
    final startX = (size.width - totalUsedWidth) / 2.0;
    final centerY = size.height / 2.0;
    final maxBarH = size.height;
    const minBarH = 6.0;

    final t = disableAnimations ? 0.0 : anim.value * 2 * math.pi;
    final level = soundLevelListenable.value.clamp(0.0, 1.0);
    // Ampiezza reattiva alla voce dell'utente con movimento base morbido in attesa.
    final energy = 0.42 + (level * 0.58);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      // Posizione normalizzata [-1 .. 1]: curva morbida più alta al centro e dolce ai bordi
      final norm = barCount == 1 ? 0.0 : (i / (barCount - 1)) * 2.0 - 1.0;
      final envelope = 0.38 + 0.62 * math.cos(norm * math.pi * 0.48);

      final wave = disableAnimations
          ? 0.55
          : (0.55 +
                  0.30 * math.sin(t * 2 + i * 0.65) +
                  0.15 * math.cos(t * 3 - i * 0.95))
              .clamp(0.15, 1.0);

      final barH = (minBarH + (maxBarH - minBarH) * envelope * wave * energy)
          .clamp(minBarH, maxBarH);
      final left = startX + i * step;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, centerY - barH / 2.0, barWidth, barH),
        const Radius.circular(barWidth / 2.0),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_FullWidthSoundWavePainter old) =>
      old.color != color ||
      old.disableAnimations != disableAnimations ||
      old.soundLevelListenable != soundLevelListenable;
}
