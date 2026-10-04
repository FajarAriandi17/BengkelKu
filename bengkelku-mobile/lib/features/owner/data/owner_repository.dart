import "dart:io";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "../../../core/utils/media_guard.dart";

/// Repository untuk operasional Pemilik Bengkel (Owner).
class OwnerRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Daftar / perbarui data bengkel (status draft) lewat RPC
  /// `workshop_register` (0021). Lokasi wajib GPS asli di Indonesia.
  Future<String> registerWorkshop({
    required String name,
    required String address,
    required String phone,
    required double lat,
    required double lng,
    String? description,
  }) async {
    final res = await _client.rpc("workshop_register", params: {
      "p_name": name,
      "p_address": address,
      "p_phone": phone,
      "p_lat": lat,
      "p_lng": lng,
      "p_description": description,
    });
    return (res as Map)["id"] as String;
  }

  /// Kirim ke antrean verifikasi admin (draft/rejected → pending).
  Future<void> submitForVerification(String workshopId) async {
    await _client.rpc(
      "workshop_submit_verification",
      params: {"p_workshop_id": workshopId},
    );
  }

  /// Status verifikasi + kelengkapan dokumen (null bila belum mendaftar).
  Future<Map<String, dynamic>?> getMyVerificationStatus() async {
    final res = await _client.rpc("workshop_my_status");
    if (res == null) return null;
    return (res as Map).cast<String, dynamic>();
  }

  /// Unggah dokumen verifikasi ke bucket privat `verification-docs` (≤ 2 MB)
  Future<void> uploadVerificationDoc({
    required String workshopId,
    required String docType, // 'ktp' | 'selfie' | 'location' (enum doc_type)
    required File file,
  }) async {
    await MediaGuard.ensureFileUnderLimit(file);

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw Exception("Belum login");

    final path =
        "$uid/$workshopId/$docType-${DateTime.now().millisecondsSinceEpoch}.jpg";

    await _client.storage.from("verification-docs").upload(
          path,
          file,
          fileOptions: const FileOptions(contentType: "image/jpeg"),
        );

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

    // Status booking → SELESAI lewat RPC (transisi divalidasi server, 0022).
    await bookingAction(bookingId, "complete");
  }

  /// Aksi booking bengkel: confirm | reject | check_in | start | complete | no_show.
  Future<void> bookingAction(String bookingId, String action,
      {String? reason}) async {
    await _client.rpc("owner_booking_action", params: {
      "p_booking_id": bookingId,
      "p_action": action,
      "p_reason": reason,
    });
  }

  /// Ringkasan dasbor bengkel (pendapatan hari ini, antrean). null bila
  /// belum punya bengkel.
  Future<Map<String, dynamic>?> getDashboard() async {
    final res = await _client.rpc("owner_dashboard");
    if (res == null) return null;
    return (res as Map).cast<String, dynamic>();
  }
}
