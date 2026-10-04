import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../domain/cancellation_policy.dart";

/// Bottom sheet pembatalan booking & rincian refund.
class CancelSheet extends StatefulWidget {
  const CancelSheet({
    super.key,
    required this.bookingId,
    required this.scheduledAt,
    required this.totalPaidIdr,
  });

  final String bookingId;
  final DateTime scheduledAt;
  final int totalPaidIdr;

  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  final _reasonController = TextEditingController();
  late RefundCalculation _refund;

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
          Text("Batalkan Booking",
              style: AppTypography.h1.copyWith(color: c.ink)),
          const SizedBox(height: 12),

          // Box Informasi Kebijakan Refund
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Kebijakan Pengembalian Dana",
                    style: AppTypography.label.copyWith(color: c.blue)),
                const SizedBox(height: 4),
                Text(_refund.explanation,
                    style: AppTypography.caption.copyWith(color: c.ink)),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Pengembalian Dana:",
                        style: AppTypography.body.copyWith(color: c.ink)),
                    Text(
                      Formatters.rupiah(_refund.refundAmountIdr),
                      style: AppTypography.h2.copyWith(color: c.blue),
                    ),
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Booking berhasil dibatalkan")),
              );
            },
          ),
        ],
      ),
    );
  }
}
