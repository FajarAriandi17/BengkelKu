import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../data/location_service.dart";

/// Layar izin lokasi & fallback kota manual.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _loading = false;

  Future<void> _requestLocation() async {
    setState(() => _loading = true);
    final pos = await LocationService.getCurrentPosition();
    setState(() => _loading = false);

    if (pos != null && mounted) {
      context.go("/home");
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("kami butuh lokasi untuk menampilkan bengkel terdekat. kamu juga bisa cari lewat nama kota."),
        ),
      );
    }
  }

  void _selectCity(Map<String, dynamic> city) {
    context.go("/home");
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.location_on, size: 80, color: c.blue),
              const SizedBox(height: 24),
              Text(
                "Temukan Bengkel Terdekat",
                style: AppTypography.display.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Aktifkan lokasi GPS kamu agar BengkelKu dapat menampilkan bengkel terdekat di sekitar kamu secara otomatis.",
                style: AppTypography.body.copyWith(color: c.ink.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              AppButton(
                label: "Aktifkan Lokasi GPS",
                onPressed: _requestLocation,
                loading: _loading,
                icon: Icons.my_location,
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Pilih Kota Manual", style: AppTypography.h2.copyWith(color: c.ink)),
                          const SizedBox(height: 16),
                          ...LocationService.fallbackCities.map(
                            (city) => ListTile(
                              title: Text(city["name"] as String, style: AppTypography.bodyStrong),
                              onTap: () {
                                Navigator.pop(ctx);
                                _selectCity(city);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Text(
                  "Pilih Kota Secara Manual",
                  style: AppTypography.label.copyWith(color: c.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
