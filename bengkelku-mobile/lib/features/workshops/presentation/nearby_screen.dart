import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../design/components/workshop_card.dart";
import "../data/workshop_model.dart";
import "../data/workshop_repository.dart";

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _workshopRepo = WorkshopRepository();
  List<Workshop> _workshops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res =
        await _workshopRepo.getNearbyWorkshops(lat: -6.2615, lng: 106.8106);
    if (mounted) {
      setState(() {
        _workshops = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daftar Bengkel Terdekat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push("/home/map"),
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Cari berdasarkan nama/layanan...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: c.panel,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.blueSoft),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.tune, color: c.blue),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _workshops.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          WorkshopCard(
                            id: "ws-1",
                            name: "Bengkel Jaya Motor",
                            address: "Jl. Fatmawati No. 12, Jakarta Selatan",
                            ratingAvg: 4.8,
                            ratingCount: 120,
                            distanceMeters: 850,
                            onTap: () => context.push("/home/workshop/ws-1"),
                          ),
                          WorkshopCard(
                            id: "ws-2",
                            name: "Honda AHASS Sentosa",
                            address: "Jl. Radio Dalam No. 45, Jakarta Selatan",
                            ratingAvg: 4.9,
                            ratingCount: 340,
                            distanceMeters: 1400,
                            onTap: () => context.push("/home/workshop/ws-2"),
                          ),
                          WorkshopCard(
                            id: "ws-3",
                            name: "Bengkel Motor Berkah",
                            address:
                                "Jl. Panglima Polim No. 88, Jakarta Selatan",
                            ratingAvg: 4.6,
                            ratingCount: 85,
                            distanceMeters: 2100,
                            onTap: () => context.push("/home/workshop/ws-3"),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _workshops.length,
                        itemBuilder: (context, index) {
                          final ws = _workshops[index];
                          return WorkshopCard(
                            id: ws.id,
                            name: ws.name,
                            address: ws.address,
                            ratingAvg: ws.ratingAvg,
                            ratingCount: ws.ratingCount,
                            distanceMeters: ws.distanceMeters,
                            photoUrl: ws.photoUrl,
                            isOpen: ws.isOpen,
                            onTap: () =>
                                context.push("/home/workshop/${ws.id}"),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
