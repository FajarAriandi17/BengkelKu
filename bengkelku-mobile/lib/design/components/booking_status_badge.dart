import "package:flutter/material.dart";

import "../../core/theme/app_colors.dart";
import "app_chip.dart";

/// Badge status booking sesuai state machine database (`booking_status`).
class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (label, color, bg, icon) = switch (status.toUpperCase()) {
      "MENUNGGU_PEMBAYARAN" => (
          "Menunggu Bayar",
          c.warn,
          c.warnSoft,
          Icons.pending_actions
        ),
      "DIBAYAR_MENUNGGU_KONFIRMASI" => (
          "Menunggu Konfirmasi",
          c.blue,
          c.blueSoft,
          Icons.hourglass_empty
        ),
      "DIKONFIRMASI" => ("Dikonfirmasi", c.ok, c.okSoft, Icons.check_circle_outline),
      "CHECK_IN" => ("Check-In", c.blue, c.blueSoft, Icons.qr_code_scanner),
      "DIKERJAKAN" => ("Sedang Dikerjakan", c.blue, c.blueSoft, Icons.build),
      "SELESAI" => ("Selesai", c.ok, c.okSoft, Icons.task_alt),
      "KEDALUWARSA" => ("Kedaluwarsa", c.bad, c.badSoft, Icons.timer_off),
      "DITOLAK" => ("Ditolak Bengkel", c.bad, c.badSoft, Icons.cancel),
      "DIBATALKAN" => ("Dibatalkan", c.bad, c.badSoft, Icons.do_not_disturb_on),
      "TIDAK_HADIR" => ("Tidak Hadir", c.bad, c.badSoft, Icons.person_off),
      _ => (status, c.ink, c.blueSoft, Icons.info_outline),
    };

    return AppStatusBadge(
      label: label,
      color: color,
      backgroundColor: bg,
      icon: icon,
    );
  }
}
