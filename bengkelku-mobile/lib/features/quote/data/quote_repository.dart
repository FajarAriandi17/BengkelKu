// Quote Repository - sesuai PRD v1.3 Section 4

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import 'quote_models.dart';

class QuoteRepository {
  SupabaseClient get _supabase => SupabaseService.client;

  // Buat penawaran (workshop side)
  Future<Quote> createQuote(QuoteCreateRequest request) async {
    try {
      final response = await _supabase.rpc(
        'quote_create',
        params: {
          'p_booking_id': request.bookingId,
          'p_sos_request_id': request.sosRequestId,
          'p_items': request.items.map((item) => item.toJson()).toList(),
          'p_note': request.note,
          'p_photos': request.photos,
        },
      );

      return Quote.fromJson(response);
    } catch (e) {
      throw Exception('Gagal membuat penawaran: $e');
    }
  }

  // Setujui penawaran (rider side)
  Future<void> approveQuote(String quoteId) async {
    try {
      await _supabase.rpc(
        'quote_approve',
        params: {
          'p_quote_id': quoteId,
        },
      );
    } catch (e) {
      throw Exception('Gagal menyetujui penawaran: $e');
    }
  }

  // Tolak penawaran (rider side)
  Future<void> rejectQuote(String quoteId, String? reason) async {
    try {
      await _supabase.rpc(
        'quote_reject',
        params: {
          'p_quote_id': quoteId,
          'p_reason': reason,
        },
      );
    } catch (e) {
      throw Exception('Gagal menolak penawaran: $e');
    }
  }

  // Ambil penawaran untuk booking
  Future<List<Quote>> getQuotesForBooking(String bookingId) async {
    try {
      final response = await _supabase
          .from('quotes')
          .select('''
            *,
            workshops:workshop_id(name)
          ''')
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => Quote.fromJson({
              ...json,
              'workshop_name': json['workshops']?['name'],
              'workshop_avatar': json['workshops']?['avatar_url'],
            }),
          )
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat penawaran: $e');
    }
  }

  // Ambil penawaran untuk SOS
  Future<List<Quote>> getQuotesForSos(String sosRequestId) async {
    try {
      final response = await _supabase
          .from('quotes')
          .select('''
            *,
            workshops:workshop_id(name)
          ''')
          .eq('sos_request_id', sosRequestId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => Quote.fromJson({
              ...json,
              'workshop_name': json['workshops']?['name'],
              'workshop_avatar': json['workshops']?['avatar_url'],
            }),
          )
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat penawaran: $e');
    }
  }

  // Ambil detail satu penawaran
  Future<Quote> getQuote(String quoteId) async {
    try {
      final response = await _supabase.from('quotes').select('''
            *,
            workshops:workshop_id(name)
          ''').eq('id', quoteId).single();

      return Quote.fromJson({
        ...response,
        'workshop_name': response['workshops']?['name'],
        'workshop_avatar': response['workshops']?['avatar_url'],
      });
    } catch (e) {
      throw Exception('Gagal memuat penawaran: $e');
    }
  }

  // Subscribe ke penawaran baru (Realtime)
  RealtimeChannel subscribeToQuotes({
    String? bookingId,
    String? sosRequestId,
    required void Function(Quote) onNewQuote,
  }) {
    final filterColumn = bookingId != null ? 'booking_id' : 'sos_request_id';
    final filterValue = bookingId ?? sosRequestId!;

    final channel = _supabase
        .channel('quotes:$filterValue')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'quotes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: filterColumn,
            value: filterValue,
          ),
          callback: (payload) {
            final quote = Quote.fromJson(payload.newRecord);
            onNewQuote(quote);
          },
        )
        .subscribe();

    return channel;
  }

  // Upload foto bukti penawaran
  Future<String> uploadQuotePhoto(String quoteId, String filePath) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'quotes/$quoteId/$fileName';

      await _supabase.storage.from('quote-photos').upload(path, filePath);

      final url = _supabase.storage.from('quote-photos').getPublicUrl(path);
      return url;
    } catch (e) {
      throw Exception('Gagal upload foto: $e');
    }
  }

  // Unsubscribe
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
