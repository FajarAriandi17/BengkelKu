// Repository Pusat Bantuan (Fitur F). Tiket dibuat & dibalas lewat RPC
// (0014, 0019, 0020); baca tunduk RLS (hanya tiket milik sendiri).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/utils/media_guard.dart';
import 'support_models.dart';

final supportRepositoryProvider =
    Provider<SupportRepository>((ref) => SupportRepository());

class SupportRepository {
  SupabaseClient get _db => SupabaseService.client;

  static String friendlyError(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is MediaTooLargeException) return e.message;
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  Future<List<FaqItem>> getFaq() async {
    final row = await _db
        .from('app_config')
        .select('value')
        .eq('key', 'support_faq')
        .maybeSingle();
    return FaqItem.parse(row?['value']);
  }

  Future<List<SupportTicket>> getMyTickets() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _db
        .from('support_tickets')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return rows.map(SupportTicket.fromJson).toList();
  }

  Future<SupportTicket> getTicket(String id) async {
    final row =
        await _db.from('support_tickets').select().eq('id', id).single();
    return SupportTicket.fromJson(row);
  }

  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final rows = await _db
        .from('support_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return rows.map(SupportMessage.fromJson).toList();
  }

  /// Unggah foto ke bucket privat `support-photos` (≤ 2 MB). Mengembalikan
  /// path penyimpanan (admin membaca lewat signed URL).
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mime = 'image/jpeg',
  }) async {
    MediaGuard.ensureBytesUnderLimit(bytes);
    final uid = SupabaseService.currentUser?.id ?? 'anon';
    final ext = mime == 'image/png' ? 'png' : 'jpg';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('support-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime),
        );
    return path;
  }

  Future<String> signedPhotoUrl(String path) =>
      _db.storage.from('support-photos').createSignedUrl(path, 3600);

  Future<SupportTicket> createTicket({
    required SupportCategory category,
    required String description,
    List<String> photoPaths = const [],
    String? bookingId,
    String? sosRequestId,
    String? threadId,
  }) async {
    final res = await _db.rpc(
      'support_create_ticket',
      params: {
        'p_category': category.name,
        'p_description': description.trim(),
        'p_photos': photoPaths,
        'p_booking_id': bookingId,
        'p_sos_request_id': sosRequestId,
        'p_thread_id': threadId,
      },
    );
    return SupportTicket.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> reply(String ticketId, String body) async {
    await _db.rpc(
      'support_reply',
      params: {'p_ticket_id': ticketId, 'p_body': body.trim()},
    );
  }

  RealtimeChannel subscribeToTicket(
    String ticketId, {
    required void Function() onChange,
  }) {
    return _db
        .channel('support_ticket:$ticketId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: ticketId,
          ),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'support_tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: ticketId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel c) => _db.removeChannel(c);
}
