import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/booking_status_badge.dart";
import "cancel_sheet.dart";

class BookingTicketScreen extends StatelessWidget {
  const BookingTicketScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tiket Booking"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kartu Tiket Utama
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Kode Booking",
                          style: AppTypography.caption
                              .copyWith(color: c.ink.withValues(alpha: 0.6))),
                      const BookingStatusBadge(status: "DIKONFIRMASI"),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("BK-884920",
                        style: AppTypography.h1
                            .copyWith(color: c.blue, fontSize: 22)),
                  ),
                  const Divider(height: 24),

                  // QR Checkin
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.blueSoft),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_2, size: 140, color: c.ink),
                        Text("Tunjukkan QR saat Check-In di bengkel",
                            style: AppTypography.caption
                                .copyWith(color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Bengkel",
                          style: AppTypography.body
                              .copyWith(color: c.ink.withValues(alpha: 0.6))),
                      Text("Bengkel Jaya Motor",
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.ink)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Jadwal",
                          style: AppTypography.body
                              .copyWith(color: c.ink.withValues(alpha: 0.6))),
                      Text("Besok • 09:00 WIB",
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.ink)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Motor",
                          style: AppTypography.body
                              .copyWith(color: c.ink.withValues(alpha: 0.6))),
                      Text("Honda Vario 160",
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.ink)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.bad,
                side: BorderSide(color: c.bad),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text("Batalkan Booking"),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => CancelSheet(
                    bookingId: bookingId,
                    scheduledAt: DateTime.now().add(const Duration(hours: 24)),
                    totalPaidIdr: 120000,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
