/// Data model Booking, Item, dan Pembayaran.
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse("${v ?? ""}") ?? 0;
DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

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
    this.workshopAddress,
    this.vehicleInfo,
    this.items = const [],
    this.refundIdr,
    this.refundStatus,
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
  final String? workshopAddress;
  final String? vehicleInfo;
  final List<BookingItem> items;
  final int? refundIdr;
  final String? refundStatus;

  /// Kode booking singkat untuk ditunjukkan ke bengkel.
  String get code {
    final hex = id.replaceAll("-", "");
    return "BK-${(hex.length >= 6 ? hex.substring(0, 6) : hex).toUpperCase()}";
  }

  bool get canCancel => const {
        "MENUNGGU_PEMBAYARAN",
        "DIBAYAR_MENUNGGU_KONFIRMASI",
        "DIKONFIRMASI",
      }.contains(status);

  bool get isActive => const {
        "MENUNGGU_PEMBAYARAN",
        "DIBAYAR_MENUNGGU_KONFIRMASI",
        "DIKONFIRMASI",
        "DIKERJAKAN",
        "MENUNGGU_PERSETUJUAN_ADDON",
        "SELESAI_MENUNGGU_KONFIRMASI",
      }.contains(status);

  factory Booking.fromJson(Map<String, dynamic> json) {
    final v = json["vehicles"];
    return Booking(
      id: json["id"] as String,
      riderId: json["rider_id"] as String? ?? "",
      workshopId: json["workshop_id"] as String? ?? "",
      vehicleId: json["vehicle_id"] as String?,
      status: json["status"] as String? ?? "MENUNGGU_PEMBAYARAN",
      scheduledAt: _date(json["scheduled_at"]) ?? DateTime.now(),
      subtotalIdr: _int(json["subtotal_idr"]),
      totalIdr: _int(json["total_idr"]),
      commissionRate: ((json["commission_rate"] ?? 0.08) as num).toDouble(),
      cancelReason: json["cancel_reason"] as String?,
      paymentDeadline: _date(json["payment_deadline"]),
      workshopName: (json["workshops"] as Map?)?["name"] as String?,
      vehicleInfo: v is Map ? "${v["brand"] ?? ""} ${v["model"] ?? ""}".trim() : null,
    );
  }

  /// Dari RPC `booking_detail` (jsonb).
  factory Booking.fromDetail(Map<String, dynamic> json) {
    final w = json["workshop"] as Map?;
    final v = json["vehicle"] as Map?;
    final r = json["refund"] as Map?;
    final items = (json["items"] as List? ?? const [])
        .map((e) => BookingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final base = Booking.fromJson(json);
    return Booking(
      id: base.id,
      riderId: base.riderId,
      workshopId: base.workshopId,
      vehicleId: base.vehicleId,
      status: base.status,
      scheduledAt: base.scheduledAt,
      subtotalIdr: base.subtotalIdr,
      totalIdr: base.totalIdr,
      commissionRate: base.commissionRate,
      cancelReason: base.cancelReason,
      paymentDeadline: base.paymentDeadline,
      workshopName: w?["name"] as String?,
      workshopAddress: w?["address"] as String?,
      vehicleInfo: v == null
          ? null
          : "${v["brand"] ?? ""} ${v["model"] ?? ""} · ${v["plate"] ?? ""}".trim(),
      items: items,
      refundIdr: r == null ? null : _int(r["amount_idr"]),
      refundStatus: r?["status"] as String?,
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
      id: json["id"] as String? ?? "",
      bookingId: json["booking_id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      priceIdr: _int(json["price_idr"]),
      isAddon: json["is_addon"] as bool? ?? false,
      addonApproved: json["addon_approved"] as bool?,
    );
  }
}
