import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_shell.dart";
import "../../../design/components/favorite_button.dart";
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
  WorkshopOpenStatus? _status;
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
      WorkshopOpenStatus? status;
      try {
        status = await _repo.getOpenStatus(widget.workshopId);
      } catch (_) {}
      try {
        hours = await _repo.getWorkshopHours(widget.workshopId);
        favs = await _repo.favoriteIds();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _workshop = ws;
        _services = sv;
        _hours = hours;
        _status = status;
        _isFavorite = favs.contains(widget.workshopId);
        _loading = false;
        if (ws == null) {
          _error = "Bengkel tidak ditemukan atau belum terverifikasi.";
        }
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
          message: _error ?? "Bengkel tidak ditemukan",
          onRetry: _load,
        ),
      );
    }

    final isOpen = _status?.isOpen ?? w.isOpen;
    final todayIdx = DateTime.now().weekday % 7; // Minggu = 0
    WorkshopHour? today;
    for (final h in _hours) {
      if (h.weekday == todayIdx) today = h;
    }
    final closeAt = today?.close;
    final openSub = _status?.tempClosedUntil != null
        ? "sementara"
        : (isOpen && today != null && !today.isClosed && closeAt != null)
            ? "s/d ${closeAt.length >= 5 ? closeAt.substring(0, 5) : closeAt}"
            : "hari ini";
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: c.panel2,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 274 + top,
                  width: double.infinity,
                  child: WorkshopIllustration(
                    seed: w.name.length,
                    photoUrl: w.photoUrl,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.panel2,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                  ),
                ),
                Positioned(
                  top: top + 12,
                  left: 16,
                  child: _CircleBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: "Kembali",
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go("/home"),
                  ),
                ),
                Positioned(
                  top: top + 12,
                  right: 16,
                  child: Material(
                    color: c.panel,
                    borderRadius: BorderRadius.circular(14),
                    child: FavoriteButton(
                      isFavorite: _isFavorite,
                      onToggle: _toggleFavorite,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          w.name,
                          style: AppTypography.h1.copyWith(color: c.ink),
                        ),
                      ),
                      if (w.status == "verified")
                        StatusPill(
                          label: "Terverifikasi",
                          icon: Icons.verified_outlined,
                          color: c.blueText,
                          background: c.blueSoft,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    w.address,
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: w.distanceMeters > 0
                              ? Formatters.distance(w.distanceMeters)
                              : "—",
                          label: "Jarak",
                          onTap: () => _directions(w),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: isOpen ? "Buka" : "Tutup",
                          label: openSub,
                          valueColor: isOpen ? c.ok : c.bad,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: w.ratingCount == 0
                              ? "—"
                              : w.ratingAvg.toStringAsFixed(1),
                          label: "${w.ratingCount} ulasan",
                          onTap: () =>
                              context.push("/reviews?workshopId=${w.id}"),
                        ),
                      ),
                    ],
                  ),
                  if (_status?.tempClosedUntil != null) ...[
                    const SizedBox(height: 12),
                    _Banner(
                      icon: Icons.pause_circle_outline,
                      color: c.warn,
                      background: c.warnSoft,
                      text: "Tutup sementara sampai "
                          "${DateFormat("EEE d MMM, HH:mm", "id_ID").format(_status!.tempClosedUntil!)}"
                          "${_status!.tempClosedReason != null ? " · ${_status!.tempClosedReason}" : ""}",
                    ),
                  ],
                  if ((_status?.closures ?? const []).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Banner(
                      icon: Icons.event_busy_outlined,
                      color: c.blueText,
                      background: c.blueSoft,
                      text:
                          "Libur: ${_status!.closures.take(3).map((e) => "${DateFormat("d MMM", "id_ID").format(e.date)}${e.reason != null ? " (${e.reason})" : ""}").join(", ")}",
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (w.phone != null && w.phone!.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _call(w.phone!),
                            icon: const Icon(Icons.call_outlined, size: 18),
                            label: const Text("Telepon"),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _directions(w),
                          icon: const Icon(Icons.near_me_outlined, size: 18),
                          label: const Text("Rute"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    "Pilih layanan",
                    style: AppTypography.h2.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 10),
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
                  if (w.description != null &&
                      w.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      "Tentang bengkel",
                      style: AppTypography.h2.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      w.description!,
                      style: AppTypography.body.copyWith(color: c.ink2),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    "Jam operasional",
                    style: AppTypography.h2.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    child: _hours.isEmpty
                        ? Text(
                            "Jam operasional belum diatur bengkel.",
                            style: AppTypography.body.copyWith(color: c.ink2),
                          )
                        : Column(
                            children: [
                              for (final h in _hours)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Expanded(
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
                                            .copyWith(
                                          color: h.isClosed ? c.bad : c.ink2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.panel,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total",
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                  Text(
                    Formatters.rupiah(_total),
                    style: AppTypography.h1.copyWith(color: c.ink),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                  label:
                      _selected.isEmpty ? "Pilih layanan" : "Booking sekarang",
                  onPressed: _selected.isEmpty
                      ? null
                      : () => context.push(
                            "/schedule?workshopId=${widget.workshopId}&services=${_selected.join(",")}",
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.panel,
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 18, color: c.ink),
        onPressed: onTap,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
