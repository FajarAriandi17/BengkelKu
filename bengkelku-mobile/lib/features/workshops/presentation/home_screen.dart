import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_shell.dart";
import "../../../design/components/state_views.dart";
import "../../auth/presentation/auth_provider.dart";
import "../../garage/data/garage_repository.dart";
import "../../garage/data/vehicle_model.dart";
import "../data/workshop_model.dart";
import "../data/workshop_repository.dart";

/// Beranda Pengendara — tata letak mengikuti prototype "Desain aplikasi":
/// lokasi + notifikasi, sapaan, pencarian, kartu oli motor utama, pintasan
/// layanan, kartu darurat, dan carousel bengkel terdekat.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _workshopRepo = WorkshopRepository();
  final _garageRepo = GarageRepository();
  List<Workshop> _nearby = [];
  Vehicle? _vehicle;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Lat & lng default Jakarta Selatan sampai izin lokasi diberikan.
      final list =
          await _workshopRepo.getNearbyWorkshops(lat: -6.2615, lng: 106.8106);
      Vehicle? v;
      try {
        final vs = await _garageRepo.getUserVehicles();
        v = vs.isEmpty ? null : vs.first;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _nearby = list;
        _vehicle = v;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Gagal memuat bengkel terdekat. Periksa koneksi internet.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final fullName = (profile?["full_name"] as String?)?.trim() ?? "";
    final first = fullName.isEmpty ? "" : fullName.split(" ").first;

    return Scaffold(
      backgroundColor: c.panel2,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push("/location"),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Lokasi saat ini",
                            style:
                                AppTypography.caption.copyWith(color: c.ink2),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: c.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Jakarta Selatan",
                                style: AppTypography.label
                                    .copyWith(color: c.ink, fontSize: 15),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: c.blue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SquareIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: "Notifikasi",
                    onTap: () => context.push("/notifications"),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                first.isEmpty ? "Halo!" : "Halo, $first",
                style: AppTypography.display.copyWith(color: c.ink),
              ),
              const SizedBox(height: 2),
              Text(
                "Motormu butuh perhatian hari ini?",
                style: AppTypography.body.copyWith(color: c.ink2),
              ),
              const SizedBox(height: 16),
              Material(
                color: c.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(color: c.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => context.push("/home/nearby"),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: c.ink2),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Cari bengkel atau layanan",
                            style: AppTypography.body.copyWith(color: c.ink2),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _OilHeroCard(vehicle: _vehicle),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Shortcut(
                    icon: Icons.water_drop_outlined,
                    label: "Ganti oli",
                    onTap: () => context.push("/home/nearby"),
                  ),
                  _Shortcut(
                    icon: Icons.build_outlined,
                    label: "Servis",
                    onTap: () => context.push("/home/nearby"),
                  ),
                  _Shortcut(
                    icon: Icons.shield_outlined,
                    label: "Rem",
                    onTap: () => context.push("/home/nearby"),
                  ),
                  _Shortcut(
                    icon: Icons.sos_rounded,
                    label: "Darurat",
                    danger: true,
                    onTap: () => context.push("/sos"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                onTap: () => context.push("/sos"),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    IconTile(
                      icon: Icons.car_crash_outlined,
                      size: 44,
                      color: c.bad,
                      background: c.badSoft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Motor mogok?",
                            style: AppTypography.label
                                .copyWith(color: c.ink, fontSize: 15),
                          ),
                          Text(
                            "Panggil mekanik terdekat ke lokasimu",
                            style:
                                AppTypography.caption.copyWith(color: c.ink2),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.ink2),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Bengkel terdekat",
                      style: AppTypography.h2.copyWith(color: c.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push("/home/nearby"),
                    child: Text(
                      "Lihat semua",
                      style: AppTypography.label.copyWith(color: c.blueText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const SizedBox(height: 220, child: SkeletonList(itemCount: 1))
              else if (_error != null)
                ErrorState(message: _error!, onRetry: _loadData)
              else if (_nearby.isEmpty)
                const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: "belum ada bengkel di sekitarmu",
                  message: "coba perluas area atau cek lagi nanti.",
                )
              else
                SizedBox(
                  height: 236,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: _nearby.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _NearbyCard(
                      workshop: _nearby[i],
                      seed: i,
                      onTap: () =>
                          context.push("/home/workshop/${_nearby[i].id}"),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.home),
    );
  }
}

/// Kartu biru gradien: motor utama + status oli + tombol booking ganti oli.
class _OilHeroCard extends StatelessWidget {
  const _OilHeroCard({required this.vehicle});
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = vehicle;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B5BF0), Color(0xFF1F4FD8), Color(0xFF1A3FB0)],
        ),
        boxShadow: [
          BoxShadow(
            color: c.blue.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: v == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Tambahkan motormu",
                        style: AppTypography.h1.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Kami ingatkan saat oli perlu diganti — berdasarkan km dan waktu.",
                        style: AppTypography.caption
                            .copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 14),
                      _WhiteButton(
                        icon: Icons.add,
                        label: "Tambah motor",
                        onTap: () => context.go("/garage"),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.model.isEmpty ? v.brand : v.model,
                              style: AppTypography.h1
                                  .copyWith(color: Colors.white),
                            ),
                            Text(
                              "${v.plate ?? "-"} · ${Formatters.odometer(v.odometer)}",
                              style: AppTypography.caption
                                  .copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            const StatusPill(
                              label: "Oli: pantau",
                              icon: Icons.circle,
                              color: Colors.white,
                              background: Color(0x33FFFFFF),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Ganti tiap ±${Formatters.odometer(v.oilIntervalKm)} atau ${v.oilIntervalDays} hari",
                              style: AppTypography.caption
                                  .copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 14),
                            _WhiteButton(
                              icon: Icons.water_drop_outlined,
                              label: "Booking ganti oli",
                              onTap: () => context.push("/home/nearby"),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            context.push("/oil-detail?vehicleId=${v.id}"),
                        child: MiniOilGauge(
                          progress: 0.35,
                          color: const Color(0xFFFBBF24),
                          size: 104,
                          trackColor: Colors.white.withValues(alpha: 0.22),
                          iconColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c.blue),
              const SizedBox(width: 6),
              Text(label, style: AppTypography.label.copyWith(color: c.blue)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: danger ? c.badSoft : c.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: danger ? c.badSoft : c.line),
              ),
              child: Icon(icon, color: danger ? c.bad : c.blueText),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.workshop,
    required this.seed,
    required this.onTap,
  });
  final Workshop workshop;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = workshop;
    return SizedBox(
      width: 208,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              width: double.infinity,
              child: WorkshopIllustration(seed: seed, photoUrl: w.photoUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label
                        .copyWith(color: c.ink, fontSize: 15),
                  ),
                  Text(
                    w.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: c.star),
                      const SizedBox(width: 2),
                      Text(
                        w.ratingAvg.toStringAsFixed(1),
                        style: AppTypography.label.copyWith(color: c.ink),
                      ),
                      Text(
                        " · ${Formatters.distance(w.distanceMeters)}",
                        style: AppTypography.caption.copyWith(color: c.ink2),
                      ),
                      const Spacer(),
                      Text(
                        w.isOpen ? "Buka" : "Tutup",
                        style: AppTypography.caption.copyWith(
                          color: w.isOpen ? c.ok : c.bad,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
