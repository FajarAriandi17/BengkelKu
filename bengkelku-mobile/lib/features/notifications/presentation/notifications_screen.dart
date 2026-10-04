import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pusat Notifikasi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push("/notifications/settings"),
          ),
        ],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NotifTile(
            title: "Oli Motor Mendekati Batas",
            body: "oli motor kamu sudah dekat waktunya ganti. yuk booking sekarang.",
            timeStr: "2 jam yang lalu",
            icon: Icons.opacity,
            color: c.warn,
          ),
          _NotifTile(
            title: "Booking Dikonfirmasi",
            body: "Bengkel Jaya Motor telah mengonfirmasi booking kamu untuk besok jam 09.00 WIB.",
            timeStr: "Kemarin",
            icon: Icons.check_circle_outline,
            color: c.ok,
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.title,
    required this.body,
    required this.timeStr,
    required this.icon,
    required this.color,
  });

  final String title;
  final String body;
  final String timeStr;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                const SizedBox(height: 2),
                Text(body, style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.7))),
                const SizedBox(height: 6),
                Text(timeStr, style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
