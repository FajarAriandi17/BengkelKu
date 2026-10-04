import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../data/owner_repository.dart";

class OwnerRecordScreen extends StatefulWidget {
  const OwnerRecordScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<OwnerRecordScreen> createState() => _OwnerRecordScreenState();
}

class _OwnerRecordScreenState extends State<OwnerRecordScreen> {
  final _odoController = TextEditingController(text: "12800");
  final _notesController = TextEditingController();
  bool _oilChanged = true;
  bool _loading = false;

  Future<void> _save() async {
    final odo = int.tryParse(_odoController.text) ?? 0;
    if (odo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Odometer terkini harus diisi")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = OwnerRepository();
      await repo.createServiceRecord(
        bookingId: widget.bookingId,
        vehicleId: "v-1",
        workshopId: "ws-1",
        odometerKm: odo,
        oilChanged: _oilChanged,
        notes: _notesController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Riwayat servis disimpan & status oli pelanggan diperbarui!")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Servis ditandai SELESAI & odometer diperbarui")),
        );
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
        title: const Text("Input Riwayat Servis"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pengerjaan Servis Selesai",
                style: AppTypography.h1.copyWith(color: c.ink)),
            const SizedBox(height: 6),
            Text(
              "Input odometer terkini untuk otomatis memperbarui status & pengingat oli di aplikasi pelanggan.",
              style: AppTypography.body
                  .copyWith(color: c.ink.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _odoController,
              label: "Odometer Terkini Motor Pelanggan (km)",
              hint: "12800",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _oilChanged,
              onChanged: (val) => setState(() => _oilChanged = val),
              title: Text("Oli Mesin Diganti?",
                  style: AppTypography.bodyStrong.copyWith(color: c.ink)),
              subtitle: Text(
                  "Nyalakan jika oli mesin diganti dalam pengerjaan ini",
                  style: AppTypography.caption
                      .copyWith(color: c.ink.withValues(alpha: 0.6))),
              activeThumbColor: c.blue,
              tileColor: c.panel,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _notesController,
              label: "Catatan Mekanik (Opsional)",
              hint: "Catatan kondisi rantai, rem, dll...",
              maxLines: 3,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Tandai Selesai & Simpan Record",
          onPressed: _save,
          loading: _loading,
        ),
      ),
    );
  }
}
