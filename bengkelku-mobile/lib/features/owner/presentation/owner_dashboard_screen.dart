import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/booking_status_badge.dart";
import "../../sos/presentation/owner_standby_screen.dart";
import "reject_sheet.dart";

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Bengkel Jaya Motor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push("/owner/wallet"),
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card Ringkasan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pendapatan Hari Ini",
                          style: AppTypography.caption
                              .copyWith(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text("Rp 340.000",
                          style: AppTypography.h1
                              .copyWith(color: Colors.white, fontSize: 22)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: c.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text("Scan Check-In"),
                    onPressed: () => context.push("/owner/scan"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bantuan Darurat (v1.3)
            const OwnerStandbyTile(),
            const SizedBox(height: 16),

            // Quick Menu
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.star_outline),
                    label: const Text("Ulasan Masuk"),
                    onPressed: () => context.push("/owner/reviews"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text("Dompet Payout"),
                    onPressed: () => context.push("/owner/wallet"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text("Antrean Booking Hari Ini",
                style: AppTypography.h2.copyWith(color: c.ink)),
            const SizedBox(height: 12),

            // Card item booking masuk
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Booking #BK-884920",
                          style: AppTypography.h2
                              .copyWith(color: c.ink, fontSize: 16)),
                      const BookingStatusBadge(
                          status: "DIBAYAR_MENUNGGU_KONFIRMASI"),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("Pengendara: Budi Santoso (Honda Vario 160)",
                      style: AppTypography.body
                          .copyWith(color: c.ink.withValues(alpha: 0.8))),
                  Text("Layanan: Servis Rutin + Ganti Oli Sintetik",
                      style: AppTypography.caption
                          .copyWith(color: c.ink.withValues(alpha: 0.6))),
                  Text("Jam Slot: 09:00 WIB",
                      style: AppTypography.caption.copyWith(
                          color: c.blue, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.bad,
                            side: BorderSide(color: c.bad),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              builder: (ctx) => const OwnerRejectSheet(
                                  bookingId: "BK-884920"),
                            );
                          },
                          child: const Text("Tolak"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: "Konfirmasi / Terima",
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Booking berhasil dikonfirmasi")),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: "Input Pengerjaan Servis & Odometer",
                    variant: AppButtonVariant.secondary,
                    onPressed: () =>
                        context.push("/owner/record?bookingId=BK-884920"),
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
