import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "workshop_model.dart";

/// Repository untuk penarikan data bengkel & layanan.
class WorkshopRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Ambil bengkel terdekat via RPC PostGIS `nearby_workshops`
  Future<List<Workshop>> getNearbyWorkshops({
    required double lat,
    required double lng,
    double radiusMeters = 10000,
    int limit = 50,
  }) async {
    try {
      final response = await _client.rpc("nearby_workshops", params: {
        "lat": lat,
        "lng": lng,
        "radius_m": radiusMeters,
        "limit_n": limit,
      }) as List<dynamic>;

      return response.map((item) => Workshop.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      // Fallback query standar jika RPC belum di-seed di environment testing
      final response = await _client
          .from("workshops")
          .select()
          .eq("status", "verified")
          .limit(limit);
      return (response as List<dynamic>)
          .map((item) => Workshop.fromJson(item as Map<String, dynamic>))
          .toList();
    }
  }

  /// Ambil detail bengkel berdasarkan ID
  Future<Workshop?> getWorkshopDetail(String workshopId) async {
    final response = await _client
        .from("workshops")
        .select()
        .eq("id", workshopId)
        .maybeSingle();

    if (response == null) return null;
    return Workshop.fromJson(response);
  }

  /// Ambil daftar layanan sebuah bengkel
  Future<List<WorkshopServiceItem>> getWorkshopServices(String workshopId) async {
    final response = await _client
        .from("services")
        .select()
        .eq("workshop_id", workshopId)
        .eq("is_active", true);

    return (response as List<dynamic>)
        .map((item) => WorkshopServiceItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
