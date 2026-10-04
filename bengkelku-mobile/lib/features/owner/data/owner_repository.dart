import "dart:io";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "../../../core/utils/media_guard.dart";

/// Repository untuk operasional Pemilik Bengkel (Owner).
class OwnerRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Pendaftaran workshop baru
  Future<Map<String, dynamic>> registerWorkshop({
    required String name,
    required String address,
    required String phone,
    required double lat,
    required double lng,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw Exception("Belum login");

    final response = await _client
        .from("workshops")
        .insert({
          "owner_id": uid,
          "name": name,
          "address": address,
          "phone": phone,
          "status": "draft",
          "location": "POINT($lng $lat)",
        })
        .select()
        .single();

    return response;
  }

  /// Unggah dokumen verifikasi ke bucket privat `verification-docs` (≤ 2 MB)
  Future<void> uploadVerificationDoc({
    required String workshopId,
    required String docType, // 'ktp' | 'selfie_ktp' | 'location'
    required File file,
  }) async {
    await MediaGuard.ensureFileUnderLimit(file);

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw Exception("Belum login");

    final path =
        "$uid/$workshopId/$docType-${DateTime.now().millisecondsSinceEpoch}.jpg";

    await _client.storage.from("verification-docs").upload(path, file);

    await _client.from("workshop_documents").insert({
      "workshop_id": workshopId,
      "type": docType,
      "storage_path": path,
      "status": "pending",
    });
  }

  /// Ambil status verifikasi workshop owner
  Future<Map<String, dynamic>?> getOwnerWorkshop() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;

    final response = await _client
        .from("workshops")
        .select()
        .eq("owner_id", uid)
        .maybeSingle();

    return response;
  }

  /// Input riwayat servis setelah pengerjaan selesai
  Future<void> createServiceRecord({
    required String bookingId,
    required String vehicleId,
    required String workshopId,
    required int odometerKm,
    required bool oilChanged,
    String? notes,
  }) async {
    await _client.from("service_records").insert({
      "booking_id": bookingId,
      "vehicle_id": vehicleId,
      "workshop_id": workshopId,
      "odometer_km": odometerKm,
      "oil_changed": oilChanged,
      "notes": notes,
    });

    // Update status booking ke SELESAI
    await _client.from("bookings").update({
      "status": "SELESAI",
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    }).eq("id", bookingId);
  }
}
