// sosForm — Formulir bantuan motor mogok (PRD v1.3 Bagian 3.2 & 3.9)
//
// Alur: pilih masalah → konfirmasi lokasi → lihat biaya tetap → bayar.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/media_guard.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/sos_components.dart';
import '../data/sos_models.dart';
import 'sos_provider.dart';

class SosFormScreen extends ConsumerStatefulWidget {
  const SosFormScreen({super.key});

  @override
  ConsumerState<SosFormScreen> createState() => _SosFormScreenState();
}

class _SosFormScreenState extends ConsumerState<SosFormScreen> {
  SosProblem _problem = SosProblem.ENGINE_DEAD;
  final _noteController = TextEditingController();
  final _landmarkController = TextEditingController();

  Position? _position;
  bool _locating = true;
  String? _locError;

  SosFeeCalculation? _fee;
  bool _loadingFee = false;
  final List<String> _photoUrls = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _position = pos;
        _locating = false;
      });
      await _loadFee();
    } catch (e) {
      setState(() {
        _locating = false;
        _locError = 'Gagal mengambil lokasi. Aktifkan GPS dan coba lagi.';
      });
    }
  }

  Future<void> _loadFee() async {
    if (_position == null) return;

    setState(() => _loadingFee = true);
    try {
      final repo = ref.read(sosRepositoryProvider);
      final fee =
          await repo.quoteFee(_position!.latitude, _position!.longitude);
      setState(() => _fee = fee);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghitung biaya: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_photoUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 3 foto')),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Validasi ukuran ≤ 2 MB (pesan baku).
      try {
        await MediaGuard.ensureFileUnderLimit(File(picked.path));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(kMediaTooLargeMessage)),
          );
        }
        return;
      }

      setState(() => _photoUrls.add(picked.path));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gagal memilih foto: $e');
      }
    }
  }

  Future<void> _submit() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi belum didapatkan')),
      );
      return;
    }

    // Buat permintaan, lalu lanjut ke pembayaran.
    final notifier = ref.read(activeSosProvider.notifier);
    final request = await notifier.create(
      problem: _problem,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      photos: _photoUrls,
      lat: _position!.latitude,
      lng: _position!.longitude,
      accuracyM: _position!.accuracy,
      landmark: _landmarkController.text.trim().isEmpty
          ? null
          : _landmarkController.text.trim(),
    );

    if (!mounted) return;

    if (request == null) {
      final err = ref.read(activeSosProvider).asError?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat permintaan: $err')),
      );
      return;
    }

    context.go('/sos/${request.id}/pay');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canSubmit = _position != null && _fee != null && !_loadingFee;

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Bantuan motor mogok'),
        elevation: 0,
        backgroundColor: c.panel,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apa yang terjadi?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SosProblem.values.map((p) {
                final selected = p == _problem;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _problem = p),
                  selectedColor: c.blue,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : c.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: BorderSide(color: selected ? c.blue : c.line),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Catatan opsional
            TextField(
              controller: _noteController,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Catatan untuk bengkel (opsional)',
                filled: true,
                fillColor: c.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.line),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Konfirmasi lokasi
            Text(
              'Konfirmasi lokasi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _LocationCard(
              locating: _locating,
              error: _locError,
              position: _position,
              onRetry: _getCurrentLocation,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _landmarkController,
              decoration: InputDecoration(
                hintText: 'Patokan (mis. depan toko roti)',
                filled: true,
                fillColor: c.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.line),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Foto opsional
            Row(
              children: [
                Text(
                  'Foto kerusakan (opsional)',
                  style: TextStyle(
                    color: c.ink2,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (_photoUrls.isNotEmpty)
                  Text(
                    '${_photoUrls.length}/3',
                    style: TextStyle(
                      color: c.ink2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photoUrls.map(
                    (path) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  _AddPhotoTile(onTap: _pickPhoto),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rincian biaya
            if (_fee != null) ...[
              FeeBreakdown(
                callFee: _fee!.callFee,
                nightFee: _fee!.nightFee,
                serviceFee: _fee!.serviceFee,
                tierLabel: _fee!.tierLabel,
              ),
              const SizedBox(height: 12),
            ] else if (_loadingFee)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: c.blue),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.warnSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: c.warnText, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Perbaikan di tempat dibayar terpisah setelah kamu setujui penawarannya. Kecelakaan atau luka? Telepon 112.',
                      style: TextStyle(
                        color: c.warnText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: 'Bayar dan cari bengkel',
          onPressed: canSubmit ? _submit : null,
          loading: _loadingFee,
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: Icon(Icons.add_photo_alternate_outlined, color: c.ink2),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool locating;
  final String? error;
  final Position? position;
  final VoidCallback onRetry;

  const _LocationCard({
    required this.locating,
    this.error,
    this.position,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: locating
          ? Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: c.blue),
                ),
                const SizedBox(width: 12),
                Text(
                  'Mengambil lokasi GPS…',
                  style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
                ),
              ],
            )
          : error != null
              ? Row(
                  children: [
                    Icon(Icons.error_outline, color: c.bad, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: c.bad,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.blueSoft,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.my_location, color: c.blueText, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lokasi terkini',
                            style: TextStyle(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Akurasi ±${position!.accuracy.round()} m · '
                            '${position!.latitude.toStringAsFixed(4)}, '
                            '${position!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(color: c.ink2, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: c.okC, size: 22),
                  ],
                ),
    );
  }
}
