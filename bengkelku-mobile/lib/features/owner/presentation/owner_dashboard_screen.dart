// ownerDash — dasbor bengkel dengan data nyata (owner_dashboard, 0022).
// Pendapatan bersih hari ini, antrean booking + aksi konfirmasi/tolak/check-in,
// kartu siaga darurat. Mengarahkan ke status verifikasi bila belum disetujui.

import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/booking_status_badge.dart";
import "../../../design/components/state_views.dart";
import "../../sos/presentation/owner_standby_screen.dart";
import "../data/owner_repository.dart";
import "reject_sheet.dart";

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _repo = OwnerRepository();
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final d = await _repo.getDashboard();
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is PostgrestException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _act(String bookingId, String action, String success) async {
    setState(() => _busyId = bookingId);
    try {
      await _repo.bookingAction(bookingId, action);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is PostgrestException ? e.message : "$e"),
          backgroundColor: context.colors.bad,
        ));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(String bookingId) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => OwnerRejectSheet(bookingId: bookingId),
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ws = (_d?["workshop"] as Map?)?.cast<String, dynamic>();
    final status = ws?["status"] as String?;

    Widget body;
    if (_loading) {
      body = const Padding(
          padding: EdgeInsets.all(16), child: SkeletonList(itemCount: 4));
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_d == null) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: "kamu belum punya bengkel",
        message: "daftarkan bengkel untuk mulai menerima booking.",
        actionLabel: "Daftarkan bengkel",
        onAction: () => context.push("/owner/register"),
      );
    } else if (status != "verified") {
      body = EmptyState(
        icon: status == "pending" ? Icons.hourglass_top : Icons.info_outline,
        title: status == "pending"
            ? "bengkel sedang diverifikasi"
            : status == "rejected"
                ? "verifikasi ditolak"
                : status == "suspended"
                    ? "bengkel ditangguhkan"
                    : "pendaftaran belum dikirim",
        message: "dasbor aktif setelah bengkel disetujui tim BengkelKu.",
        actionLabel: "Lihat status",
        onAction: () => context.push("/owner/status"),
      );
    } else {
      final queue = ((_d!["queue"] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryCard(
              revenue: (_d!["today_revenue"] as num?)?.toInt() ?? 0,
              todayCount: (_d!["today_count"] as num?)?.toInt() ?? 0,
              waiting: (_d!["waiting_confirmation"] as num?)?.toInt() ?? 0,
            ),
            const SizedBox(height: 16),
            const OwnerStandbyTile(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.star_outline),
                    label: Text("Ulasan (${ws?["rating_count"] ?? 0})"),
                    onPressed: () => context.push("/owner/reviews"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text("Dompet"),
                    onPressed: () => context.push("/owner/wallet"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text("Antrean Booking",
                style: AppTypography.h2.copyWith(color: c.ink)),
            const SizedBox(height: 12),
            if (queue.isEmpty)
              const EmptyState(
                icon: Icons.event_available,
                title: "belum ada booking aktif",
                message: "booking yang sudah dibayar pelanggan muncul di sini.",
              ),
            for (final b in queue)
              _BookingCard(
                booking: b,
                busy: _busyId == b["id"],
                onConfirm: () => _act(b["id"] as String, "confirm",
                    "booking dikonfirmasi. pelanggan sudah diberi tahu."),
                onReject: () => _reject(b["id"] as String),
                onCheckIn: () =>
                    _act(b["id"] as String, "check_in", "check-in dicatat"),
                onStart: () =>
                    _act(b["id"] as String, "start", "pengerjaan dimulai"),
                onRecord: () => context
                    .push("/owner/record?bookingId=${b["id"]}")
                    .then((_) => _load()),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: Text(ws?["name"] as String? ?? "Dashboard Bengkel"),
        actions: [
          IconButton(
            tooltip: "Scan check-in",
            icon: const Icon(Icons.qr_code_scanner),
            onPressed:
                status == "verified" ? () => context.push("/owner/scan") : null,
          ),
          IconButton(
            tooltip: "Notifikasi",
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push("/notifications"),
          ),
        ],
        elevation: 0,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.revenue,
    required this.todayCount,
    required this.waiting,
  });

  final int revenue;
  final int todayCount;
  final int waiting;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Pendapatan bersih hari ini",
              style: AppTypography.caption.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(end: revenue.toDouble()),
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 600),
            builder: (_, v, __) => Text(
              Formatters.rupiah(v.round()),
              style:
                  AppTypography.h1.copyWith(color: Colors.white, fontSize: 24),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: "booking hari ini", value: "$todayCount"),
              const SizedBox(width: 24),
              _Stat(label: "menunggu konfirmasi", value: "$waiting"),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.h2.copyWith(color: Colors.white)),
        Text(label,
            style: AppTypography.caption.copyWith(color: Colors.white70)),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.busy,
    required this.onConfirm,
    required this.onReject,
    required this.onCheckIn,
    required this.onStart,
    required this.onRecord,
  });

  final Map<String, dynamic> booking;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onCheckIn;
  final VoidCallback onStart;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = booking["status"] as String;
    final id = booking["id"] as String;
    final at = DateTime.parse(booking["scheduled_at"] as String);
    final code = "BK-${id.substring(0, 6).toUpperCase()}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(code,
                    style:
                        AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
              ),
              BookingStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${booking["rider_name"] ?? "Pelanggan"}"
            "${booking["vehicle"] != null ? " · ${booking["vehicle"]}" : ""}",
            style: AppTypography.body.copyWith(color: c.ink),
          ),
          if (booking["services"] != null)
            Text(booking["services"] as String,
                style: AppTypography.caption.copyWith(color: c.ink2)),
          const SizedBox(height: 4),
          Text(
            "${Formatters.dateTimeLocal(at)} · ${Formatters.rupiah((booking["total_idr"] as num?) ?? 0)}",
            style: AppTypography.caption
                .copyWith(color: c.blueText, fontWeight: FontWeight.w700),
          ),
          const Divider(height: 20),
          if (status == "DIBAYAR_MENUNGGU_KONFIRMASI")
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.bad,
                      side: BorderSide(color: c.bad),
                    ),
                    onPressed: busy ? null : onReject,
                    child: const Text("Tolak"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: "Konfirmasi",
                    loading: busy,
                    onPressed: busy ? null : onConfirm,
                  ),
                ),
              ],
            )
          else if (status == "DIKONFIRMASI")
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: "Check-in",
                    variant: AppButtonVariant.secondary,
                    onPressed: busy ? null : onCheckIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: "Mulai kerjakan",
                    loading: busy,
                    onPressed: busy ? null : onStart,
                  ),
                ),
              ],
            )
          else if (status == "CHECK_IN")
            AppButton(
              label: "Mulai kerjakan",
              loading: busy,
              onPressed: busy ? null : onStart,
            )
          else
            AppButton(
              label: "Input Pengerjaan & Odometer",
              variant: AppButtonVariant.secondary,
              onPressed: onRecord,
            ),
        ],
      ),
    );
  }
}
