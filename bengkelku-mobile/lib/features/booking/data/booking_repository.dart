import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "booking_model.dart";

class BookingSlot {
  const BookingSlot({required this.at, required this.label, required this.remaining});
  final DateTime at;
  final String label;
  final int remaining;
  bool get available => remaining > 0;

  factory BookingSlot.fromJson(Map<String, dynamic> j) => BookingSlot(
        at: DateTime.parse(j["slot_at"] as String).toUtc(),
        label: j["label"] as String? ?? "",
        remaining: (j["remaining"] as num?)?.toInt() ?? 0,
      );
}

class CancelResult {
  const CancelResult({required this.refundPct, required this.refundIdr});
  final int refundPct;
  final int refundIdr;
}

/// Pesan error ramah pengguna dari exception Supabase/RPC.
String bookingErrorMessage(Object e) {
  if (e is PostgrestException) return e.message;
  final s = e.toString();
  return s.startsWith("Exception: ") ? s.substring(11) : s;
}

/// Repository booking. Semua penulisan lewat RPC server (harga & status
/// dihitung di server, klien tidak bisa memanipulasi).
class BookingRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<BookingSlot>> availableSlots(String workshopId, DateTime date) async {
    final d = "${date.year.toString().padLeft(4, "0")}-"
        "${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
    final res = await _client.rpc("booking_available_slots",
        params: {"p_workshop_id": workshopId, "p_date": d});
    return (res as List)
        .map((e) => BookingSlot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Booking> createBooking({
    required String workshopId,
    String? vehicleId,
    required List<String> serviceIds,
    required DateTime scheduledAt,
    String? note,
  }) async {
    final res = await _client.rpc("booking_create", params: {
      "p_workshop_id": workshopId,
      "p_vehicle_id": vehicleId,
      "p_service_ids": serviceIds,
      "p_scheduled_at": scheduledAt.toUtc().toIso8601String(),
      "p_note": note,
    });
    return Booking.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Booking> getBooking(String id) async {
    final res = await _client.rpc("booking_detail", params: {"p_booking_id": id});
    if (res == null) throw Exception("Booking tidak ditemukan");
    return Booking.fromDetail(Map<String, dynamic>.from(res as Map));
  }

  Future<void> sandboxPay(String id, String method) async {
    await _client.rpc("booking_sandbox_pay",
        params: {"p_booking_id": id, "p_method": method});
  }

  Future<bool> isSandboxPayments() async {
    try {
      final row = await _client
          .from("app_config")
          .select("value")
          .eq("key", "payments_sandbox")
          .maybeSingle();
      return row?["value"] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Booking>> getRiderBookings() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return [];
    final response = await _client
        .from("bookings")
        .select("*, workshops(name), vehicles(brand, model)")
        .eq("rider_id", uid)
        .order("created_at", ascending: false);
    return (response as List<dynamic>)
        .map((b) => Booking.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<CancelResult> cancelBooking(String bookingId, String reason) async {
    final res = await _client.rpc("booking_cancel",
        params: {"p_booking_id": bookingId, "p_reason": reason});
    final m = Map<String, dynamic>.from(res as Map);
    return CancelResult(
      refundPct: (m["refund_pct"] as num?)?.toInt() ?? 0,
      refundIdr: (m["refund_idr"] as num?)?.toInt() ?? 0,
    );
  }
}
