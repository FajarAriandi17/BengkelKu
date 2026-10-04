import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/price_summary.dart";
import "../data/booking_repository.dart";

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final _bookingRepo = BookingRepository();
  bool _loading = false;

  Future<void> _processBooking() async {
    setState(() => _loading = true);
    try {
      final booking = await _bookingRepo.createBooking(
        workshopId: widget.workshopId,
        vehicleId: "v-1",
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        items: [
          {"name": "Servis Rutin / Ringan", "price_idr": 55000},
          {"name": "Ganti Oli Mesin Sintetik", "price_idr": 65000},
        ],
        subtotalIdr: 120000,
        totalIdr: 120000,
      );

      if (mounted) {
        context.push("/payment?bookingId=${booking.id}");
      }
    } catch (_) {
      // Fallback redirect untuk UI flow
      if (mounted) {
        context.push("/payment?bookingId=bk-mock-123");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ringkasan Pemesanan"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workshop
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bengkel Jaya Motor", style: AppTypography.h2.copyWith(color: c.ink)),
                  const SizedBox(height: 4),
                  Text("Jl. Fatmawati No. 12, Jakarta Selatan", style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.6))),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Jadwal Servis", style: AppTypography.body.copyWith(color: c.ink.withOpacity(0.7))),
                      Text("Besok, 09.00 WIB", style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Kendaraan", style: AppTypography.body.copyWith(color: c.ink.withOpacity(0.7))),
                      Text("Honda Vario 160 (B 1234 XYZ)", style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Layanan dipilih
            Text("Layanan Dipesan", style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Servis Rutin / Ringan", style: TextStyle(fontWeight: FontWeight.w500)),
                      Text("Rp 55.000"),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Ganti Oli Mesin Sintetik", style: TextStyle(fontWeight: FontWeight.w500)),
                      Text("Rp 65.000"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const PriceSummary(subtotalIdr: 120000),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Bayar Sekarang",
          onPressed: _processBooking,
          loading: _loading,
        ),
      ),
    );
  }
}
