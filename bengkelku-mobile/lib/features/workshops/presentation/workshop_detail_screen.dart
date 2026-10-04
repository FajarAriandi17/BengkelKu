import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_chip.dart";
import "../../../design/components/favorite_button.dart";
import "../../../design/components/rating_stars.dart";
import "../../../design/components/service_row.dart";
import "../../../design/components/state_views.dart";
import "../data/workshop_model.dart";
import "../data/workshop_repository.dart";

class WorkshopDetailScreen extends StatefulWidget {
  const WorkshopDetailScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  final _repo = WorkshopRepository();
  Workshop? _workshop;
  List<WorkshopServiceItem> _services = [];
  List<WorkshopHour> _hours = [];
  final Set<String> _selected = {};
  bool _loading = true;
  String? _error;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ws = await _repo.getWorkshopDetail(widget.workshopId);
      final sv = await _repo.getWorkshopServices(widget.workshopId);
      List<WorkshopHour> hours = [];
      Set<String> favs = {};
      try {
        hours = await _repo.getWorkshopHours(widget.workshopId);
        favs = await _repo.favoriteIds();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _workshop = ws;
        _services = sv;
        _hours = hours;
        _isFavorite = favs.contains(widget.workshopId);
        _loading = false;
        if (ws == null)
          _error = "Bengkel tidak ditemukan atau belum terverifikasi.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Gagal memuat bengkel. Periksa koneksi internet.";
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(bool fav) async {
    setState(() => _isFavorite = fav);
    try {
      await _repo.setFavorite(widget.workshopId, fav);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFavorite = !fav);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<void> _call(String phone) async {
    final uri =
        Uri(scheme: "tel", path: phone.replaceAll(RegExp(r"[^0-9+]"), ""));
    await launchUrl(uri);
  }

  Future<void> _directions(Workshop w) async {
    final uri = (w.latitude != null && w.longitude != null)
        ? Uri.parse(
            "https://www.google.com/maps/dir/?api=1&destination=${w.latitude},${w.longitude}",
          )
        : Uri.parse(
            "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(w.address)}",
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  int get _total => _services
      .where((s) => _selected.contains(s.id))
      .fold(0, (a, s) => a + s.priceIdr);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = _workshop;

    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const SkeletonList(itemCount: 5));
    }
    if (_error != null || w == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(
            message: _error ?? "Bengkel tidak ditemukan", onRetry: _load),
      );
    }

    final todayIdx = DateTime.now().weekday % 7; // Minggu = 0
    WorkshopHour? today;
    for (final h in _hours) {
      if (h.weekday == todayIdx) today = h;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(w.name, overflow: TextOverflow.ellipsis),
        elevation: 0,
        actions: [
          FavoriteButton(isFavorite: _isFavorite, onToggle: _toggleFavorite),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 180,
                color: c.blueSoft,
                child: w.photoUrl != null && w.photoUrl!.isNotEmpty
                    ? Image.network(
                        w.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.storefront, size: 64, color: c.blue),
                      )
                    : Icon(Icons.storefront, size: 64, color: c.blue),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: Text(w.name,
                        style: AppTypography.h1.copyWith(color: c.ink))),
                AppStatusBadge(
                  label: w.isOpen ? "Buka" : "Tutup",
                  color: w.isOpen ? c.ok : c.bad,
                  backgroundColor: w.isOpen ? c.okSoft : c.badSoft,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(w.address, style: AppTypography.body.copyWith(color: c.ink2)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => context.push("/reviews?workshopId=${w.id}"),
              child: Row(
                children: [
                  RatingStars(rating: w.ratingAvg, starSize: 18),
                  const SizedBox(width: 6),
                  Text(
                    w.ratingCount == 0
                        ? "Belum ada ulasan"
                        : "${w.ratingAvg.toStringAsFixed(1)} (${w.ratingCount} ulasan)",
                    style: AppTypography.label.copyWith(color: c.ink),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: c.ink2),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (w.phone != null && w.phone!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(w.phone!),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text("Telepon"),
                    ),
                  ),
                if (w.phone != null && w.phone!.isNotEmpty)
                  const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _directions(w),
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: const Text("Rute"),
                  ),
                ),
              ],
            ),
            if (w.description != null && w.description!.trim().isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                "Tentang Bengkel",
                style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(w.description!,
                  style: AppTypography.body.copyWith(color: c.ink2)),
            ],
            const Divider(height: 32),
            Text(
              "Jam Operasional",
              style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (_hours.isEmpty)
              Text(
                "Jam operasional belum diatur bengkel.",
                style: AppTypography.body.copyWith(color: c.ink2),
              )
            else
              ..._hours.map(
                (h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          h.dayName,
                          style: (h == today
                                  ? AppTypography.bodyStrong
                                  : AppTypography.body)
                              .copyWith(color: c.ink),
                        ),
                      ),
                      Text(
                        h.label,
                        style: (h == today
                                ? AppTypography.bodyStrong
                                : AppTypography.body)
                            .copyWith(color: h.isClosed ? c.bad : c.ink2),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 32),
            Text(
              "Pilih Layanan Servis",
              style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_services.isEmpty)
              Text(
                "Bengkel ini belum menambahkan layanan yang bisa dipesan online.",
                style: AppTypography.body.copyWith(color: c.ink2),
              )
            else
              ..._services.map(
                (s) => ServiceRow(
                  name: s.name,
                  priceIdr: s.priceIdr,
                  durationMinutes: s.durationMinutes,
                  isSelected: _selected.contains(s.id),
                  onTap: () => setState(() {
                    if (!_selected.remove(s.id)) _selected.add(s.id);
                  }),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: _selected.isEmpty
              ? "Pilih layanan dulu"
              : "Lanjut Pilih Jadwal · ${Formatters.rupiah(_total)}",
          onPressed: _selected.isEmpty
              ? null
              : () => context.push(
                    "/schedule?workshopId=${widget.workshopId}&services=${_selected.join(",")}",
                  ),
        ),
      ),
    );
  }
}
