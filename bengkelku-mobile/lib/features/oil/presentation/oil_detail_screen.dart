import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/oil_gauge.dart";
import "../domain/oil_calculator.dart";
import "snooze_sheet.dart";

class OilDetailScreen extends StatelessWidget {
  const OilDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Data simulasi status oli
    const currentOdo = 12500;
    const targetOdo = 12700; // sisa 200 km -> soon
    final targetDate = DateTime.now().add(const Duration(days: 5));

    final rKm = remainingKm(targetKm: targetOdo, currentOdometer: currentOdo);
    final rDays = remainingDays(targetDate: targetDate, now: DateTime.now());
    final stage = oilStage(remainingKm: rKm, remainingDays: rDays);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Pengingat Oli"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Gauge
            Center(
              child: OilGauge(
                progress: (rKm / 4000).clamp(0.0, 1.0),
                stage: stage,
                size: 200,
              ),
            ),
            const SizedBox(height: 24),

            // Card Ringkasan
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
                      Text(
                        "Sisa Jarak Ganti Oli",
                        style: AppTypography.body
                            .copyWith(color: c.ink.withValues(alpha: 0.7)),
                      ),
                      Text(
                        Formatters.odometer(rKm),
                        style: AppTypography.h2.copyWith(color: c.blue),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Sisa Hari",
                        style: AppTypography.body
                            .copyWith(color: c.ink.withValues(alpha: 0.7)),
                      ),
                      Text(
                        "$rDays Hari Lagi",
                        style: AppTypography.h2.copyWith(color: c.blue),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Target Odometer",
                        style: AppTypography.body
                            .copyWith(color: c.ink.withValues(alpha: 0.7)),
                      ),
                      Text(
                        Formatters.odometer(targetOdo),
                        style: AppTypography.bodyStrong.copyWith(color: c.ink),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.ink,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (ctx) => const SnoozeSheet(),
                      );
                    },
                    child: const Text("Tunda Pengingat"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: "Booking Servis",
                    onPressed: () => context.push("/home"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
