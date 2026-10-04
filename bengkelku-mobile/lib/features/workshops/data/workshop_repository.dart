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
      final response = await _client.rpc(
        "nearby_workshops",
        params: {
          "lat": lat,
          "lng": lng,
          "radius_m": radiusMeters,
          "limit_n": limit,
        },
      ) as List<dynamic>;

      return response
          .map((item) => Workshop.fromJson(item as Map<String, dynamic>))
          .toList();
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
  Future<List<WorkshopServiceItem>> getWorkshopServices(
      String workshopId) async {
    final response = await _client
        .from("services")
        .select()
        .eq("workshop_id", workshopId)
        .eq("is_active", true);

    return (response as List<dynamic>)
        .map((item) =>
            WorkshopServiceItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkshopHour>> getWorkshopHours(String workshopId) async {
    final res = await _client
        .from("workshop_hours")
        .select()
        .eq("workshop_id", workshopId)
        .order("weekday");
    return (res as List<dynamic>)
        .map((e) => WorkshopHour.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> favoriteIds() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return {};
    final res = await _client.from("favorites").select("workshop_id").eq("user_id", uid);
    return (res as List<dynamic>).map((e) => e["workshop_id"] as String).toSet();
  }

  Future<List<Workshop>> favoriteWorkshops() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return [];
    final res = await _client
        .from("favorites")
        .select("created_at, workshops(*)")
        .eq("user_id", uid)
        .order("created_at", ascending: false);
    return (res as List<dynamic>)
        .where((e) => e["workshops"] != null)
        .map((e) => Workshop.fromJson(Map<String, dynamic>.from(e["workshops"] as Map)))
        .toList();
  }

  Future<void> setFavorite(String workshopId, bool favorite) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw Exception("Silakan masuk terlebih dahulu");
    if (favorite) {
      await _client.from("favorites").upsert({"user_id": uid, "workshop_id": workshopId});
    } else {
      await _client.from("favorites").delete().eq("user_id", uid).eq("workshop_id", workshopId);
    }
  }
}
