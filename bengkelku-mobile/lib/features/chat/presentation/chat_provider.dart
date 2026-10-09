// Provider state untuk daftar thread chat & jumlah belum dibaca.
//
// Memakai StateNotifier agar unsubscribe Realtime dihandle di dispose.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

/// Daftar thread chat pengguna saat ini.
final chatThreadsProvider =
    StateNotifierProvider<ChatThreadsNotifier, AsyncValue<List<ChatThread>>>(
        (ref) {
  ref.watch(currentUserIdProvider);
  return ChatThreadsNotifier(ref.watch(chatRepositoryProvider));
});

class ChatThreadsNotifier extends StateNotifier<AsyncValue<List<ChatThread>>> {
  final ChatRepository _repository;
  RealtimeChannel? _channel;

  ChatThreadsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final threads = await _repository.getThreads(userId);
      if (mounted) state = AsyncValue.data(threads);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _subscribe() {
    // Segarkan daftar tiap ada pesan baru (thread_order & unread berubah).
    _channel = SupabaseService.client
        .channel('chat_threads_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> refresh() => _load();

  /// Tandai thread dibaca & perbarui badge secara lokal.
  Future<void> markRead(String threadId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await _repository.markAsRead(threadId, userId);

    state.whenData((threads) {
      state = AsyncValue.data(
        threads.map((t) {
          if (t.id == threadId) {
            return ChatThread(
              id: t.id,
              type: t.type,
              bookingId: t.bookingId,
              sosRequestId: t.sosRequestId,
              riderId: t.riderId,
              workshopId: t.workshopId,
              state: t.state,
              lastMessageAt: t.lastMessageAt,
              workshopUnread: t.workshopUnread,
              lastMessageText: t.lastMessageText,
              workshopName: t.workshopName,
              workshopAvatar: t.workshopAvatar,
              isDarurat: t.isDarurat,
            );
          }
          return t;
        }).toList(),
      );
    });
  }

  @override
  void dispose() {
    if (_channel != null) {
      SupabaseService.client.removeChannel(_channel!);
    }
    super.dispose();
  }
}

/// Jumlah total pesan belum dibaca (untuk lencana BottomNav).
final chatUnreadCountProvider = Provider<int>((ref) {
  final threads = ref.watch(chatThreadsProvider);
  return threads.maybeWhen(
    data: (list) =>
        list.fold(0, (sum, t) => sum + (t.riderUnread > 9 ? 9 : t.riderUnread)),
    orElse: () => 0,
  );
});
