// regVerify — pendaftaran bengkel + unggah dokumen verifikasi (FR-O, PRD).
//
// Alur (0021): workshop_register (draft, GPS asli) → unggah 3 dokumen ke bucket
// privat verification-docs → workshop_submit_verification (pending) → antrean
// admin web. Saat ditolak, layar ini dibuka lagi untuk ajukan ulang: data
// terisi otomatis, cukup ganti dokumen yang bermasalah.

import "dart:io";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../../../design/components/media_picker_tile.dart";
import "../../location/data/location_service.dart";
import "../data/owner_repository.dart";

class RegVerifyScreen extends StatefulWidget {
  const RegVerifyScreen({super.key});

  @override
  State<RegVerifyScreen> createState() => _RegVerifyScreenState();
}

class _RegVerifyScreenState extends State<RegVerifyScreen> {
  final _repo = OwnerRepository();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _ktpFile;
  File? _selfieFile;
  File? _locationFile;
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _loading = false;
  bool _prefilling = true;
  String? _status;
  String? _rejectedReason;
  Set<String> _existingDocs = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      final s = await _repo.getMyVerificationStatus();
      if (!mounted) return;
      if (s != null) {
        _nameController.text = s["name"] as String? ?? "";
        _addressController.text = s["address"] as String? ?? "";
        _phoneController.text = s["phone"] as String? ?? "";
        _lat = (s["lat"] as num?)?.toDouble();
        _lng = (s["lng"] as num?)?.toDouble();
        _status = s["status"] as String?;
        _rejectedReason = s["rejected_reason"] as String?;
        _existingDocs = ((s["documents"] as List?) ?? const [])
            .whereType<Map>()
            .where((d) => d["status"] != "rejected")
            .map((d) => d["type"] as String)
            .toSet();
        if (_status == "pending" || _status == "verified") {
          // Sudah diajukan/disetujui — tampilkan layar status.
          context.pushReplacement("/owner/status");
          return;
        }
      }
    } catch (_) {
      // Abaikan; formulir kosong.
    }
    if (mounted) setState(() => _prefilling = false);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos == null) {
        _error =
            "lokasi tidak tersedia. aktifkan GPS & izinkan akses lokasi, lalu coba lagi.";
      } else {
        _lat = pos.latitude;
        _lng = pos.longitude;
      }
    });
  }

  bool _needsDoc(String type, File? picked) =>
      picked == null && !_existingDocs.contains(type);

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    String? err;
    if (name.length < 3) {
      err = "nama bengkel minimal 3 karakter";
    } else if (address.length < 10) {
      err = "alamat lengkap minimal 10 karakter";
    } else if (_lat == null || _lng == null) {
      err =
          "tandai lokasi bengkel dengan tombol \"Pakai lokasi saat ini\" (berdiri di depan bengkel)";
    } else if (_needsDoc("ktp", _ktpFile) ||
        _needsDoc("selfie", _selfieFile) ||
        _needsDoc("location", _locationFile)) {
      err =
          "unggah ketiga dokumen: KTP, selfie dengan KTP, dan foto depan bengkel";
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wsId = await _repo.registerWorkshop(
        name: name,
        address: address,
        phone: _phoneController.text.trim(),
        lat: _lat!,
        lng: _lng!,
      );
      if (_ktpFile != null) {
        await _repo.uploadVerificationDoc(
          workshopId: wsId,
          docType: "ktp",
          file: _ktpFile!,
        );
      }
      if (_selfieFile != null) {
        await _repo.uploadVerificationDoc(
          workshopId: wsId,
          docType: "selfie",
          file: _selfieFile!,
        );
      }
      if (_locationFile != null) {
        await _repo.uploadVerificationDoc(
          workshopId: wsId,
          docType: "location",
          file: _locationFile!,
        );
      }
      await _repo.submitForVerification(wsId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "berkas terkirim. tim kami meninjau maksimal 2×24 jam kerja.",
          ),
        ),
      );
      context.pushReplacement("/owner/status");
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final resubmit = _status == "rejected";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          resubmit ? "Ajukan Ulang Verifikasi" : "Registrasi Usaha Bengkel",
        ),
        elevation: 0,
      ),
      body: _prefilling
          ? Center(child: CircularProgressIndicator(color: c.blue))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (resubmit)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.badSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "alasan penolakan: ${_rejectedReason ?? "-"}\nperbaiki data atau ganti dokumen yang bermasalah, lalu ajukan ulang.",
                          style: AppTypography.body.copyWith(color: c.badText),
                        ),
                      ),
                    Text(
                      "Profil Bengkel",
                      style: AppTypography.h2.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _nameController,
                      label: "Nama Bengkel",
                      hint: "misal: Bengkel Jaya Motor",
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _addressController,
                      label: "Alamat Lengkap",
                      hint: "Jl. Fatmawati No. 12, Cilandak, Jakarta Selatan",
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phoneController,
                      label: "Nomor Telepon",
                      hint: "081234567890",
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _LocationCard(
                      lat: _lat,
                      lng: _lng,
                      locating: _locating,
                      onTap: _locating ? null : _useCurrentLocation,
                    ),
                    const Divider(height: 32),
                    Text(
                      "Dokumen Verifikasi (Maks 2 MB Per File)",
                      style: AppTypography.h2.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "foto KTP, selfie, dan foto depan bengkel wajib asli & jelas. dokumen hanya dilihat tim verifikasi. NIB tidak wajib.",
                      style: AppTypography.caption.copyWith(color: c.ink2),
                    ),
                    const SizedBox(height: 16),
                    MediaPickerTile(
                      title: "1. Foto KTP",
                      subtitle:
                          _existingDocs.contains("ktp") && _ktpFile == null
                              ? "sudah diunggah • ketuk untuk mengganti"
                              : "pastikan teks KTP terbaca jelas",
                      selectedFile: _ktpFile,
                      onFileSelected: (f) => setState(() => _ktpFile = f),
                    ),
                    const SizedBox(height: 12),
                    MediaPickerTile(
                      title: "2. Selfie Memegang KTP",
                      subtitle: _existingDocs.contains("selfie") &&
                              _selfieFile == null
                          ? "sudah diunggah • ketuk untuk mengganti"
                          : "kamera • wajah & KTP terlihat jelas",
                      useCameraOnly: true,
                      selectedFile: _selfieFile,
                      onFileSelected: (f) => setState(() => _selfieFile = f),
                    ),
                    const SizedBox(height: 12),
                    MediaPickerTile(
                      title: "3. Foto Depan Bengkel",
                      subtitle: _existingDocs.contains("location") &&
                              _locationFile == null
                          ? "sudah diunggah • ketuk untuk mengganti"
                          : "kamera • papan nama & bagian depan terlihat",
                      useCameraOnly: true,
                      selectedFile: _locationFile,
                      onFileSelected: (f) => setState(() => _locationFile = f),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: AppTypography.bodyStrong
                              .copyWith(color: c.badText),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label:
                          resubmit ? "Ajukan Ulang" : "Kirim Berkas Verifikasi",
                      onPressed: _loading ? null : _submit,
                      loading: _loading,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.lat,
    required this.lng,
    required this.locating,
    required this.onTap,
  });

  final double? lat;
  final double? lng;
  final bool locating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final has = lat != null && lng != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: has ? c.okSoft : c.panel,
        border: Border.all(color: has ? c.ok : c.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            has ? Icons.where_to_vote : Icons.add_location_alt_outlined,
            color: has ? c.ok : c.ink2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Titik lokasi bengkel",
                  style: AppTypography.bodyStrong.copyWith(color: c.ink),
                ),
                Text(
                  has
                      ? "${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}"
                      : "berdiri di depan bengkel lalu ketuk tombol ini",
                  style: AppTypography.caption.copyWith(color: c.ink2),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(has ? "Perbarui" : "Pakai lokasi saat ini"),
          ),
        ],
      ),
    );
  }
}
