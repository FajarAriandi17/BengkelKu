// PaymentInstructionSheet — instruksi pembayaran Mayar.
//
// Pengguna diarahkan ke invoice_url (hosted checkout Mayar) untuk memilih kanal
// (QRIS, e-wallet, virtual account, retail) dan menyelesaikan pembayaran. Selagi
// terbuka, sheet memantau status booking tiap 3 detik; begitu webhook menandai
// lunas, sheet menutup dan mengembalikan `true` ke pemanggil.

import "dart:async";

import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../data/booking_repository.dart";

class PaymentInstructionSheet extends StatefulWidget {
  const PaymentInstructionSheet({
    super.key,
    required this.bookingId,
    required this.intent,
  });

  final String bookingId;
  final PaymentIntent intent;

  @override
  State<PaymentInstructionSheet> createState() =>
      _PaymentInstructionSheetState();
}

class _PaymentInstructionSheetState extends State<PaymentInstructionSheet> {
  final _repo = BookingRepository();
  Timer? _poll;
  Timer? _expiryTimer;
  Duration _left = Duration.zero;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _startExpiryCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _startExpiryCountdown() {
    void tick() {
      final e = widget.intent.expiresAt;
      if (e == null) return;
      final left = e.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _left = left.isNegative ? Duration.zero : left);
      if (left.isNegative) {
        _expiryTimer!.cancel();
        Navigator.of(context).pop(false);
      }
    }

    tick();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _startPolling() {
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    try {
      final b = await _repo.getBooking(widget.bookingId);
      if (!mounted) return;
      if (b.status != "MENUNGGU_PEMBAYARAN") {
        _poll!.cancel();
        _expiryTimer!.cancel();
        Navigator.of(context).pop(
          b.status == "DIBAYAR_MENUNGGU_KONFIRMASI" ||
              b.status == "DIKONFIRMASI",
        );
      }
    } catch (_) {
      // Kegagalan ping sementara diabaikan; polling lanjut.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String get _countdownText {
    final m = _left.inMinutes.remainder(60).toString().padLeft(2, "0");
    final s = _left.inSeconds.remainder(60).toString().padLeft(2, "0");
    return _left.inHours > 0 ? "${_left.inHours}:$m:$s" : "$m:$s";
  }

  Future<void> _openInvoice() async {
    final url = widget.intent.invoiceUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak dapat membuka halaman pembayaran")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final intent = widget.intent;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Selesaikan Pembayaran",
                  style: AppTypography.h2.copyWith(color: c.ink, fontSize: 17),
                ),
                Text(
                  "Bayar dalam $_countdownText",
                  style: AppTypography.label.copyWith(color: c.warnText),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Total ${Formatters.rupiah(intent.amountIdr)}",
              style: AppTypography.caption.copyWith(color: c.ink2),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.blueSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.open_in_browser, size: 40, color: c.blue),
                  const SizedBox(height: 10),
                  Text(
                    "Buka halaman pembayaran untuk memilih metode (QRIS, e-wallet, "
                    "virtual account, atau retail) dan menyelesaikan transaksi.",
                    style: AppTypography.caption.copyWith(color: c.blueText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: "Buka Halaman Pembayaran",
              onPressed: _openInvoice,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: "Saya Sudah Membayar",
              variant: AppButtonVariant.secondary,
              loading: _checking,
              onPressed: _checking ? null : _checkStatus,
            ),
            const SizedBox(height: 10),
            Text(
              "Pembayaran terverifikasi otomatis. Jangan tutup aplikasi sebelum status berubah.",
              style: AppTypography.caption.copyWith(color: c.ink2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
