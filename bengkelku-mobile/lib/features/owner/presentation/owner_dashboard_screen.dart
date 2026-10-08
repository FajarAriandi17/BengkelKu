// ownerDash — dasbor bengkel dengan data nyata (owner_dashboard, 0022).
// Pendapatan bersih hari ini, antrean booking + aksi konfirmasi/tolak/check-in,
// kartu siaga darurat. Mengarahkan ke status verifikasi bila belum disetujui.

import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_shell.dart";
import "../../../design/components/booking_status_badge.dart";
import "../../../design/components/state_views.dart";
import "../../sos/presentation/owner_standby_screen.dart";
import "../data/owner_repository.dart";
import "../data/owner_schedule.dart";
import "owner_schedule_screen.dart";
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
  bool? _isOpen;
  OwnerSchedule? _schedule;
  bool _toggling = false;
  final _schedRepo = OwnerScheduleRepository();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final d = await _repo.getDashboard();
      bool? open;
      OwnerSchedule? sch;
      if (d != null) {
        try {
          sch = await _schedRepo.get();
          open = sch.isOpen && !sch.isTempClosed;
        } catch (_) {
          open = null; // migrasi 0026 belum dijalankan — tile tetap tampil
        }
      }
      if (!mounted) return;
      _isOpen = open;
      _schedule = sch;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is PostgrestException ? e.message : "$e"),
            backgroundColor: context.colors.bad,
          ),
        );
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

  /// Sakelar "Menerima booking": mati = tutup sementara, nyala = buka lagi.
  Future<void> _toggleAccepting(bool accept) async {
    final sch = _schedule;
    if (sch == null) {
      await context.push("/owner/schedule");
      await _load();
      return;
    }
    final sheet = accept
        ? null
        : showTempCloseFlow(context, repo: _schedRepo, hours: sch.hours);
    final messenger = ScaffoldMessenger.of(context);
    final bad = context.colors.bad;
    setState(() => _toggling = true);
    try {
      final next = accept ? await _schedRepo.setTempClosed(null) : await sheet;
      if (next != null && mounted) {
        setState(() {
          _schedule = next;
          _isOpen = next.isOpen && !next.isTempClosed;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? "bengkel kembali menerima booking sesuai jadwal"
                  : "bengkel ditutup sementara",
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(scheduleErrorMessage(e)), backgroundColor: bad),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ws = (_d?["workshop"] as Map?)?.cast<String, dynamic>();
    final status = ws?["status"] as String?;

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonList(),
      );
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
            _ShopHeader(
              name: ws?["name"] as String? ?? "Bengkel",
              onSwitch: () => context.go("/home"),
            ),
            const SizedBox(height: 14),
            _AcceptingCard(
              schedule: _schedule,
              isOpen: _isOpen,
              busy: _toggling,
              onToggle: _toggleAccepting,
              onSchedule: () =>
                  context.push("/owner/schedule").then((_) => _load()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: "${(_d!["today_count"] as num?)?.toInt() ?? 0}",
                    label: "Booking hari ini",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: Formatters.rupiah(
                      (_d!["today_revenue"] as num?)?.toInt() ?? 0,
                    ),
                    label: "Pendapatan",
                    onTap: () => context.push("/owner/wallet"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: ((ws?["rating_avg"] as num?) ?? 0) == 0
                        ? "—"
                        : (ws!["rating_avg"] as num).toStringAsFixed(1),
                    label: "Ulasan ›",
                    onTap: () => context.push("/owner/reviews"),
                  ),
                ),
              ],
            ),
            if (((_d!["waiting_confirmation"] as num?)?.toInt() ?? 0) > 0) ...[
              const SizedBox(height: 12),
              StatusPill(
                label:
                    "${_d!["waiting_confirmation"]} booking menunggu konfirmasi",
                icon: Icons.notifications_active_outlined,
                color: c.warnText,
                background: c.warnSoft,
              ),
            ],
            const SizedBox(height: 12),
            const OwnerStandbyTile(),
            const SizedBox(height: 24),
            Text(
              "Antrean Booking",
              style: AppTypography.h2.copyWith(color: c.ink),
            ),
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
                onConfirm: () => _act(
                  b["id"] as String,
                  "confirm",
                  "booking dikonfirmasi. pelanggan sudah diberi tahu.",
                ),
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
      backgroundColor: c.panel2,
      bottomNavigationBar: status == "verified"
          ? Container(
              decoration: BoxDecoration(
                color: c.panel,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: AppButton(
                  label: "Scan QR check-in",
                  icon: Icons.qr_code_scanner,
                  onPressed: () => context.push("/owner/scan"),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Text("Mode bengkel"),
        backgroundColor: c.panel2,
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
                child: Text(
                  code,
                  style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
                ),
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
            Text(
              booking["services"] as String,
              style: AppTypography.caption.copyWith(color: c.ink2),
            ),
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

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.name, required this.onSwitch});
  final String name;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        IconTile(
          icon: Icons.storefront_outlined,
          color: Colors.white,
          background: c.blue,
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.h2.copyWith(color: c.ink),
              ),
              Text(
                "Mode bengkel",
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
            ],
          ),
        ),
        SquareIconButton(
          icon: Icons.swap_horiz_rounded,
          tooltip: "Beralih ke mode pengendara",
          onTap: onSwitch,
        ),
      ],
    );
  }
}

/// Kartu status buka + sakelar "Menerima booking" (prototype ownerDash),
/// terhubung ke jadwal buka/tutup (0026).
class _AcceptingCard extends StatelessWidget {
  const _AcceptingCard({
    required this.schedule,
    required this.isOpen,
    required this.busy,
    required this.onToggle,
    required this.onSchedule,
  });

  final OwnerSchedule? schedule;
  final bool? isOpen;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final temp = schedule?.isTempClosed ?? false;
    final open = isOpen ?? true;
    final fmt = DateFormat("EEE d MMM, HH:mm", "id_ID");

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: temp ? "Tutup sementara" : (open ? "Buka" : "Tutup"),
                color: temp ? c.warnText : (open ? c.okText : c.badText),
                background: temp ? c.warnSoft : (open ? c.okSoft : c.badSoft),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Menerima booking",
                  style: AppTypography.body.copyWith(color: c.ink2),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                Switch(
                  value: !temp,
                  activeTrackColor: c.okC,
                  onChanged: onToggle,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            temp
                ? "buka lagi ${fmt.format(schedule!.tempClosedUntil!)}"
                    "${schedule!.tempClosedReason != null ? " · ${schedule!.tempClosedReason}" : ""}"
                : open
                    ? "bengkelmu tampil buka dan bisa dibooking pengendara sekitar."
                    : "di luar jam buka atau sedang libur — slot dibuka sesuai jadwal.",
            style: AppTypography.caption.copyWith(color: c.ink2),
          ),
          Divider(height: 24, color: c.line),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onSchedule,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const IconTile(icon: Icons.schedule_rounded, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Jadwal buka",
                          style: AppTypography.label.copyWith(color: c.ink),
                        ),
                        Text(
                          _summary(schedule),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: c.ink2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.ink2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _summary(OwnerSchedule? s) {
    if (s == null) return "atur jam buka, libur, & tutup sementara";
    final today = s.hours[DateTime.now().weekday % 7];
    final t = today.isClosed
        ? "hari ini libur"
        : "hari ini ${today.open}–${today.close}";
    final libur = s.closures.isEmpty ? "" : " · ${s.closures.length} libur";
    return "$t$libur";
  }
}
