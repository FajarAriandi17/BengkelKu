/// Data model kendaraan di Garasi pengguna.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.userId,
    required this.brand,
    required this.model,
    this.year,
    this.plate,
    this.odometer = 0,
    this.oilIntervalKm = 4000,
    this.oilIntervalDays = 90,
  });

  final String id;
  final String userId;
  final String brand;
  final String model;
  final int? year;
  final String? plate;
  final int odometer;
  final int oilIntervalKm;
  final int oilIntervalDays;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json["id"] as String,
      userId: json["user_id"] as String? ?? "",
      brand: json["brand"] as String? ?? "",
      model: json["model"] as String? ?? "",
      year: json["year"] as int?,
      plate: json["plate"] as String?,
      odometer: (json["odometer"] ?? 0) as int,
      oilIntervalKm: (json["oil_interval_km"] ?? 4000) as int,
      oilIntervalDays: (json["oil_interval_days"] ?? 90) as int,
    );
  }
}
