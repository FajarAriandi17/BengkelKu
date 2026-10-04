import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";

class RegStatusScreen extends StatelessWidget {
  const RegStatusScreen({super.key, this.status = "pending", this.rejectedReason});

  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectedReason;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (title, message, icon, iconColor) = switch (status) {
      "approved" => (
          "Bengkel Disetujui!",
          "selamat! bengkel kamu sudah tayang di BengkelKu.",
          Icons.verified,
          c.ok,
        ),
      "rejected" => (
          "Verifikasi Ditolak",
          rejectedReason ?? "Dokumen KTP kurang jelas. Silakan perbarui berkas kamu.",
          Icons.error_outline,
          c.bad,
        ),
      _ => (
          "Menunggu Verifikasi",
          "Berkas verifikasi kamu sedang ditinjau tim admin (maksimal 48 jam kerja).",
          Icons.hourglass_top,
          c.warn,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Status Verifikasi Bengkel"),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: iconColor),
            const SizedBox(height: 24),
            Text(title, style: AppTypography.display.copyWith(color: c.ink), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(message, style: AppTypography.body.copyWith(color: c.ink.withOpacity(0.7)), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            if (status == "rejected")
              AppButton(
                label: "Ajukan Ulang Berkas",
                onPressed: () => Navigator.pop(context),
              )
            else if (status == "approved")
              AppButton(
                label: "Buka Dashboard Owner",
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}
