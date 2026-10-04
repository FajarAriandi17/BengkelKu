import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "booking_model.dart";

/// Repository untuk transaksi booking, pembayaran, dan pembatalan.
class BookingRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Buat pesanan booking baru
  Future<Booking> createBooking({
    required String workshopId,
    required String vehicleId,
    required DateTime scheduledAt,
    required List<Map<String, dynamic>> items,
    required int subtotalIdr,
    required int totalIdr,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) throw Exception("Belum login");

    final deadline = DateTime.now().toUtc().add(const Duration(minutes: 60));

    final bookingRes = await _client
        .from("bookings")
        .insert({
          "rider_id": uid,
          "workshop_id": workshopId,
          "vehicle_id": vehicleId,
          "status": "MENUNGGU_PEMBAYARAN",
          "scheduled_at": scheduledAt.toUtc().toIso8601String(),
          "subtotal_idr": subtotalIdr,
          "total_idr": totalIdr,
          "payment_deadline": deadline.toIso8601String(),
        })
        .select()
        .single();

    final bookingId = bookingRes["id"] as String;

    // Insert items
    for (final item in items) {
      await _client.from("booking_items").insert({
        "booking_id": bookingId,
        "name": item["name"],
        "price_idr": item["price_idr"],
        "is_addon": false,
      });
    }

    return Booking.fromJson(bookingRes);
  }

  /// Ambil daftar booking pengendara
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

  /// Batalkan booking
  Future<void> cancelBooking(String bookingId, String reason) async {
    await _client.from("bookings").update({
      "status": "DIBATALKAN",
      "cancel_reason": reason,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    }).eq("id", bookingId);
  }
}
