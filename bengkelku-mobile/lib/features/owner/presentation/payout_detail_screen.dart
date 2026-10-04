import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";

class PayoutDetailScreen extends StatelessWidget {
  const PayoutDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rincian Payout & Komisi"),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Detail Transaksi Payout H+1",
                style: AppTypography.h1.copyWith(color: c.ink)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Pendapatan Kotor (Gross)",
                          style: AppTypography.body
                              .copyWith(color: c.ink.withValues(alpha: 0.7))),
                      Text(Formatters.rupiah(340000),
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.ink)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Komisi Platform BengkelKu (8%)",
                          style: AppTypography.body.copyWith(color: c.bad)),
                      Text("-${Formatters.rupiah(27200)}",
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.bad)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Pencairan Bersih (Net)",
                          style: AppTypography.h2.copyWith(color: c.ink)),
                      Text(Formatters.rupiah(312800),
                          style: AppTypography.h1
                              .copyWith(color: c.ok, fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
