/// Data model Bengkel, Jam Buka, Layanan, dan Slot.
class Workshop {
  const Workshop({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.phone,
    required this.address,
    this.latitude,
    this.longitude,
    required this.status,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.distanceMeters = 0.0,
    this.photoUrl,
    this.isOpen = true,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final String status;
  final double ratingAvg;
  final int ratingCount;
  final double distanceMeters;
  final String? photoUrl;
  final bool isOpen;

  factory Workshop.fromJson(Map<String, dynamic> json) {
    return Workshop(
      id: json["id"] as String,
      ownerId: json["owner_id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      description: json["description"] as String?,
      phone: json["phone"] as String?,
      address: json["address"] as String? ?? "",
      latitude: ((json["lat"] ?? json["latitude"]) as num?)?.toDouble(),
      longitude: ((json["lng"] ?? json["longitude"]) as num?)?.toDouble(),
      status: json["status"] as String? ?? "verified",
      ratingAvg: ((json["rating_avg"] ?? 0) as num).toDouble(),
      ratingCount: ((json["rating_count"] ?? 0) as num).toInt(),
      distanceMeters: ((json["distance_m"] ?? 0) as num).toDouble(),
      photoUrl: json["photo_url"] as String?,
      isOpen: json["is_open"] as bool? ?? true,
    );
  }
}

class WorkshopServiceItem {
  const WorkshopServiceItem({
    required this.id,
    required this.workshopId,
    required this.name,
    required this.priceIdr,
    required this.durationMinutes,
    this.isActive = true,
  });

  final String id;
  final String workshopId;
  final String name;
  final int priceIdr;
  final int durationMinutes;
  final bool isActive;

  factory WorkshopServiceItem.fromJson(Map<String, dynamic> json) {
    return WorkshopServiceItem(
      id: json["id"] as String,
      workshopId: json["workshop_id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      priceIdr: ((json["price_idr"] ?? 0) as num).toInt(),
      durationMinutes: ((json["duration_minutes"] ?? 60) as num).toInt(),
      isActive: json["is_active"] as bool? ?? true,
    );
  }
}

class WorkshopHour {
  const WorkshopHour({required this.weekday, this.open, this.close, this.isClosed = false});
  final int weekday; // 0 = Minggu
  final String? open;
  final String? close;
  final bool isClosed;

  static const dayNames = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
  String get dayName => dayNames[weekday.clamp(0, 6)];
  String get label {
    if (isClosed || open == null || close == null) return "Tutup";
    String t(String v) => v.length >= 5 ? v.substring(0, 5) : v;
    return "${t(open!)} - ${t(close!)}";
  }

  factory WorkshopHour.fromJson(Map<String, dynamic> j) => WorkshopHour(
        weekday: ((j["weekday"] ?? 0) as num).toInt(),
        open: j["open_time"] as String?,
        close: j["close_time"] as String?,
        isClosed: j["is_closed"] as bool? ?? false,
      );
}
