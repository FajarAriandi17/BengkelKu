import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "vehicle_model.dart";

/// Repository untuk kelola kendaraan di Garasi pengguna.
class GarageRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Ambil daftar kendaraan pengguna saat ini
  Future<List<Vehicle>> getUserVehicles() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return [];

    final response = await _client
        .from("vehicles")
        .select()
        .eq("user_id", uid)
        .order("created_at", ascending: false);

    return (response as List<dynamic>)
        .map((v) => Vehicle.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Tambah kendaraan baru
  Future<Vehicle> addVehicle({
    required String brand,
    required String model,
    int? year,
    String? plate,
    int odometer = 0,
    int oilIntervalKm = 4000,
    int oilIntervalDays = 90,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw Exception("Belum login");

    final response = await _client.from("vehicles").insert({
      "user_id": uid,
      "brand": brand,
      "model": model,
      "year": year,
      "plate": plate,
      "odometer": odometer,
      "oil_interval_km": oilIntervalKm,
      "oil_interval_days": oilIntervalDays,
    }).select().single();

    return Vehicle.fromJson(response);
  }

  /// Hapus kendaraan
  Future<void> deleteVehicle(String vehicleId) async {
    await _client.from("vehicles").delete().eq("id", vehicleId);
  }
}
