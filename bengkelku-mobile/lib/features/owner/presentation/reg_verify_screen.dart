import "dart:io";
import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../../../design/components/media_picker_tile.dart";
import "../data/owner_repository.dart";

class RegVerifyScreen extends StatefulWidget {
  const RegVerifyScreen({super.key});

  @override
  State<RegVerifyScreen> createState() => _RegVerifyScreenState();
}

class _RegVerifyScreenState extends State<RegVerifyScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _ktpFile;
  File? _selfieFile;
  File? _locationFile;
  bool _loading = false;

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama dan alamat bengkel wajib diisi")),
      );
      return;
    }

    if (_ktpFile == null || _selfieFile == null || _locationFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Seluruh dokumen verifikasi (KTP, Selfie, Foto Ruko) wajib diunggah")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = OwnerRepository();
      final ws = await repo.registerWorkshop(
        name: _nameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        lat: -6.2615,
        lng: 106.8106,
      );

      final wsId = ws["id"] as String;
      await repo.uploadVerificationDoc(
          workshopId: wsId, docType: "ktp", file: _ktpFile!);
      await repo.uploadVerificationDoc(
          workshopId: wsId, docType: "selfie_ktp", file: _selfieFile!);
      await repo.uploadVerificationDoc(
          workshopId: wsId, docType: "location", file: _locationFile!);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Pendaftaran bengkel berhasil diajukan! Menunggu verifikasi admin.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e")),
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
        title: const Text("Registrasi Usaha Bengkel"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Profil Bengkel",
                style: AppTypography.h2.copyWith(color: c.ink)),
            const SizedBox(height: 12),
            AppTextField(
                controller: _nameController,
                label: "Nama Bengkel",
                hint: "misal: Bengkel Jaya Motor"),
            const SizedBox(height: 12),
            AppTextField(
                controller: _addressController,
                label: "Alamat Lengkap",
                hint: "Jl. Fatmawati No. 12..."),
            const SizedBox(height: 12),
            AppTextField(
                controller: _phoneController,
                label: "Nomor Telepon",
                hint: "081234567890",
                keyboardType: TextInputType.phone),
            const Divider(height: 32),
            Text("Dokumen Verifikasi (Maks 2 MB Per File)",
                style: AppTypography.h2.copyWith(color: c.ink)),
            const SizedBox(height: 6),
            Text(
              "Foto KTP, Selfie, dan foto lokasi ruko wajib asli & jelas. NIB tidak wajib.",
              style: AppTypography.caption
                  .copyWith(color: c.ink.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            MediaPickerTile(
              title: "1. Unggah Foto KTP",
              subtitle: "Pastikan teks KTP terbaca jelas",
              selectedFile: _ktpFile,
              onFileSelected: (f) => setState(() => _ktpFile = f),
            ),
            const SizedBox(height: 12),
            MediaPickerTile(
              title: "2. Selfie Memegang KTP",
              subtitle: "Kamera in-app • Wajah & KTP terlihat jelas",
              useCameraOnly: true,
              selectedFile: _selfieFile,
              onFileSelected: (f) => setState(() => _selfieFile = f),
            ),
            const SizedBox(height: 12),
            MediaPickerTile(
              title: "3. Foto Lokasi / Ruko Bengkel",
              subtitle: "Kamera in-app • Foto dari depan ruko",
              useCameraOnly: true,
              selectedFile: _locationFile,
              onFileSelected: (f) => setState(() => _locationFile = f),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: "Kirim Berkas Verifikasi",
              onPressed: _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
