/// Data model Booking, Item, dan Pembayaran.
class Booking {
  const Booking({
    required this.id,
    required this.riderId,
    required this.workshopId,
    this.vehicleId,
    required this.status,
    required this.scheduledAt,
    this.subtotalIdr = 0,
    this.totalIdr = 0,
    this.commissionRate = 0.08,
    this.cancelReason,
    this.paymentDeadline,
    this.workshopName,
    this.vehicleInfo,
    this.items = const [],
  });

  final String id;
  final String riderId;
  final String workshopId;
  final String? vehicleId;
  final String status;
  final DateTime scheduledAt;
  final int subtotalIdr;
  final int totalIdr;
  final double commissionRate;
  final String? cancelReason;
  final DateTime? paymentDeadline;
  final String? workshopName;
  final String? vehicleInfo;
  final List<BookingItem> items;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json["id"] as String,
      riderId: json["rider_id"] as String? ?? "",
      workshopId: json["workshop_id"] as String? ?? "",
      vehicleId: json["vehicle_id"] as String?,
      status: json["status"] as String? ?? "MENUNGGU_PEMBAYARAN",
      scheduledAt: DateTime.parse(json["scheduled_at"] as String),
      subtotalIdr: (json["subtotal_idr"] ?? 0) as int,
      totalIdr: (json["total_idr"] ?? 0) as int,
      commissionRate: ((json["commission_rate"] ?? 0.08) as num).toDouble(),
      cancelReason: json["cancel_reason"] as String?,
      paymentDeadline: json["payment_deadline"] != null
          ? DateTime.parse(json["payment_deadline"] as String)
          : null,
      workshopName: json["workshops"]?["name"] as String?,
      vehicleInfo: json["vehicles"] != null
          ? "${json["vehicles"]["brand"]} ${json["vehicles"]["model"]}"
          : null,
    );
  }
}

class BookingItem {
  const BookingItem({
    required this.id,
    required this.bookingId,
    required this.name,
    required this.priceIdr,
    this.isAddon = false,
    this.addonApproved,
  });

  final String id;
  final String bookingId;
  final String name;
  final int priceIdr;
  final bool isAddon;
  final bool? addonApproved;

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: json["id"] as String,
      bookingId: json["booking_id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      priceIdr: (json["price_idr"] ?? 0) as int,
      isAddon: json["is_addon"] as bool? ?? false,
      addonApproved: json["addon_approved"] as bool?,
    );
  }
}
