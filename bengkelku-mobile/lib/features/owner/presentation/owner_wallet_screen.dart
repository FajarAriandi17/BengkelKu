import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";

class OwnerWalletScreen extends StatelessWidget {
  const OwnerWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dompet & Payout"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () => context.push("/owner/bank-account"),
          ),
        ],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Saldo Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Saldo Siap Dicairkan (Payout H+1)",
                  style: AppTypography.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.rupiah(312800),
                  style: AppTypography.h1
                      .copyWith(color: Colors.white, fontSize: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  "Komisi platform 8% dipotong otomatis saat batch payout H+1.",
                  style: AppTypography.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            "Riwayat Batch Payout",
            style: AppTypography.h2.copyWith(color: c.ink),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.panel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Payout H+1 (12 Sep 2026)",
                      style: AppTypography.bodyStrong.copyWith(color: c.ink),
                    ),
                    Text(
                      "BCA ••••• 8821",
                      style: AppTypography.caption
                          .copyWith(color: c.ink.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                Text(
                  Formatters.rupiah(312800),
                  style: AppTypography.h2.copyWith(color: c.ok),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
