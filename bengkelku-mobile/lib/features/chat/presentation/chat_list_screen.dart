// Daftar chat (chatList) — sesuai PRD v1.3 Bagian 2.2
//
// State: loading (SkeletonList), empty (EmptyState), error (ErrorState).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design/components/chat_components.dart';
import '../../../design/components/state_views.dart';
import 'chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    // Segarkan daftar saat layar dibuka (mungkin ada pesan baru).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatThreadsProvider.notifier).refresh();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(chatThreadsProvider.notifier).refresh();
  }

  void _openThread(String threadId) {
    context.push('/chat/$threadId');
    // Reset badge lencana secara lokal; server akan kirim nilai sebenarnya.
    ref.read(chatThreadsProvider.notifier).markRead(threadId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final asyncThreads = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Chat'),
        elevation: 0,
        backgroundColor: c.panel,
      ),
      body: asyncThreads.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(),
        ),
        error: (e, _) => ErrorState(
          message: 'Gagal memuat daftar chat',
          onRetry: () => ref.read(chatThreadsProvider.notifier).refresh(),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Belum ada chat',
              message:
                  'Chat dengan bengkel terbuka setelah booking-mu dibayar dan diterima.',
            );
          }

          return RefreshIndicator(
            color: c.blue,
            onRefresh: _onRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: threads.length,
              separatorBuilder: (_, __) =>
                  Divider(color: c.line, height: 1, indent: 76),
              itemBuilder: (context, index) {
                final thread = threads[index];
                return ChatThreadTile(
                  thread: thread,
                  onTap: () => _openThread(thread.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
