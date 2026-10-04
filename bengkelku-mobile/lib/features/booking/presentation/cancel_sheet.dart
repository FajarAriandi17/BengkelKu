import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../data/booking_repository.dart";
import "../domain/cancellation_policy.dart";

/// Bottom sheet pembatalan booking & rincian refund. Pop `true` bila berhasil.
class CancelSheet extends StatefulWidget {
  const CancelSheet({
    super.key,
    required this.bookingId,
    required this.scheduledAt,
    required this.totalPaidIdr,
    this.status = "DIBAYAR_MENUNGGU_KONFIRMASI",
  });

  final String bookingId;
  final DateTime scheduledAt;
  final int totalPaidIdr;
  final String status;

  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  final _reasonController = TextEditingController();
  final _repo = BookingRepository();
  late RefundCalculation _refund;
  bool _submitting = false;

  bool get _unpaid => widget.status == "MENUNGGU_PEMBAYARAN";

  @override
  void initState() {
    super.initState();
    _refund = calculateRefund(
      scheduledAt: widget.scheduledAt,
      now: DateTime.now(),
      totalPaidIdr: widget.totalPaidIdr,
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tuliskan alasan pembatalan.")));
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await _repo.cancelBooking(widget.bookingId, reason);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(
        content: Text(r.refundIdr > 0
            ? "Booking dibatalkan. Refund ${Formatters.rupiah(r.refundIdr)} (${r.refundPct}%) diproses."
            : "Booking dibatalkan."),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Batalkan Booking", style: AppTypography.h1.copyWith(color: c.ink)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: c.blueSoft, borderRadius: BorderRadius.circular(12)),
            child: _unpaid
                ? Text("Booking belum dibayar, pembatalan tidak dikenai biaya.",
                    style: AppTypography.caption.copyWith(color: c.ink))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Kebijakan Pengembalian Dana",
                          style: AppTypography.label.copyWith(color: c.blueText)),
                      const SizedBox(height: 4),
                      Text(_refund.explanation,
                          style: AppTypography.caption.copyWith(color: c.ink)),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Estimasi refund:",
                              style: AppTypography.body.copyWith(color: c.ink)),
                          Text(Formatters.rupiah(_refund.refundAmountIdr),
                              style: AppTypography.h2.copyWith(color: c.blueText)),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _reasonController,
            label: "Alasan Pembatalan",
            hint: "Berikan alasan pembatalan...",
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: "Konfirmasi Pembatalan",
            onPressed: _submitting ? null : _confirm,
            loading: _submitting,
          ),
        ],
      ),
    );
  }
}
