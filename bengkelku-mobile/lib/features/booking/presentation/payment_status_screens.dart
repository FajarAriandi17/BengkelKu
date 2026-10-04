import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.okSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, size: 72, color: c.ok),
              ),
              const SizedBox(height: 24),
              Text(
                "Pembayaran Berhasil!",
                style: AppTypography.display.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Pembayaran kamu telah diterima. Menunggu pihak bengkel mengonfirmasi pesanan kamu.",
                style: AppTypography.body
                    .copyWith(color: c.ink.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: "Lihat Tiket Booking",
                onPressed: () => context.go("/ticket?bookingId=$bookingId"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentFailedScreen extends StatelessWidget {
  const PaymentFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(Icons.cancel_outlined, size: 72, color: c.bad),
              const SizedBox(height: 24),
              Text(
                "Pembayaran Gagal",
                style: AppTypography.display.copyWith(color: c.bad),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Transaksi tidak dapat diproses. Silakan coba metode pembayaran lain.",
                style: AppTypography.body
                    .copyWith(color: c.ink.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: "Coba Lagi",
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
