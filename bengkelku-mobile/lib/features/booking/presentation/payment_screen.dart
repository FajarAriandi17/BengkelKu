import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/state_views.dart";
import "../data/booking_model.dart";
import "../data/booking_repository.dart";
import "payment_instruction_sheet.dart";

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _repo = BookingRepository();
  Booking? _booking;
  bool _sandbox = false;
  bool _mayar = false;
  bool _loading = true;
  bool _paying = false;
  String? _error;
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await _repo.getBooking(widget.bookingId);
      final sb = await _repo.isSandboxPayments();
      final my = await _repo.isMayarEnabled();
      if (!mounted) return;
      if (b.status != "MENUNGGU_PEMBAYARAN") {
        context.go("/ticket?bookingId=${b.id}");
        return;
      }
      setState(() {
        _booking = b;
        _sandbox = sb;
        _mayar = my;
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = bookingErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    void tick() {
      final d = _booking?.paymentDeadline;
      if (d == null) return;
      final left = d.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _left = left.isNegative ? Duration.zero : left);
      if (left.isNegative) {
        _timer?.cancel();
        context.go("/payment-failed");
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      if (_sandbox) {
        await _repo.sandboxPay(widget.bookingId);
        if (!mounted) return;
        context.go("/payment-success?bookingId=${widget.bookingId}");
        return;
      }

      // Alur produksi: buat invoice Mayar, lalu tampilkan instruksi pembayaran
      // sambil menunggu webhook menandai lunas.
      final intent = await _repo.createPayment(widget.bookingId);
      if (!mounted) return;
      _timer?.cancel();
      final paid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => PaymentInstructionSheet(
          bookingId: widget.bookingId,
          intent: intent,
        ),
      );
      if (!mounted) return;
      if (paid == true) {
        context.go("/payment-success?bookingId=${widget.bookingId}");
      } else {
        // Cek status terbaru (mungkin sudah dibayar saat sheet ditutup, atau
        // kedaluwarsa). _load memulai ulang hitung mundur bila masih menunggu.
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  String get _countdown {
    final m = _left.inMinutes.remainder(60).toString().padLeft(2, "0");
    final s = _left.inSeconds.remainder(60).toString().padLeft(2, "0");
    return _left.inHours > 0 ? "${_left.inHours}:$m:$s" : "$m:$s";
  }

  /// true bila salah satu mode pembayaran aktif (sandbox untuk demo, Mayar
  /// untuk produksi).
  bool get _canPay => _sandbox || _mayar;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pembayaran")),
        body: const SkeletonList(),
      );
    }
    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pembayaran")),
        body: ErrorState(
          message: _error ?? "Booking tidak ditemukan",
          onRetry: _load,
        ),
      );
    }
    final b = _booking!;

    return Scaffold(
      appBar: AppBar(title: const Text("Pembayaran"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.warnSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: c.warnText, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Selesaikan pembayaran dalam $_countdown",
                      style: AppTypography.label.copyWith(color: c.warnText),
                    ),
                  ),
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
                    b.code,
                    style: AppTypography.caption.copyWith(
                      color: c.ink2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.workshopName ?? "Bengkel",
                    style: AppTypography.h2.copyWith(color: c.ink),
                  ),
                  Text(
                    Formatters.dateTimeLocal(b.scheduledAt),
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                  const Divider(height: 24),
                  for (final i in b.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(i.name, style: AppTypography.body),
                          ),
                          Text(
                            Formatters.rupiah(i.priceIdr),
                            style: AppTypography.body,
                          ),
                        ],
                      ),
                    ),
                  if (b.totalIdr != b.subtotalIdr)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Expanded(child: Text("Biaya layanan")),
                          Text(Formatters.rupiah(b.totalIdr - b.subtotalIdr)),
                        ],
                      ),
                    ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Total Bayar",
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_sandbox)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Mode uji coba (sandbox): pembayaran disimulasikan dan tidak ada dana yang ditarik.",
                  style: AppTypography.caption.copyWith(color: c.blueText),
                ),
              ),
            if (!_sandbox && _mayar)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Kamu akan diarahkan ke halaman pembayaran untuk memilih metode "
                  "(QRIS, e-wallet, virtual account, atau retail).",
                  style: AppTypography.caption.copyWith(color: c.blueText),
                ),
              ),
            if (!_sandbox && !_mayar)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.warnSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Pembayaran online belum diaktifkan. Sementara ini hubungi bengkel langsung untuk konfirmasi booking.",
                  style: AppTypography.caption.copyWith(color: c.warnText),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: _canPay
              ? "Bayar ${Formatters.rupiah(b.totalIdr)}"
              : "Pembayaran online segera hadir",
          onPressed: (_canPay && !_paying) ? _pay : null,
          loading: _paying,
        ),
      ),
    );
  }
}
