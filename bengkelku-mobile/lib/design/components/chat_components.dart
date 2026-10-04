// Chat UI Components - sesuai PRD v1.3 Section 2.2 & 2.3

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/motion/motion.dart';
import '../../features/chat/data/chat_models.dart';
import 'package:intl/intl.dart';

/// ChatThreadTile - Item di daftar chat
class ChatThreadTile extends StatelessWidget {
  final ChatThread thread;
  final VoidCallback onTap;

  const ChatThreadTile({
    super.key,
    required this.thread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final timeStr = _formatTime(thread.lastMessageAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar bengkel
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.blueSoft,
              child: thread.workshopAvatar != null
                  ? ClipOval(
                      child: Image.network(
                        thread.workshopAvatar!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      thread.workshopName?.substring(0, 2).toUpperCase() ?? 'BK',
                      style: TextStyle(
                        color: colors.blueText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Konten
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.workshopName ?? 'Bengkel',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (thread.isDarurat)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warnSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Darurat',
                            style: TextStyle(
                              color: colors.warnText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessageText ?? '',
                          style: TextStyle(
                            color: colors.ink2,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: colors.ink2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Badge unread
            if (thread.riderUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    thread.riderUnread > 9 ? '9+' : '${thread.riderUnread}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'baru saja';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} mnt';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} hari';
    } else {
      return DateFormat('d MMM').format(time);
    }
  }
}

/// ChatBubble - Gelembung pesan
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool reduceMotion;

  const ChatBubble({
    super.key,
    required this.message,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return TweenAnimationBuilder<double>(
      duration: reduceMotion ? const Duration(milliseconds: 100) : Motion.dStd,
      curve: Motion.easeOut,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: message.isMine ? colors.blue : colors.panel,
            border: message.isMine ? null : Border.all(color: colors.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(message.isMine ? 16 : 5),
              bottomRight: Radius.circular(message.isMine ? 5 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.body != null)
                Text(
                  message.body!,
                  style: TextStyle(
                    color: message.isMine ? Colors.white : colors.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (message.mediaPaths.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...message.mediaPaths.map(
                  (path) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        path,
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              if (message.isMine) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: message.isRead
                          ? colors.blue
                          : Colors.white.withOpacity(0.75),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// SystemMessage - Pesan sistem
class SystemMessage extends StatelessWidget {
  final String text;

  const SystemMessage({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colors.panel,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.ink2,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// TypingDots - Indikator sedang mengetik
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.panel,
          border: Border.all(color: colors.line),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = (_controller.value - (index * 0.15)) % 1.0;
                final opacity = progress < 0.3
                    ? 1.0
                    : progress < 0.6
                        ? 0.5
                        : 0.5;
                final offset = progress < 0.3 ? -5.0 : 0.0;

                return Container(
                  margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                  child: Transform.translate(
                    offset: Offset(0, offset),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.ink2.withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

/// QuickReplyRow - Baris balasan cepat
class QuickReplyRow extends StatelessWidget {
  final List<QuickReply> replies;
  final Function(String) onReplyTap;

  const QuickReplyRow({
    super.key,
    required this.replies,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: replies.map((reply) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => onReplyTap(reply.text),
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.panel,
                  border: Border.all(color: colors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  reply.text,
                  style: TextStyle(
                    color: colors.blueText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ChatComposer - Input pesan
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImagePick;
  final bool enabled;
  final String? disabledMessage;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onImagePick,
    this.enabled = true,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (!enabled && disabledMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: colors.panel2,
        child: Text(
          disabledMessage!,
          style: TextStyle(
            color: colors.ink2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          // Tombol gambar
          InkWell(
            onTap: onImagePick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.image_outlined,
                color: colors.ink,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // TextField
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.panel2,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                maxLength: 1000,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan…',
                  hintStyle: TextStyle(
                    color: colors.ink2,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  counterText: '',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tombol kirim
          InkWell(
            onTap: onSend,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
