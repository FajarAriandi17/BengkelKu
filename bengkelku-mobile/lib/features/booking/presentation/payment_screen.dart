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
  bool _loading = true;
  bool _paying = false;
  String? _error;
  String _method = "qris";
  Timer? _timer;
  Duration _left = Duration.zero;

  static const _methods = [
    ("qris", "QRIS (semua bank & e-wallet)", Icons.qr_code_2),
    ("ewallet", "E-Wallet (GoPay / OVO / DANA)", Icons.account_balance_wallet),
    ("va", "Virtual Account (BCA / Mandiri / BRI / BNI)", Icons.account_balance),
  ];

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
      if (!mounted) return;
      if (b.status != "MENUNGGU_PEMBAYARAN") {
        context.go("/ticket?bookingId=${b.id}");
        return;
      }
      setState(() {
        _booking = b;
        _sandbox = sb;
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
      await _repo.sandboxPay(widget.bookingId, _method);
      if (!mounted) return;
      context.go("/payment-success?bookingId=${widget.bookingId}");
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: const Text("Pembayaran")),
          body: const SkeletonList(itemCount: 4));
    }
    if (_error != null || _booking == null) {
      return Scaffold(
          appBar: AppBar(title: const Text("Pembayaran")),
          body: ErrorState(message: _error ?? "Booking tidak ditemukan", onRetry: _load));
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
                  color: c.warnSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: c.warnText, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("Selesaikan pembayaran dalam $_countdown",
                        style: AppTypography.label.copyWith(color: c.warnText)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.panel, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.code, style: AppTypography.caption.copyWith(color: c.ink2)),
                  const SizedBox(height: 2),
                  Text(b.workshopName ?? "Bengkel",
                      style: AppTypography.h2.copyWith(color: c.ink)),
                  Text(Formatters.dateTimeLocal(b.scheduledAt),
                      style: AppTypography.caption.copyWith(color: c.ink2)),
                  const Divider(height: 24),
                  for (final i in b.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Text(i.name, style: AppTypography.body)),
                        Text(Formatters.rupiah(i.priceIdr), style: AppTypography.body),
                      ]),
                    ),
                  if (b.totalIdr != b.subtotalIdr)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        const Expanded(child: Text("Biaya layanan")),
                        Text(Formatters.rupiah(b.totalIdr - b.subtotalIdr)),
                      ]),
                    ),
                  const Divider(height: 20),
                  Row(children: [
                    Expanded(
                        child: Text("Total Bayar",
                            style: AppTypography.bodyStrong.copyWith(color: c.ink))),
                    Text(Formatters.rupiah(b.totalIdr),
                        style: AppTypography.h2.copyWith(color: c.blue)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text("Metode Pembayaran",
                style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
            const SizedBox(height: 10),
            for (final m in _methods)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _method = m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _method == m.$1 ? c.blue : c.line,
                          width: _method == m.$1 ? 1.6 : 1),
                    ),
                    child: Row(children: [
                      Icon(m.$3, color: c.blue),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m.$2, style: AppTypography.body)),
                      Icon(
                          _method == m.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _method == m.$1 ? c.blue : c.line),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (_sandbox)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: c.blueSoft, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "Mode uji coba (sandbox): pembayaran disimulasikan dan tidak ada dana yang ditarik.",
                  style: AppTypography.caption.copyWith(color: c.blueText),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: _sandbox
              ? "Bayar ${Formatters.rupiah(b.totalIdr)}"
              : "Pembayaran online segera hadir",
          onPressed: (_sandbox && !_paying) ? _pay : null,
          loading: _paying,
        ),
      ),
    );
  }
}
