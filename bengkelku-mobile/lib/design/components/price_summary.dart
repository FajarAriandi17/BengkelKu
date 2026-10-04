import "package:flutter/material.dart";

import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";
import "../../core/utils/formatters.dart";

/// Ringkasan biaya booking (subtotal, komisi tersirat, total).
class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotalIdr,
    this.platformFeeIdr = 0,
    this.commissionRate = 0.08,
  });

  final int subtotalIdr;
  final int platformFeeIdr;
  final double commissionRate;

  int get totalIdr => subtotalIdr + platformFeeIdr;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.blueSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ringkasan Biaya",
            style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Subtotal Layanan",
                style: AppTypography.body
                    .copyWith(color: c.ink.withValues(alpha: 0.7)),
              ),
              Text(
                Formatters.rupiah(subtotalIdr),
                style: AppTypography.bodyStrong.copyWith(color: c.ink),
              ),
            ],
          ),
          if (platformFeeIdr > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Biaya Layanan",
                  style: AppTypography.body
                      .copyWith(color: c.ink.withValues(alpha: 0.7)),
                ),
                Text(
                  Formatters.rupiah(platformFeeIdr),
                  style: AppTypography.bodyStrong.copyWith(color: c.ink),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Pembayaran",
                style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
              ),
              Text(
                Formatters.rupiah(totalIdr),
                style: AppTypography.h1.copyWith(color: c.blue, fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
