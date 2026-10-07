import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "booking_model.dart";

/// Intent pembayaran Mayar yang aktif untuk sebuah booking.
class PaymentIntent {
  const PaymentIntent({
    required this.providerRef,
    required this.amountIdr,
    required this.method,
    this.invoiceUrl,
    this.gatewayTxnId,
    this.expiresAt,
  });

  final String providerRef;
  final int amountIdr;
  final String? method;
  final String? invoiceUrl;
  final String? gatewayTxnId;
  final DateTime? expiresAt;

  factory PaymentIntent.fromJson(Map<String, dynamic> j) => PaymentIntent(
        providerRef: j["provider_ref"] as String? ?? "",
        amountIdr: (j["amount_idr"] as num?)?.toInt() ?? 0,
        method: j["method"] as String?,
        invoiceUrl: j["invoice_url"] as String?,
        gatewayTxnId: j["gateway_txn_id"] as String?,
        expiresAt: j["expires_at"] is String
            ? DateTime.tryParse(j["expires_at"] as String)?.toLocal()
            : null,
      );
}

class BookingSlot {
  const BookingSlot({
    required this.at,
    required this.label,
    required this.remaining,
  });
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
  // Edge Function mengembalikan {"error": "..."} saat gateway menolak;
  // functions.invoke melempar FunctionException (details = body respons).
  if (e is FunctionException) {
    final details = e.details;
    if (details is Map && details["error"] is String) {
      return details["error"] as String;
    }
  }
  final s = e.toString();
  return s.startsWith("Exception: ") ? s.substring(11) : s;
}

/// Repository booking. Semua penulisan lewat RPC server (harga & status
/// dihitung di server, klien tidak bisa memanipulasi).
class BookingRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<BookingSlot>> availableSlots(
    String workshopId,
    DateTime date,
  ) async {
    final d = "${date.year.toString().padLeft(4, "0")}-"
        "${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
    final res = await _client.rpc(
      "booking_available_slots",
      params: {"p_workshop_id": workshopId, "p_date": d},
    );
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
    final res = await _client.rpc(
      "booking_create",
      params: {
        "p_workshop_id": workshopId,
        "p_vehicle_id": vehicleId,
        "p_service_ids": serviceIds,
        "p_scheduled_at": scheduledAt.toUtc().toIso8601String(),
        "p_note": note,
      },
    );
    return Booking.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Booking> getBooking(String id) async {
    final res =
        await _client.rpc("booking_detail", params: {"p_booking_id": id});
    if (res == null) throw Exception("Booking tidak ditemukan");
    return Booking.fromDetail(Map<String, dynamic>.from(res as Map));
  }

  Future<void> sandboxPay(String id) async {
    await _client.rpc(
      "booking_sandbox_pay",
      params: {"p_booking_id": id},
    );
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

  /// Apakah gateway produksi (Mayar) sudah diaktifkan admin. Klien memakai ini
  /// untuk memilih antara alur sandbox dan alur Mayar yang sebenarnya.
  Future<bool> isMayarEnabled() async {
    try {
      final row = await _client
          .from("app_config")
          .select("value")
          .eq("key", "mayar_enabled")
          .maybeSingle();
      return row?["value"] == true;
    } catch (_) {
      return false;
    }
  }

  /// Membuat invoice Mayar lewat Edge Function `mayar-pay`. JWT pengendara
  /// dikirim otomatis oleh functions.invoke; nominal & validasi dihitung server.
  /// Idempoten: memanggil dua kali mengembalikan invoice yang sama.
  Future<PaymentIntent> createPayment(String bookingId) async {
    final res = await _client.functions.invoke(
      "mayar-pay",
      body: {"booking_id": bookingId},
    );
    final data = res.data;
    if (data is! Map) {
      throw Exception("Respons pembayaran tidak valid");
    }
    final j = Map<String, dynamic>.from(data);
    if (j["error"] is String) {
      throw Exception(j["error"] as String);
    }
    return PaymentIntent.fromJson(j);
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
    final res = await _client.rpc(
      "booking_cancel",
      params: {"p_booking_id": bookingId, "p_reason": reason},
    );
    final m = Map<String, dynamic>.from(res as Map);
    return CancelResult(
      refundPct: (m["refund_pct"] as num?)?.toInt() ?? 0,
      refundIdr: (m["refund_idr"] as num?)?.toInt() ?? 0,
    );
  }
}
