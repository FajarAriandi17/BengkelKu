// Repository sisi bengkel Bantuan Darurat (PRD v1.3 Bagian 3.3–3.4, 3.8).
// Semua tulisan lewat RPC security definer (0012, 0017, 0018, 0019).

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/utils/media_guard.dart';
import '../domain/owner_sos_logic.dart';
import 'owner_sos_models.dart';
import 'sos_models.dart';

class OwnerSosRepository {
  SupabaseClient get _db => SupabaseService.client;

  /// Ubah PostgrestException jadi pesan yang bisa ditampilkan.
  static String friendlyError(Object e) {
    if (e is PostgrestException) return e.message;
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  // ---------------------------------------------------------------------------
  // Bengkel & siaga
  // ---------------------------------------------------------------------------

  Future<OwnerWorkshop?> getMyWorkshop() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    final row = await _db
        .from('workshops')
        .select('id, name, status, location')
        .eq('owner_id', uid)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row == null ? null : OwnerWorkshop.fromJson(row);
  }

  Future<WorkshopStandby?> getStandby(String workshopId) async {
    final row = await _db
        .from('workshop_standby')
        .select()
        .eq('workshop_id', workshopId)
        .maybeSingle();
    return row == null ? null : WorkshopStandby.fromJson(row);
  }

  Future<List<SosTier>> getTiers() async {
    try {
      final row = await _db
          .from('app_config')
          .select('value')
          .eq('key', 'sos_tiers')
          .maybeSingle();
      return SosTier.parse(row?['value']);
    } catch (_) {
      return SosTier.defaults;
    }
  }

  Future<WorkshopStandby> updateStandbySettings({
    required bool ready,
    required bool afterHours,
    required int radiusTierMax,
  }) async {
    final res = await _db.rpc(
      'sos_update_standby_settings',
      params: {
        'p_ready': ready,
        'p_after_hours': afterHours,
        'p_radius_tier_max': radiusTierMax,
      },
    );
    return WorkshopStandby.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Detak siaga: posisi terakhir + `last_seen_at` (kandidat harus ≤ 60 dtk).
  Future<void> heartbeat({
    required String workshopId,
    required double lat,
    required double lng,
  }) async {
    await _db.rpc(
      'sos_update_standby_position',
      params: {
        'p_workshop_id': workshopId,
        'p_lat': lat,
        'p_lng': lng,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tawaran
  // ---------------------------------------------------------------------------

  Future<List<SosOffer>> getOpenOffers() async {
    final res = await _db.rpc('sos_my_open_offers');
    return (res as List)
        .map((e) => SosOffer.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<SosOfferDetails> getOfferDetails(String offerId) async {
    final res =
        await _db.rpc('sos_offer_details', params: {'p_offer_id': offerId});
    return SosOfferDetails.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Mengembalikan request_id bila menang. Melempar "sudah diambil" bila
  /// bengkel lain lebih dulu.
  Future<String> acceptOffer(String offerId) async {
    final res = await _db.rpc('sos_accept', params: {'p_offer_id': offerId});
    return (res as Map)['request_id'] as String;
  }

  Future<void> skipOffer(String offerId) async {
    await _db.rpc('sos_skip_offer', params: {'p_offer_id': offerId});
  }

  /// Tawaran baru untuk bengkel ini (Realtime postgres changes, RLS berlaku).
  RealtimeChannel subscribeToOffers(
    String workshopId,
    void Function(SosOffer offer) onOffer,
  ) {
    return _db
        .channel('owner_offers:$workshopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workshop_id',
            value: workshopId,
          ),
          callback: (payload) {
            try {
              onOffer(SosOffer.fromJson(payload.newRecord));
            } catch (e) {
              debugPrint('Tawaran tidak valid: $e');
            }
          },
        )
        .subscribe();
  }

  /// Panggilan yang sedang ditangani bengkel ini (bila ada).
  Future<SosRequest?> getActiveJob(String workshopId) async {
    final row = await _db
        .from('sos_requests')
        .select()
        .eq('accepted_workshop_id', workshopId)
        .inFilter('status', const [
          'DITERIMA',
          'MENUJU_LOKASI',
          'TIBA',
          'MEMERIKSA',
          'DIKERJAKAN',
        ])
        .order('accepted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : SosRequest.fromJson(row);
  }

  // ---------------------------------------------------------------------------
  // Rute & kedatangan
  // ---------------------------------------------------------------------------

  /// Permintaan yang diterima bengkel ini (lokasi tepat terbuka via RLS).
  Future<SosRequest> getAcceptedRequest(String requestId) async {
    final row =
        await _db.from('sos_requests').select().eq('id', requestId).single();
    return SosRequest.fromJson(row);
  }

  Future<void> startRoute(String requestId) async {
    await _db.rpc('sos_start_route', params: {'p_request_id': requestId});
  }

  Future<void> markArrived(String requestId) async {
    await _db.rpc('sos_mark_arrived', params: {'p_request_id': requestId});
  }

  /// true bila kode benar (status → MEMERIKSA).
  Future<bool> verifyArrivalCode(String requestId, String code) async {
    final res = await _db.rpc(
      'sos_verify_arrival_code',
      params: {
        'p_request_id': requestId,
        'p_code': code,
      },
    );
    return res == true;
  }

  Future<void> complete(String requestId, {required bool withRepair}) async {
    await _db.rpc(
      'sos_complete',
      params: {
        'p_request_id': requestId,
        'p_with_repair': withRepair,
      },
    );
  }

  /// Simpan jejak lokasi (tiap 30 dtk). Broadcast 5 dtk lewat [broadcastLocation].
  Future<void> recordTracking({
    required String requestId,
    required double lat,
    required double lng,
    double? speed,
    double? heading,
  }) async {
    await _db.rpc(
      'sos_record_tracking',
      params: {
        'p_request_id': requestId,
        'p_lat': lat,
        'p_lng': lng,
        'p_speed': speed,
        'p_heading': heading,
      },
    );
  }

  /// Channel broadcast `sos:{id}` — sama dengan yang didengar pengendara.
  RealtimeChannel openLocationChannel(String requestId) =>
      _db.channel('sos:$requestId')..subscribe();

  Future<void> broadcastLocation(
    RealtimeChannel channel, {
    required double lat,
    required double lng,
    double? speed,
    double? heading,
  }) async {
    await channel.sendBroadcastMessage(
      event: 'location',
      payload: {
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'heading': heading,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  RealtimeChannel subscribeToRequest(
    String requestId,
    void Function(SosRequest) onUpdate,
  ) {
    return _db
        .channel('owner_sos_request:$requestId')
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
            try {
              onUpdate(SosRequest.fromJson(payload.newRecord));
            } catch (e) {
              debugPrint('Pembaruan permintaan tidak valid: $e');
            }
          },
        )
        .subscribe();
  }

  /// Unggah foto bukti penawaran ke `quote-photos` (≤ 2 MB). URL publik.
  Future<String> uploadQuotePhoto({
    required String requestId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    MediaGuard.ensureBytesUnderLimit(bytes);
    final ext = contentType == 'image/png' ? 'png' : 'jpg';
    final path = 'sos/$requestId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('quote-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _db.storage.from('quote-photos').getPublicUrl(path);
  }

  Future<QuoteLimits> getQuoteLimits() async {
    try {
      final rows = await _db.from('app_config').select('key, value').inFilter(
        'key',
        const ['quote_min_items', 'quote_max_items', 'quote_max_total'],
      );
      int read(String k, int d) {
        for (final r in rows) {
          if (r['key'] == k) return (r['value'] as num?)?.toInt() ?? d;
        }
        return d;
      }

      return QuoteLimits(
        minItems: read('quote_min_items', 1),
        maxItems: read('quote_max_items', 10),
        maxTotal: read('quote_max_total', 2000000),
      );
    } catch (_) {
      return const QuoteLimits();
    }
  }

  Future<void> unsubscribe(RealtimeChannel channel) =>
      _db.removeChannel(channel);
}
