// Formulir "Laporkan masalah" (PRD v1.3 Bagian 7).
// Kategori, deskripsi (maks 1.000 karakter), foto (maks 3, ≤ 2 MB).
// Bisa ditautkan ke booking / panggilan darurat / chat lewat query param.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/media_guard.dart';
import '../../../design/components/app_button.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';
import 'support_tickets_screen.dart';

class SupportReportScreen extends ConsumerStatefulWidget {
  const SupportReportScreen({
    super.key,
    this.bookingId,
    this.sosRequestId,
    this.threadId,
    this.initialCategory,
  });

  final String? bookingId;
  final String? sosRequestId;
  final String? threadId;
  final SupportCategory? initialCategory;

  @override
  ConsumerState<SupportReportScreen> createState() =>
      _SupportReportScreenState();
}

class _Photo {
  _Photo(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

class _SupportReportScreenState extends ConsumerState<SupportReportScreen> {
  SupportCategory? _category;
  final _desc = TextEditingController();
  final List<_Photo> _photos = [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  String? get _relatedLabel {
    if (widget.sosRequestId != null) return 'panggilan darurat';
    if (widget.bookingId != null) return 'booking';
    if (widget.threadId != null) return 'chat';
    return null;
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= SupportLimits.maxPhotos) return;
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      MediaGuard.ensureBytesUnderLimit(bytes);
      final mime =
          x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      setState(() => _photos.add(_Photo(bytes, mime)));
    } on MediaTooLargeException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('gagal memilih foto: $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: context.colors.bad),
    );
  }

  Future<void> _submit() async {
    final err = validateSupportReport(
      category: _category,
      description: _desc.text,
      photoCount: _photos.length,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      final paths = <String>[];
      for (final p in _photos) {
        paths.add(await repo.uploadPhoto(p.bytes, mime: p.mime));
      }
      final t = await repo.createTicket(
        category: _category!,
        description: _desc.text,
        photoPaths: paths,
        bookingId: widget.bookingId,
        sosRequestId: widget.sosRequestId,
        threadId: widget.threadId,
      );
      ref.invalidate(myTicketsProvider);
      if (!mounted) return;
      await HapticFeedback.lightImpact();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.check_circle, color: ctx.colors.okC, size: 48),
          title: Text('Laporan ${t.code} terkirim'),
          content: const Text(
            'tim kami akan membalas paling lambat 1×24 jam kerja. pantau statusnya di Laporanku.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Oke'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.pushReplacement('/help/tickets/${t.id}');
    } catch (e) {
      setState(() => _error = SupportRepository.friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final related = _relatedLabel;
    final len = _desc.text.trim().length;

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Laporkan masalah'),
        backgroundColor: c.panel,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (related != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: c.blueText, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'laporan ini ditautkan ke $related',
                        style: AppTypography.body.copyWith(color: c.blueText),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Kategori',
              style: AppTypography.label.copyWith(color: c.ink2),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in SupportCategory.values)
                  ChoiceChip(
                    label: Text(cat.label),
                    selected: _category == cat,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() {
                              _category = cat;
                              _error = null;
                            }),
                  ),
              ],
            ),
            if (_category?.holdsPayout ?? false) ...[
              const SizedBox(height: 8),
              Text(
                'pembayaran ke bengkel untuk bagian ini ditahan selama laporan ditinjau.',
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _desc,
              enabled: !_submitting,
              maxLines: 6,
              maxLength: SupportLimits.maxDescription,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Ceritakan masalahnya',
                hintText:
                    'apa yang terjadi, kapan, dan apa yang kamu harapkan dari kami',
                alignLabelWithHint: true,
                filled: true,
                fillColor: c.panel,
                helperText: len > 0 && len < SupportLimits.minDescription
                    ? 'minimal ${SupportLimits.minDescription} karakter'
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Foto (${_photos.length}/${SupportLimits.maxPhotos}, opsional)',
              style: AppTypography.label.copyWith(color: c.ink2),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _photos[i].bytes,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Semantics(
                          button: true,
                          label: 'hapus foto ${i + 1}',
                          child: InkWell(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_photos.length < SupportLimits.maxPhotos)
                  Semantics(
                    button: true,
                    label: 'tambah foto',
                    child: InkWell(
                      onTap: _submitting ? null : _pickPhoto,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: c.panel,
                          border: Border.all(color: c.line),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: c.ink2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTypography.bodyStrong.copyWith(color: c.badText),
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: 'Kirim laporan',
              icon: Icons.send_outlined,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
