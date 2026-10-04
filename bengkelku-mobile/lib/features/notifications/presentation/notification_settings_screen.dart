import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _bookingNotif = true;
  bool _oilNotif = true;
  bool _promoNotif = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan Notifikasi"),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _bookingNotif,
            onChanged: (val) => setState(() => _bookingNotif = val),
            title: Text(
              "Status Booking",
              style: AppTypography.bodyStrong.copyWith(color: c.ink),
            ),
            subtitle: Text(
              "Notifikasi perubahan status booking servis kamu",
              style: AppTypography.caption
                  .copyWith(color: c.ink.withValues(alpha: 0.6)),
            ),
            activeThumbColor: c.blue,
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _oilNotif,
            onChanged: (val) => setState(() => _oilNotif = val),
            title: Text(
              "Pengingat Oli Pintar",
              style: AppTypography.bodyStrong.copyWith(color: c.ink),
            ),
            subtitle: Text(
              "Pengingat jadwal ganti oli berdasarkan odometer & waktu",
              style: AppTypography.caption
                  .copyWith(color: c.ink.withValues(alpha: 0.6)),
            ),
            activeThumbColor: c.blue,
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _promoNotif,
            onChanged: (val) => setState(() => _promoNotif = val),
            title: Text(
              "Promo & Informasi",
              style: AppTypography.bodyStrong.copyWith(color: c.ink),
            ),
            subtitle: Text(
              "Info promo servis & pembaruan dari BengkelKu",
              style: AppTypography.caption
                  .copyWith(color: c.ink.withValues(alpha: 0.6)),
            ),
            activeThumbColor: c.blue,
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    );
  }
}
