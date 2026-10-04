// Chat Repository - sesuai PRD v1.3 Section 2

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import 'chat_models.dart';

class ChatRepository {
  SupabaseClient get _supabase => SupabaseService.client;
  final _uuid = const Uuid();

  // Ambil daftar thread chat
  Future<List<ChatThread>> getThreads(String userId) async {
    try {
      final response = await _supabase
          .from('chat_threads')
          .select('''
            *,
            workshops:workshop_id(name)
          ''')
          .or('rider_id.eq.$userId,workshop_id.eq.$userId')
          .order('last_message_at', ascending: false);

      return (response as List)
          .map(
            (json) => ChatThread.fromJson({
              ...json,
              'workshop_name': json['workshops']?['name'],
              'workshop_avatar': json['workshops']?['avatar_url'],
            }),
          )
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat daftar chat: $e');
    }
  }

  // Ambil pesan dalam thread
  Future<List<ChatMessage>> getMessages(
      String threadId, String currentUserId) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: true)
          .limit(100);

      return (response as List)
          .map((json) =>
              ChatMessage.fromJson(json, currentUserId: currentUserId))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat pesan: $e');
    }
  }

  // Kirim pesan - lewat RPC untuk filtering dan validasi
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String senderId,
    required MessageKind kind,
    String? body,
    List<String>? mediaPaths,
    String? quoteId,
    double? latitude,
    double? longitude,
  }) async {
    final clientId = _uuid.v4();

    try {
      final response = await _supabase.rpc(
        'chat_send',
        params: {
          'p_thread_id': threadId,
          'p_sender_id': senderId,
          'p_kind': kind.name,
          'p_body': body,
          'p_media_paths': mediaPaths ?? [],
          'p_quote_id': quoteId,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_client_id': clientId,
        },
      );

      return ChatMessage.fromJson(response, currentUserId: senderId);
    } catch (e) {
      throw Exception('Gagal mengirim pesan: $e');
    }
  }

  // Tandai pesan sebagai dibaca
  Future<void> markAsRead(String threadId, String userId) async {
    try {
      await _supabase.rpc(
        'chat_mark_read',
        params: {
          'p_thread_id': threadId,
          'p_user_id': userId,
        },
      );
    } catch (e) {
      // Tidak perlu throw, karena ini non-blocking
      debugPrint('Gagal menandai sebagai dibaca: $e');
    }
  }

  // Subscribe ke perubahan pesan (Realtime)
  RealtimeChannel subscribeToMessages(
    String threadId,
    void Function(ChatMessage) onMessage,
  ) {
    final channel = _supabase
        .channel('chat:$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'thread_id',
              value: threadId),
          callback: (payload) {
            final userId = _supabase.auth.currentUser?.id ?? '';
            final message = ChatMessage.fromJson(
              payload.newRecord,
              currentUserId: userId,
            );
            onMessage(message);
          },
        )
        .subscribe();

    return channel;
  }

  // Subscribe ke status "sedang mengetik" (Broadcast)
  RealtimeChannel subscribeToTyping(
    String threadId,
    void Function(String userId, bool isTyping) onTypingChange,
  ) {
    final channel = _supabase
        .channel('typing:$threadId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final isTyping = payload['is_typing'] as bool? ?? false;
            if (userId != null) {
              onTypingChange(userId, isTyping);
            }
          },
        )
        .subscribe();

    return channel;
  }

  // Broadcast status "sedang mengetik"
  Future<void> broadcastTyping(
      String threadId, String userId, bool isTyping) async {
    try {
      final channel = _supabase.channel('typing:$threadId');
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': userId, 'is_typing': isTyping},
      );
    } catch (e) {
      // Non-blocking
      debugPrint('Gagal broadcast typing: $e');
    }
  }

  // Laporkan thread
  Future<void> reportThread({
    required String threadId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      await _supabase.from('chat_reports').insert({
        'thread_id': threadId,
        'reporter_id': reporterId,
        'reason': reason,
        'state': 'DITERIMA',
      });
    } catch (e) {
      throw Exception('Gagal melaporkan chat: $e');
    }
  }

  // Upload foto chat (maksimal 2 MB)
  Future<String> uploadChatImage(String threadId, String filePath) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final path = 'chat/$threadId/$fileName';

      await _supabase.storage.from('chat-media').upload(path, filePath);

      final url = _supabase.storage.from('chat-media').getPublicUrl(path);
      return url;
    } catch (e) {
      throw Exception('Gagal upload foto: $e');
    }
  }

  // Unsubscribe dari channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  // Ambil satu thread (dipakai layar chat room).
  Future<ChatThread> getThread(String threadId) async {
    try {
      final response = await _supabase.from('chat_threads').select('''
            *,
            workshops:workshop_id(name)
          ''').eq('id', threadId).single();

      return ChatThread.fromJson({
        ...response,
        'workshop_name': response['workshops']?['name'],
      });
    } catch (e) {
      throw Exception('Gagal memuat chat: $e');
    }
  }

  // Ambil thread chat untuk sebuah panggilan darurat (bila sudah dibuat).
  Future<ChatThread?> getThreadForSos(String sosRequestId) async {
    try {
      final response = await _supabase.from('chat_threads').select('''
            *,
            workshops:workshop_id(name)
          ''').eq('sos_request_id', sosRequestId).maybeSingle();

      if (response == null) return null;
      return ChatThread.fromJson({
        ...response,
        'workshop_name': response['workshops']?['name'],
      });
    } catch (e) {
      throw Exception('Gagal memuat chat: $e');
    }
  }
}
