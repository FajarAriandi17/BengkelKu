import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_chip.dart";
import "../../../design/components/sos_components.dart";
import "../../../design/components/workshop_card.dart";
import "../../chat/presentation/chat_provider.dart";
import "../data/workshop_model.dart";
import "../data/workshop_repository.dart";

/// Beranda Pengendara (Rider Home)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _workshopRepo = WorkshopRepository();
  List<Workshop> _nearbyWorkshops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    // Lat & lng default Jakarta Selatan
    final list =
        await _workshopRepo.getNearbyWorkshops(lat: -6.2615, lng: 106.8106);
    if (mounted) {
      setState(() {
        _nearbyWorkshops = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Lokasi Kamu",
                style: AppTypography.caption
                    .copyWith(color: c.ink.withValues(alpha: 0.6))),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: c.blue),
                const SizedBox(width: 4),
                Text("Jakarta Selatan",
                    style: AppTypography.label.copyWith(color: c.ink)),
                Icon(Icons.keyboard_arrow_down, size: 18, color: c.ink),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: c.ink),
            onPressed: () => context.push("/notifications"),
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Pengingat Oli Ringkas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.blueSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.opacity,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Pengingat Oli Motor",
                            style: AppTypography.label.copyWith(color: c.ink)),
                        Text(
                            "oli motor kamu sudah dekat waktunya ganti. yuk booking sekarang.",
                            style: AppTypography.caption
                                .copyWith(color: c.ink.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.go("/garage"),
                    child: Text("Cek Oli",
                        style: AppTypography.label.copyWith(color: c.blue)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tombol darurat (PRD v1.3 3.9: sosEntry)
            Align(
              alignment: Alignment.centerLeft,
              child: SosButton(onTap: () => context.push("/sos")),
            ),
            const SizedBox(height: 20),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: "Cari bengkel atau layanan servis...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: c.panel,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.blueSoft),
                ),
              ),
              onTap: () => context.push("/home/nearby"),
            ),
            const SizedBox(height: 16),

            // Chips Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppFilterChip(
                      label: "Terdekat", selected: true, onSelected: (_) {}),
                  const SizedBox(width: 8),
                  AppFilterChip(
                      label: "Rating Tinggi",
                      selected: false,
                      onSelected: (_) {}),
                  const SizedBox(width: 8),
                  AppFilterChip(
                      label: "Buka Sekarang",
                      selected: false,
                      onSelected: (_) {}),
                  const SizedBox(width: 8),
                  AppFilterChip(
                      label: "Lihat Peta",
                      selected: false,
                      icon: Icons.map,
                      onSelected: (_) => context.push("/home/map")),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section Bengkel Terdekat
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Bengkel Terdekat",
                    style: AppTypography.h2.copyWith(color: c.ink)),
                TextButton(
                  onPressed: () => context.push("/home/nearby"),
                  child: Text("Lihat Semua",
                      style: AppTypography.label.copyWith(color: c.blue)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_nearbyWorkshops.isEmpty)
              // Mock fallback jika DB belum di-seed
              Column(
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
                ],
              )
            else
              ..._nearbyWorkshops.map(
                (ws) => WorkshopCard(
                  id: ws.id,
                  name: ws.name,
                  address: ws.address,
                  ratingAvg: ws.ratingAvg,
                  ratingCount: ws.ratingCount,
                  distanceMeters: ws.distanceMeters,
                  photoUrl: ws.photoUrl,
                  isOpen: ws.isOpen,
                  onTap: () => context.push("/home/workshop/${ws.id}"),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: c.blue,
        unselectedItemColor: c.ink.withValues(alpha: 0.5),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              break;
            case 1:
              context.go("/chat");
              break;
            case 2:
              context.go("/garage");
              break;
            case 3:
              context.go("/bookings");
              break;
            case 4:
              context.go("/favorites");
              break;
            case 5:
              context.go("/profile");
              break;
          }
        },
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Beranda"),
          BottomNavigationBarItem(
            icon: Consumer(
              builder: (context, ref, _) => _ChatIcon(
                icon: Icons.chat_bubble_outline,
                count: ref.watch(chatUnreadCountProvider),
              ),
            ),
            activeIcon: Consumer(
              builder: (context, ref, _) => _ChatIcon(
                icon: Icons.chat_bubble,
                count: ref.watch(chatUnreadCountProvider),
              ),
            ),
            label: "Chat",
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.two_wheeler_outlined),
              activeIcon: Icon(Icons.two_wheeler),
              label: "Garasi"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number_outlined),
              activeIcon: Icon(Icons.confirmation_number),
              label: "Booking"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: "Favorit"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profil"),
        ],
      ),
    );
  }
}

/// Ikon Chat dengan lencana jumlah pesan belum dibaca (v1.3).
class _ChatIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _ChatIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -8,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: context.colors.heart,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              count > 9 ? "9+" : "$count",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
