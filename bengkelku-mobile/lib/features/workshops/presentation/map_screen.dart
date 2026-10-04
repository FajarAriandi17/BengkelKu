import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:go_router/go_router.dart";

import "../../../design/components/workshop_card.dart";

/// Peta interaktif Google Maps dengan pin bengkel.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(-6.2615, 106.8106), // Jakarta Selatan
    zoom: 14.0,
  );

  String? _selectedWorkshopId = "ws-1";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Peta Bengkel Terdekat"),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId("ws-1"),
                position: const LatLng(-6.2615, 106.8106),
                infoWindow: const InfoWindow(title: "Bengkel Jaya Motor"),
                onTap: () => setState(() => _selectedWorkshopId = "ws-1"),
              ),
              Marker(
                markerId: const MarkerId("ws-2"),
                position: const LatLng(-6.2580, 106.8150),
                infoWindow: const InfoWindow(title: "Honda AHASS Sentosa"),
                onTap: () => setState(() => _selectedWorkshopId = "ws-2"),
              ),
            },
          ),
          if (_selectedWorkshopId != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: WorkshopCard(
                id: _selectedWorkshopId!,
                name: _selectedWorkshopId == "ws-1"
                    ? "Bengkel Jaya Motor"
                    : "Honda AHASS Sentosa",
                address: "Jl. Fatmawati No. 12, Jakarta Selatan",
                ratingAvg: 4.8,
                ratingCount: 120,
                distanceMeters: 850,
                onTap: () =>
                    context.push("/home/workshop/$_selectedWorkshopId"),
              ),
            ),
        ],
      ),
    );
  }
}
