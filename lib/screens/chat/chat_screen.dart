import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_models.dart';
import '../../models/proposed_entry.dart';
import '../../providers/appointments_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/clinical_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/clinical_proposal_card.dart';
import '../../widgets/formatted_chat_message.dart';
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

class _ChatScreenState extends State<ChatScreen> {
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
  final _spokenMessageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _draftFocusNode = FocusNode();
  String _liveSpokenText = '';
  bool _hasSpokenMessage = false;

  // Lazy: con l'hot reload initState non viene ri-eseguito sugli stati già
  // vivi, un late assegnato lì andrebbe in LateInitializationError.
  late final String _greeting = _greetings[math.Random().nextInt(_greetings.length)];

  @override
  void dispose() {
    _controller.dispose();
    _spokenMessageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _draftFocusNode.dispose();
    try {
      context.read<VoiceService>().stopSpeaking();
      context.read<VoiceService>().stopListening();
    } catch (_) {}
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
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
      final ext = name.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'webp') mimeType = 'image/webp';

      Uint8List finalBytes = bytes;
      if (isReport) {
        final sanitized = await ReportPrivacyMaskDialog.show(
          context,
          imageBytes: bytes,
          fileName: name,
        );
        if (sanitized == null || !mounted) return;
        finalBytes = sanitized;
      }

      setState(() {
        _pendingAttachment = _PendingAttachment(
          fileName: name,
          kind: kind,
          mimeType: mimeType,
          bytes: finalBytes,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile selezionare l\'immagine: $e')),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile leggere il file selezionato')),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile selezionare il PDF: $e')),
        );
      }
    }
  }

  void _showAttachmentModal() {
    final hasAiConsent = context.read<ProfileProvider>().aiHealthConsent;
    if (!hasAiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Consenso al trattamento dati sanitari con IA revocato. Riattivalo dalle Impostazioni.',
          ),
        ),
      );
      return;
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
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
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.privacy_tip_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Privacy by Design: per le foto dei referti puoi regolare l\'oscuramento dei dati anagrafici nell\'anteprima prima dell\'invio.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                            color: cs.onSurfaceVariant,
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
    );
  }

  void _showGalleryChoiceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
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

  Future<void> _send({String? overrideText}) async {
    final hasAiConsent = context.read<ProfileProvider>().aiHealthConsent;
    if (!hasAiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Consenso al trattamento dati sanitari con IA revocato. Riattivalo dalle Impostazioni per chattare.',
          ),
        ),
      );
      return;
    }
    final chat = context.read<ChatProvider>();
    final voice = context.read<VoiceService>();
    final text = (overrideText ?? _controller.text).trim();
    final att = _pendingAttachment;
    if ((text.isEmpty && att == null) || chat.isSending) return;

    if (voice.isListening) {
      await voice.stopListening();
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
      _hasSpokenMessage = false;
      _liveSpokenText = '';
      _spokenMessageController.clear();
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
    if (!ok && chat.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chat.errorMessage!)));
    } else if (ok) {
      if (attachmentIn != null) {
        unawaited(context.read<ReportsProvider>().refresh());
      }
      final settings = context.read<SettingsProvider>();
      if (settings.autoTts && chat.messages.isNotEmpty) {
        final lastMsg = chat.messages.last;
        if (!lastMsg.isUser && lastMsg.text.isNotEmpty) {
          final msgKey = lastMsg.id;
          unawaited(voice.speak(lastMsg.text, messageKey: msgKey));
        }
      }
    }
  }

  Future<void> _toggleListening() async {
    // Chiudi subito la tastiera virtuale se aperta
    FocusScope.of(context).unfocus();
    _focusNode.unfocus();

    final hasAiConsent = context.read<ProfileProvider>().aiHealthConsent;
    if (!hasAiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Consenso al trattamento dati sanitari con IA revocato. Riattivalo dalle Impostazioni per usare il microfono.',
          ),
        ),
      );
      return;
    }
    final voice = context.read<VoiceService>();
    if (voice.isListening) {
      await voice.stopListening();
      if (_liveSpokenText.trim().isNotEmpty) {
        setState(() {
          _spokenMessageController.text = _liveSpokenText.trim();
          _hasSpokenMessage = true;
          _liveSpokenText = '';
        });
        _scrollToEnd();
      }
      return;
    }

    setState(() {
      _liveSpokenText = '';
      _hasSpokenMessage = false;
      _spokenMessageController.clear();
    });

    final started = await voice.startListening(
      onResult: (words) {
        if (!mounted) return;
        setState(() {
          _liveSpokenText = words;
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_liveSpokenText.trim().isNotEmpty && !_hasSpokenMessage) {
          setState(() {
            _spokenMessageController.text = _liveSpokenText.trim();
            _hasSpokenMessage = true;
            _liveSpokenText = '';
          });
          _scrollToEnd();
        }
      },
    );

    if (!started && mounted && voice.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(voice.lastError!)),
      );
    }
  }

  /// Predisposizione per l'input vocale Speech-to-Text (STT) futuro.
  void onVoiceTranscriptReceived(String transcript, {bool autoSend = false}) {
    final text = transcript.trim();
    if (text.isEmpty) return;
    if (autoSend) {
      _controller.text = text;
      _send();
    } else {
      setState(() {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      });
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

  Widget _buildListeningBanner(ThemeData theme, ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const _AudioWaveformLines(color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _liveSpokenText.isNotEmpty
                  ? _liveSpokenText
                  : 'In ascolto... Parla pure',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _liveSpokenText.isNotEmpty ? cs.onSurface : cs.onSurfaceVariant,
                fontStyle: _liveSpokenText.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                fontWeight: _liveSpokenText.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpokenDraftBubble(ThemeData theme, ColorScheme cs) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = screenWidth > 640 ? 540.0 : (screenWidth * 0.82);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.25),
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                  tooltip: 'Modifica testo',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    _draftFocusNode.requestFocus();
                    _spokenMessageController.selection = TextSelection.collapsed(
                      offset: _spokenMessageController.text.length,
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                  tooltip: 'Annulla',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    setState(() {
                      _hasSpokenMessage = false;
                      _spokenMessageController.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                _draftFocusNode.requestFocus();
                _spokenMessageController.selection = TextSelection.collapsed(
                  offset: _spokenMessageController.text.length,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _spokenMessageController,
                  focusNode: _draftFocusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Modifica testo...',
                    hintStyle: TextStyle(color: Colors.white60),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _send(overrideText: _spokenMessageController.text),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Invia',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

    return _AnimatedChatBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                  voice.stopSpeaking();
                  chat.newChat();
                },
              ),
          ],
        ),
        drawer: const ChatDrawer(),
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
                            itemCount: chat.messages.length + (_hasSpokenMessage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_hasSpokenMessage && index == chat.messages.length) {
                                return _buildSpokenDraftBubble(theme, cs);
                              }
                              final message = chat.messages[index];
                              if (message.isUser) {
                                return _bubble(
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
                                );
                              }

                              final msgKey = message.id;
                              final isCurrentSpeaking =
                                  voice.isSpeaking && voice.speakingMessageKey == msgKey;

                              final isDark = theme.brightness == Brightness.dark;

                              return Padding(
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
                                                onDismiss: () => chat.dismissProposal(message.id, proposal.proposalId),
                                                onConfirm: (finalData) async {
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
                              );
                            },
                          )
                        : _hasSpokenMessage
                            ? ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                children: [
                                  _ChatGreeting(greeting: _greeting),
                                  const SizedBox(height: 12),
                                  _buildSpokenDraftBubble(theme, cs),
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
                              voice.stopSpeaking();
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
                // Barra di inserimento messaggio, allegato, microfono e invio.
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: voice.isListening
                                    ? _buildListeningBanner(theme, cs)
                                    : TextField(
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
                                          hintText: 'Scrivi un messaggio...',
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
                                width: 48,
                                height: 48,
                                child: FloatingActionButton(
                                  heroTag: 'mic',
                                  elevation: 1,
                                  tooltip: voice.isListening ? 'Ferma ascolto' : 'Parla al microfono',
                                  onPressed: _toggleListening,
                                  backgroundColor: voice.isListening
                                      ? AppColors.accent
                                      : cs.primaryContainer,
                                  child: Icon(
                                    voice.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                    color: voice.isListening
                                        ? Colors.white
                                        : cs.onPrimaryContainer,
                                    size: 24,
                                  ),
                                ),
                              ),
                              if (!voice.isListening) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 48,
                                  height: 48,
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = disableAnimations ? 0.0 : _controller.value * 2 * math.pi;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _OrbBackgroundPainter(t: t, isDark: isDark, cs: cs),
            ),
            widget.child,
          ],
        );
      },
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final pulse = _controller.value;
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
                      Container(
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
                      ),
                    ],
                  ),
                );
              },
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
  final double t;
  final bool isDark;
  final ColorScheme cs;

  _OrbBackgroundPainter({required this.t, required this.isDark, required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
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
      old.t != t || old.isDark != isDark || old.cs != cs;
}

/// Visualizzatore ad onde sonore animate per il feedback vocale in tempo reale.
class _AudioWaveformLines extends StatefulWidget {
  final Color color;
  const _AudioWaveformLines({required this.color});

  @override
  State<_AudioWaveformLines> createState() => _AudioWaveformLinesState();
}

class _AudioWaveformLinesState extends State<_AudioWaveformLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value * 2 * math.pi;
        const barHeights = [14.0, 22.0, 28.0, 20.0, 12.0];
        const barPhases = [0.0, 1.2, 2.4, 3.6, 4.8];

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (i) {
            final wave = (math.sin(t * 2 + barPhases[i]) + 1.0) / 2.0;
            final h = 6.0 + (barHeights[i] - 6.0) * wave;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3.0,
              height: h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
