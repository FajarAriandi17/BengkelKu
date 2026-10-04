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
      latitude: (json["lat"] ?? json["latitude"]) as double?,
      longitude: (json["lng"] ?? json["longitude"]) as double?,
      status: json["status"] as String? ?? "verified",
      ratingAvg: ((json["rating_avg"] ?? 0) as num).toDouble(),
      ratingCount: (json["rating_count"] ?? 0) as int,
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
      priceIdr: (json["price_idr"] ?? 0) as int,
      durationMinutes: (json["duration_minutes"] ?? 60) as int,
      isActive: json["is_active"] as bool? ?? true,
    );
  }
}
