// SOS Repository - sesuai PRD v1.3 Section 3

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import 'sos_models.dart';

class SosRepository {
  SupabaseClient get _supabase => SupabaseService.client;

  // Quote biaya panggilan berdasarkan lokasi
  Future<SosFeeCalculation> quoteFee(double lat, double lng) async {
    try {
      final response = await _supabase.rpc('sos_quote_fee', params: {
        'p_lat': lat,
        'p_lng': lng,
      });

      return SosFeeCalculation.fromJson(response);
    } catch (e) {
      throw Exception('Gagal menghitung biaya: $e');
    }
  }

  // Buat permintaan darurat
  Future<SosRequest> createRequest({
    required String problemCode,
    String? problemNote,
    List<String>? photos,
    required double lat,
    required double lng,
    required double accuracyM,
    String? landmark,
  }) async {
    try {
      final response = await _supabase.rpc('sos_create', params: {
        'p_problem_code': problemCode,
        'p_problem_note': problemNote,
        'p_photos': photos ?? [],
        'p_lat': lat,
        'p_lng': lng,
        'p_accuracy_m': accuracyM,
        'p_landmark': landmark,
      });

      // sos_create mengembalikan { request, offers }.
      return SosRequest.fromJson(
        (response['request'] as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      throw Exception('Gagal membuat permintaan darurat: $e');
    }
  }

  // Ambil detail permintaan
  Future<SosRequest> getRequest(String requestId) async {
    try {
      final response = await _supabase
          .from('sos_requests')
          .select('''
            *,
            workshops:accepted_workshop_id(
              name,
              rating_avg
            )
          ''')
          .eq('id', requestId)
          .single();

      return SosRequest.fromJson({
        ...response,
        'workshop_name': response['workshops']?['name'],
        'workshop_rating': response['workshops']?['rating_avg'],
      });
    } catch (e) {
      throw Exception('Gagal memuat permintaan: $e');
    }
  }

  // Batalkan permintaan
  Future<Map<String, dynamic>> cancelRequest({
    required String requestId,
    required String reason,
  }) async {
    try {
      final response = await _supabase.rpc('sos_cancel', params: {
        'p_request_id': requestId,
        'p_reason': reason,
      });

      return {
        'refund_percent': response['refund_percent'] as int,
        'refund_amount': response['refund_amount'] as int,
        'message': response['message'] as String,
      };
    } catch (e) {
      throw Exception('Gagal membatalkan: $e');
    }
  }

  // Subscribe ke perubahan status permintaan (Realtime)
  RealtimeChannel subscribeToRequest(
    String requestId,
    void Function(SosRequest) onUpdate,
  ) {
    final channel = _supabase
        .channel('sos_request:$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'sos_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: requestId,
          ),
          callback: (payload) {
            final request = SosRequest.fromJson(payload.newRecord);
            onUpdate(request);
          },
        )
        .subscribe();

    return channel;
  }

  // Subscribe ke lokasi mekanik (Broadcast channel)
  RealtimeChannel subscribeToMechanicLocation(
    String requestId,
    void Function(MechanicLocation) onLocationUpdate,
  ) {
    final channel = _supabase
        .channel('sos:$requestId')
        .onBroadcast(
          event: 'location',
          callback: (payload) {
            final location = MechanicLocation.fromJson(payload);
            onLocationUpdate(location);
          },
        )
        .subscribe();

    return channel;
  }

  // Konfirmasi kode kedatangan (dari sisi pengendara)
  Future<void> confirmArrivalCode(String requestId, String code) async {
    try {
      await _supabase.rpc('sos_confirm_arrival', params: {
        'p_request_id': requestId,
        'p_code': code,
      });
    } catch (e) {
      throw Exception('Kode tidak valid atau sudah digunakan');
    }
  }

  // Upload foto masalah
  Future<String> uploadProblemPhoto(String requestId, String filePath) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'sos/$requestId/$fileName';

      await _supabase.storage.from('sos-photos').upload(path, filePath);

      final url = _supabase.storage.from('sos-photos').getPublicUrl(path);
      return url;
    } catch (e) {
      throw Exception('Gagal upload foto: $e');
    }
  }

  // Unsubscribe
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  // ===== WORKSHOP SIDE =====

  // Toggle siaga darurat (untuk pemilik bengkel)
  Future<void> toggleEmergencyReady({
    required String workshopId,
    required bool ready,
    int radiusTierMax = 4,
  }) async {
    try {
      await _supabase.rpc('sos_toggle_standby', params: {
        'p_workshop_id': workshopId,
        'p_ready': ready,
        'p_radius_tier_max': radiusTierMax,
      });
    } catch (e) {
      throw Exception('Gagal mengubah status siaga: $e');
    }
  }

  // Terima tawaran darurat (untuk bengkel).
  // sos_accept mengembalikan { request_id, workshop_id, mechanic_name }.
  Future<Map<String, dynamic>> acceptOffer(String offerId) async {
    try {
      final response = await _supabase.rpc('sos_accept', params: {
        'p_offer_id': offerId,
      });

      return (response as Map).cast<String, dynamic>();
    } catch (e) {
      if (e.toString().contains('already taken')) {
        throw Exception('Panggilan sudah diambil bengkel lain');
      }
      throw Exception('Gagal menerima panggilan: $e');
    }
  }

  // Tandai mekanik sudah tiba
  Future<String> markArrived(String requestId) async {
    try {
      final response = await _supabase.rpc('sos_mark_arrived', params: {
        'p_request_id': requestId,
      });

      return response['arrival_code'] as String;
    } catch (e) {
      throw Exception('Gagal menandai kedatangan: $e');
    }
  }

  // Broadcast lokasi mekanik (dipanggil tiap 5 detik saat menuju lokasi)
  Future<void> broadcastMechanicLocation({
    required String requestId,
    required double lat,
    required double lng,
    double? speed,
    double? heading,
  }) async {
    try {
      final channel = _supabase.channel('sos:$requestId');
      await channel.sendBroadcastMessage(
        event: 'location',
        payload: {
          'lat': lat,
          'lng': lng,
          'speed': speed,
          'heading': heading,
          'recorded_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Non-blocking
      debugPrint('Gagal broadcast lokasi: $e');
    }
  }

  // Subscribe ke tawaran baru (untuk bengkel yang siaga)
  RealtimeChannel subscribeToOffers(
    String workshopId,
    void Function(SosOffer, SosRequest) onNewOffer,
  ) {
    final channel = _supabase
        .channel('sos_offers:$workshopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workshop_id',
            value: workshopId,
          ),
          callback: (payload) async {
            final offer = SosOffer.fromJson(payload.newRecord);
            // Ambil detail request
            final request = await getRequest(offer.requestId);
            onNewOffer(offer, request);
          },
        )
        .subscribe();

    return channel;
  }

  // ===== TAMBAHAN v1.3: gelombang dispatch, pembayaran, lacak mekanik =====

  /// Lanjutkan gelombang dispatch berikutnya (PRD 3.4). Aman dipanggil berkala.
  Future<void> dispatchWave() async {
    try {
      await _supabase.rpc('sos_dispatch_wave');
    } catch (e) {
      debugPrint('Gagal dispatch wave: $e');
    }
  }

  /// Tandai biaya panggilan sudah dibayar → status MENCARI_BENGKEL (PRD 3.5).
  Future<SosRequest> markPaid(String requestId) async {
    try {
      final response = await _supabase.rpc('sos_mark_paid', params: {
        'p_request_id': requestId,
      });
      return SosRequest.fromJson((response as Map).cast<String, dynamic>());
    } catch (e) {
      throw Exception('Gagal menandai pembayaran: $e');
    }
  }
}
