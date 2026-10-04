// Chat Room Screen - sesuai PRD v1.3 Section 2.2

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/media_guard.dart';
import '../../../design/components/chat_components.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';

class ChatRoomScreen extends StatefulWidget {
  final String threadId;
  final String? bookingCode; // untuk BookingPinnedCard

  const ChatRoomScreen({
    super.key,
    required this.threadId,
    this.bookingCode,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _repository = ChatRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  ChatThread? _thread;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  String? _error;
  String? _currentUserId;

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _typingChannel;
  Timer? _typingTimer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadThread();
    _loadMessages();
    _subscribeToMessages();
    _subscribeToTyping();

    // Detect reduce motion preference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reduceMotion = MediaQuery.of(context).disableAnimations;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _unsubscribe();
    super.dispose();
  }

  Future<void> _loadThread() async {
    try {
      final thread = await _repository.getThread(widget.threadId);
      setState(() {
        _thread = thread;
      });

      // Mark as read
      await _repository.markAsRead(widget.threadId, _currentUserId!);
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat chat: $e';
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages =
          await _repository.getMessages(widget.threadId, _currentUserId!);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat pesan: $e';
        _isLoading = false;
      });
    }
  }

  void _subscribeToMessages() {
    _messageChannel = _repository.subscribeToMessages(
      widget.threadId,
      (message) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();

        // Mark as read if not mine
        if (!message.isMine) {
          _repository.markAsRead(widget.threadId, _currentUserId!);
        }
      },
    );
  }

  void _subscribeToTyping() {
    _typingChannel = _repository.subscribeToTyping(
      widget.threadId,
      (userId, isTyping) {
        if (userId != _currentUserId) {
          setState(() {
            _isTyping = isTyping;
          });
        }
      },
    );
  }

  Future<void> _unsubscribe() async {
    if (_messageChannel != null) {
      await _repository.unsubscribe(_messageChannel!);
    }
    if (_typingChannel != null) {
      await _repository.unsubscribe(_typingChannel!);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text, List<String>? mediaPaths}) async {
    if ((text == null || text.trim().isEmpty) &&
        (mediaPaths == null || mediaPaths.isEmpty)) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _repository.sendMessage(
        threadId: widget.threadId,
        senderId: _currentUserId!,
        kind: mediaPaths != null && mediaPaths.isNotEmpty
            ? MessageKind.image
            : MessageKind.text,
        body: text?.trim(),
        mediaPaths: mediaPaths,
      );

      _messageController.clear();
      _scrollToBottom();

      // Stop typing indicator
      _repository.broadcastTyping(widget.threadId, _currentUserId!, false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Validasi ukuran ≤2MB
      try {
        await MediaGuard.ensureFileUnderLimit(File(pickedFile.path));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ukuran media anda terlalu besar segera kompres file media untuk melanjutkan',
              ),
            ),
          );
        }
        return;
      }

      // Upload
      setState(() {
        _isSending = true;
      });

      final url = await _repository.uploadChatImage(
        widget.threadId,
        pickedFile.path,
      );

      await _sendMessage(mediaPaths: [url]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload foto: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _onTextChanged(String text) {
    if (_currentUserId == null) return;
    // Broadcast typing indicator
    final isTyping = text.trim().isNotEmpty;
    _repository.broadcastTyping(widget.threadId, _currentUserId!, isTyping);

    // Auto-stop after 2 seconds
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _repository.broadcastTyping(widget.threadId, _currentUserId!, false);
      });
    }
  }

  void _onQuickReplyTap(String text) {
    _messageController.text = text;
    _sendMessage(text: text);
  }

  void _showReportSheet() {
    final colors = Theme.of(context).extension<AppColors>()!;
    String? selectedReason;
    bool submitting = false;

    const reasons = [
      'Perilaku tidak pantas',
      'Mencoba transaksi di luar aplikasi',
      'Spam atau penipuan',
      'Bahasa kasar',
      'Lainnya',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Laporkan chat ini?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Laporan masuk antrean moderasi admin. Thread tetap bisa dibaca hingga selesai ditinjau.',
                    style: TextStyle(
                      color: colors.ink2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...reasons.map(
                    (reason) => RadioListTile<String>(
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (value) =>
                          setSheetState(() => selectedReason = value),
                      title: Text(reason),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (selectedReason == null || submitting)
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              setSheetState(() => submitting = true);
                              try {
                                await _repository.reportThread(
                                  threadId: widget.threadId,
                                  reporterId: _currentUserId!,
                                  reason: selectedReason!,
                                );
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Laporan terkirim. Terima kasih.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (mounted) {
                                  setSheetState(() => submitting = false);
                                }
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Gagal melapor: $e')),
                                );
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Kirim laporan'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.stage,
      appBar: AppBar(
        backgroundColor: colors.panel,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: _thread != null
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.blueSoft,
                    child: Text(
                      _thread!.workshopName?.substring(0, 2).toUpperCase() ??
                          'BK',
                      style: TextStyle(
                        color: colors.blueText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _thread!.workshopName ?? 'Bengkel',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (_thread!.canSend)
                          Text(
                            'Online',
                            style: TextStyle(
                              color: colors.okText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showReportSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Booking Pinned Card (jika ada)
          if (widget.bookingCode != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.panel,
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bookingCode!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Ganti oli matic',
                          style: TextStyle(
                            color: colors.ink2,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Kam, 2 Okt · 09.00 WIB',
                          style: TextStyle(
                            color: colors.ink2,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.ink2),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.blue),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: colors.ink2,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(color: colors.ink2),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                  _isLoading = true;
                                });
                                _loadMessages();
                              },
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: colors.ink2,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada pesan',
                                  style: TextStyle(
                                    color: colors.ink2,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Mulai percakapan dengan bengkel',
                                  style: TextStyle(
                                    color: colors.ink2,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length + (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length && _isTyping) {
                                return const TypingDots();
                              }

                              final message = _messages[index];

                              if (message.kind == MessageKind.system) {
                                return SystemMessage(
                                  text: message.body ?? '',
                                );
                              }

                              return ChatBubble(
                                message: message,
                                reduceMotion: _reduceMotion,
                              );
                            },
                          ),
          ),

          // Quick Replies
          if (_thread != null && _thread!.canSend)
            QuickReplyRow(
              replies: QuickReplies.riderReplies,
              onReplyTap: _onQuickReplyTap,
            ),
          const SizedBox(height: 8),

          // Composer
          ChatComposer(
            controller: _messageController,
            onSend: () => _sendMessage(text: _messageController.text),
            onImagePick: _pickImage,
            onChanged: _onTextChanged,
            sending: _isSending,
            enabled: _thread?.canSend ?? false,
            disabledMessage: _thread?.state == ChatThreadState.readonly
                ? 'Chat sudah ditutup'
                : 'Chat terbuka setelah bengkel menerima booking-mu',
          ),
        ],
      ),
    );
  }
}
