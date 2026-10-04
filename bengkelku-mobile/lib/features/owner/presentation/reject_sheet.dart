import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";

/// Bottom sheet penolakan booking oleh bengkel.
class OwnerRejectSheet extends StatefulWidget {
  const OwnerRejectSheet({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<OwnerRejectSheet> createState() => _OwnerRejectSheetState();
}

class _OwnerRejectSheetState extends State<OwnerRejectSheet> {
  final _reasonController = TextEditingController();

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
          Text("Tolak Pesanan Booking",
              style: AppTypography.h1.copyWith(color: c.bad)),
          const SizedBox(height: 8),
          Text(
            "Penolakan pesanan akan memicu refund 100% dana ke pengendara.",
            style: AppTypography.body
                .copyWith(color: c.ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _reasonController,
            label: "Alasan Penolakan",
            hint: "misal: Slot penuh / Bengkel libur...",
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: "Konfirmasi Tolak Booking",
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        "Booking ditolak. Refund 100% telah dikirim ke pelanggan.")),
              );
            },
          ),
        ],
      ),
    );
  }
}
