import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/booking_status_badge.dart";
import "../../../design/components/state_views.dart";
import "../data/booking_model.dart";
import "../data/booking_repository.dart";
import "cancel_sheet.dart";

class BookingTicketScreen extends StatefulWidget {
  const BookingTicketScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<BookingTicketScreen> createState() => _BookingTicketScreenState();
}

class _BookingTicketScreenState extends State<BookingTicketScreen> {
  final _repo = BookingRepository();
  Booking? _b;
  bool _loading = true;
  String? _error;

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
      final b = await _repo.getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _b = b;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = bookingErrorMessage(e);
        _loading = false;
      });
    }
  }

  String _hint(String status) => switch (status) {
        "MENUNGGU_PEMBAYARAN" =>
          "Selesaikan pembayaran sebelum batas waktu agar slot tidak hangus.",
        "DIBAYAR_MENUNGGU_KONFIRMASI" =>
          "Pembayaran diterima. Menunggu bengkel mengonfirmasi jadwal.",
        "DIKONFIRMASI" =>
          "Datang sesuai jadwal dan tunjukkan kode booking ini ke bengkel.",
        "CHECK_IN" => "Kamu sudah check-in. Motor akan segera dikerjakan.",
        "DIKERJAKAN" => "Motor sedang dikerjakan mekanik.",
        "SELESAI" =>
          "Servis selesai. Terima kasih! Beri ulasan untuk membantu pengendara lain.",
        "DIBATALKAN" => "Booking dibatalkan.",
        "DITOLAK" =>
          "Bengkel tidak dapat menerima booking ini. Dana dikembalikan penuh.",
        "KEDALUWARSA" => "Batas waktu pembayaran terlewati.",
        "TIDAK_HADIR" => "Kamu tidak hadir pada jadwal yang dipesan.",
        _ => "",
      };

  Future<void> _cancel(Booking b) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => CancelSheet(
        bookingId: b.id,
        scheduledAt: b.scheduledAt,
        totalPaidIdr: b.totalIdr,
        status: b.status,
      ),
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget body;
    Widget? bottom;
    if (_loading) {
      body = const SkeletonList();
    } else if (_error != null || _b == null) {
      body = ErrorState(
        message: _error ?? "Booking tidak ditemukan",
        onRetry: _load,
      );
    } else {
      final b = _b!;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Kode Booking",
                        style: AppTypography.caption.copyWith(color: c.ink2),
                      ),
                      BookingStatusBadge(status: b.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    b.code,
                    style: AppTypography.display
                        .copyWith(color: c.blue, letterSpacing: 2),
                  ),
                  if (_hint(b.status).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _hint(b.status),
                      style: AppTypography.caption.copyWith(color: c.ink),
                    ),
                  ],
                  const Divider(height: 28),
                  Text(
                    b.workshopName ?? "Bengkel",
                    style: AppTypography.h2.copyWith(color: c.ink),
                  ),
                  if (b.workshopAddress != null)
                    Text(
                      b.workshopAddress!,
                      style: AppTypography.caption.copyWith(color: c.ink2),
                    ),
                  const SizedBox(height: 12),
                  _info(
                    context,
                    Icons.event,
                    Formatters.dateTimeLocal(b.scheduledAt),
                  ),
                  if (b.vehicleInfo != null)
                    _info(context, Icons.two_wheeler, b.vehicleInfo!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Rincian Layanan",
                    style:
                        AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  for (final i in b.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              i.isAddon
                                  ? "${i.name} (tambahan${i.addonApproved == null ? ", menunggu persetujuan" : i.addonApproved! ? "" : ", ditolak"})"
                                  : i.name,
                              style: AppTypography.body,
                            ),
                          ),
                          Text(
                            Formatters.rupiah(i.priceIdr),
                            style: AppTypography.body,
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Total",
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.ink),
                        ),
                      ),
                      Text(
                        Formatters.rupiah(b.totalIdr),
                        style: AppTypography.h2.copyWith(color: c.blue),
                      ),
                    ],
                  ),
                  if (b.refundIdr != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Refund ${Formatters.rupiah(b.refundIdr!)} · ${b.refundStatus ?? "diproses"}",
                      style: AppTypography.caption.copyWith(color: c.okText),
                    ),
                  ],
                  if (b.cancelReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Alasan: ${b.cancelReason}",
                      style: AppTypography.caption.copyWith(color: c.ink2),
                    ),
                  ],
                ],
              ),
            ),
            if (b.canCancel) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _cancel(b),
                icon: Icon(Icons.cancel_outlined, color: c.bad),
                label: Text("Batalkan Booking", style: TextStyle(color: c.bad)),
              ),
            ],
          ],
        ),
      );
      if (b.status == "MENUNGGU_PEMBAYARAN") {
        bottom = AppButton(
          label: "Lanjutkan Pembayaran",
          onPressed: () => context.push("/payment?bookingId=${b.id}"),
        );
      } else if (b.status == "SELESAI") {
        bottom = AppButton(
          label: "Beri Ulasan",
          onPressed: () => context.push("/rate?bookingId=${b.id}"),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tiket Booking"),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Laporkan masalah",
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => context.push(
              "/help/report?bookingId=${Uri.encodeComponent(widget.bookingId)}",
            ),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(minimum: const EdgeInsets.all(16), child: bottom),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}
