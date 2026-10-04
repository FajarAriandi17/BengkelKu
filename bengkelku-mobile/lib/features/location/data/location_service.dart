import "package:geolocator/geolocator.dart";

/// Service penanganan lokasi & koordinat GPS.
class LocationService {
  /// Minta izin lokasi & ambil posisi saat ini.
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Daftar kota default sebagai fallback bila izin lokasi ditolak.
  static const List<Map<String, dynamic>> fallbackCities = [
    {"name": "Jakarta Selatan", "lat": -6.2615, "lng": 106.8106},
    {"name": "Bandung", "lat": -6.9175, "lng": 107.6191},
    {"name": "Surabaya", "lat": -7.2575, "lng": 112.7521},
    {"name": "Yogyakarta", "lat": -7.7956, "lng": 110.3695},
    {"name": "Medan", "lat": 3.5952, "lng": 98.6722},
    {"name": "Makassar", "lat": -5.1477, "lng": 119.4327},
  ];
}
